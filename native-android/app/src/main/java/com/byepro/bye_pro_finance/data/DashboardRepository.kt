package com.byepro.bye_pro_finance.data

import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import com.byepro.bye_pro_finance.domain.ActivityItem
import com.byepro.bye_pro_finance.domain.DashboardSummary
import com.byepro.bye_pro_finance.domain.FinanceRecord
import java.time.Instant
import java.time.YearMonth
import java.time.ZoneId
import java.util.Locale

/**
 * Read-only bridge over the database schema already used by Flutter/Drift.
 * Money remains Long minor-units throughout; no Double conversions are used.
 */
class DashboardRepository(private val helper: LegacyFinanceDatabase) {

    fun loadDashboard(month: YearMonth): DashboardSummary {
        val work = readWorkEntries()
        val expenses = readHomeExpenses()
        val transfers = readTransfers()
        val debts = readDebts()
        val bills = readBills()
        val billPayments = readBillPayments()
        val debtPayments = readDebtPayments()

        val workForMonth = work.filter {
            it.dueYear == month.year && it.dueMonth == month.month
        }
        val salary = workForMonth
            .filter { it.kind == "salary" }
            .sumOf { it.amount }
        val advances = workForMonth
            .filter { it.kind == "advance" }
            .sumOf { it.amount }
        val payments = workForMonth
            .filter { it.kind == "payment" || it.kind == "salaryPayment" }
            .sumOf { it.amount }

        // Match WorkBalanceAllocation and MonthlyOverview in the Flutter app.
        val salaryOutstanding = (salary - advances - payments).coerceAtLeast(0L)
        val cashReceived = workForMonth
            .filter { it.kind != "salary" }
            .sumOf { it.amount }

        val transfersForMonth = transfers
            .filter { isInMonth(it.timestamp, month) }
            .sumOf { it.amount }
        val expensesForMonth = expenses
            .filter { isInMonth(it.timestamp, month) }
            .sumOf { it.amount }
        val billPaymentsForMonth = billPayments
            .filter { isInMonth(it.timestamp, month) }
            .sumOf { it.amount }

        val monthEndExclusive = month.plusMonths(1)
            .atDay(1)
            .atStartOfDay(ZoneId.systemDefault())
            .toInstant()
            .toEpochMilli()
        val paidBeforeMonthEnd = billPayments
            .filter { it.timestamp < monthEndExclusive }
            .groupBy { it.billId }
            .mapValues { (_, records) -> records.sumOf { it.amount } }
        val outstandingBills = bills
            .filter { it.dueYear == month.year && it.dueMonth == month.month }
            .sumOf { bill ->
                (bill.amount - (paidBeforeMonthEnd[bill.id] ?: 0L))
                    .coerceAtLeast(0L)
            }

        val creditor = debts
            .filter { it.direction == "creditor" }
            .sumOf { it.outstanding }
        val debtor = debts
            .filter { it.direction == "debtor" }
            .sumOf { it.outstanding }

        return DashboardSummary(
            month = month,
            availableMonths = collectAvailableMonths(
                month, work, expenses, transfers, debts, bills
            ),
            homeAvailableBalance = transfersForMonth -
                expensesForMonth -
                billPaymentsForMonth -
                outstandingBills,
            workRemaining = cashReceived - transfersForMonth,
            totalWorkOutstanding = salaryOutstanding,
            salaryTotal = salary,
            advancesTotal = advances,
            paymentsTotal = payments,
            currentSalaryOutstanding = salaryOutstanding,
            homeExpensesTotal = expensesForMonth,
            transfersTotal = transfersForMonth,
            billsOutstanding = outstandingBills,
            billsPaid = billPaymentsForMonth,
            creditorBalance = creditor,
            debtorBalance = debtor,
            recentActivity = collectRecentActivity(
                work, expenses, transfers, bills, billPayments, debts, debtPayments
            )
        )
    }

    fun loadWorkRecords(month: YearMonth): List<FinanceRecord> {
        return readWorkEntries()
            .filter { it.dueYear == month.year && it.dueMonth == month.month }
            .sortedByDescending { it.timestamp }
            .map { item ->
                FinanceRecord(
                    id = item.id,
                    kind = item.kind,
                    title = when (item.kind) {
                        "salary" -> "salary"
                        "advance" -> "advance"
                        else -> "payment"
                    },
                    detail = buildList {
                        add(month.toString())
                        if (!item.note.isNullOrBlank()) add(item.note)
                    }.joinToString(" • "),
                    amountMinorUnits = item.amount,
                    timestamp = item.timestamp
                )
            }
    }

    fun loadHomeExpenses(month: YearMonth): List<FinanceRecord> {
        return readHomeExpenses()
            .filter { isInMonth(it.timestamp, month) }
            .sortedByDescending { it.timestamp }
            .map { item ->
                FinanceRecord(
                    id = item.id,
                    kind = "expense",
                    title = item.categoryId,
                    detail = item.note.orEmpty(),
                    amountMinorUnits = item.amount,
                    timestamp = item.timestamp
                )
            }
    }

    fun loadDebts(): List<FinanceRecord> {
        return readDebts()
            .sortedByDescending { it.createdAt }
            .map { debt ->
                FinanceRecord(
                    id = debt.id,
                    kind = debt.direction,
                    title = debt.counterparty,
                    detail = debt.direction + " • " + debt.dueYear + "-" +
                        debt.dueMonth.toString().padStart(2, '0'),
                    amountMinorUnits = debt.outstanding,
                    timestamp = debt.createdAt
                )
            }
    }

    private fun collectAvailableMonths(
        current: YearMonth,
        work: List<WorkRow>,
        expenses: List<ExpenseRow>,
        transfers: List<TransferRow>,
        debts: List<DebtRow>,
        bills: List<BillRow>
    ): List<YearMonth> {
        val months = linkedSetOf(current)
        work.forEach { months.add(YearMonth.of(it.dueYear, it.dueMonth)) }
        debts.forEach { months.add(YearMonth.of(it.dueYear, it.dueMonth)) }
        bills.forEach { months.add(YearMonth.of(it.dueYear, it.dueMonth)) }
        expenses.forEach { months.add(toYearMonth(it.timestamp)) }
        transfers.forEach { months.add(toYearMonth(it.timestamp)) }
        return months.sortedDescending()
    }

    private fun collectRecentActivity(
        work: List<WorkRow>,
        expenses: List<ExpenseRow>,
        transfers: List<TransferRow>,
        bills: List<BillRow>,
        billPayments: List<BillPaymentRow>,
        debts: List<DebtRow>,
        debtPayments: List<DebtPaymentRow>
    ): List<ActivityItem> {
        val billNames = bills.associate { it.id to it.title }
        val debtNames = debts.associate { it.id to it.counterparty }
        val items = mutableListOf<ActivityItem>()

        work.forEach { item ->
            val title = when (item.kind) {
                "salary" -> "salary"
                "advance" -> "advance"
                else -> "payment"
            }
            items.add(
                ActivityItem(title, item.note.orEmpty(), item.amount, item.timestamp, "work")
            )
        }
        expenses.forEach { item ->
            items.add(
                ActivityItem("expense", item.categoryId, item.amount, item.timestamp, "home")
            )
        }
        transfers.forEach { item ->
            items.add(
                ActivityItem("transfer_to_home", item.note.orEmpty(), item.amount, item.timestamp, "transfer")
            )
        }
        billPayments.forEach { item ->
            items.add(
                ActivityItem(
                    "bill_payment",
                    billNames[item.billId].orEmpty(),
                    item.amount,
                    item.timestamp,
                    "bill"
                )
            )
        }
        debtPayments.forEach { item ->
            items.add(
                ActivityItem(
                    "debt_payment",
                    debtNames[item.debtId].orEmpty(),
                    item.amount,
                    item.timestamp,
                    "debt"
                )
            )
        }
        debts.forEach { item ->
            items.add(
                ActivityItem(
                    "debt_created",
                    item.counterparty,
                    item.original,
                    item.createdAt,
                    "debt"
                )
            )
        }
        return items.sortedByDescending { it.timestamp }.take(5)
    }

    private fun readWorkEntries(): List<WorkRow> =
        helper.readableDatabase.rawQuery(
            """
            SELECT id, kind, amount_minor_units, due_year, due_month,
                   recorded_at_epoch_millis, note
            FROM work_entries
            """.trimIndent(),
            null
        ).use { cursor ->
            cursor.mapRows { c ->
                WorkRow(
                    id = c.getString(0),
                    kind = c.getString(1),
                    amount = c.getLong(2),
                    dueYear = c.getInt(3),
                    dueMonth = c.getInt(4),
                    timestamp = c.getLong(5),
                    note = c.nullableString(6)
                )
            }
        }

    private fun readHomeExpenses(): List<ExpenseRow> =
        helper.readableDatabase.rawQuery(
            """
            SELECT id, amount_minor_units, category_id,
                   expense_date_epoch_millis, note
            FROM home_expenses
            """.trimIndent(),
            null
        ).use { cursor ->
            cursor.mapRows { c ->
                ExpenseRow(
                    id = c.getString(0),
                    amount = c.getLong(1),
                    categoryId = c.getString(2),
                    timestamp = c.getLong(3),
                    note = c.nullableString(4)
                )
            }
        }

    private fun readTransfers(): List<TransferRow> =
        helper.readableDatabase.rawQuery(
            """
            SELECT id, amount_minor_units, transferred_at_epoch_millis, note
            FROM work_home_transfers
            """.trimIndent(),
            null
        ).use { cursor ->
            cursor.mapRows { c ->
                TransferRow(
                    id = c.getString(0),
                    amount = c.getLong(1),
                    timestamp = c.getLong(2),
                    note = c.nullableString(3)
                )
            }
        }

    private fun readDebts(): List<DebtRow> =
        helper.readableDatabase.rawQuery(
            """
            SELECT id, direction, original_amount_minor_units,
                   outstanding_amount_minor_units, due_year, due_month,
                   created_at_epoch_millis, counterparty, note
            FROM debts
            """.trimIndent(),
            null
        ).use { cursor ->
            cursor.mapRows { c ->
                DebtRow(
                    id = c.getString(0),
                    direction = c.getString(1),
                    original = c.getLong(2),
                    outstanding = c.getLong(3),
                    dueYear = c.getInt(4),
                    dueMonth = c.getInt(5),
                    createdAt = c.getLong(6),
                    counterparty = c.getString(7),
                    note = c.nullableString(8)
                )
            }
        }

    private fun readBills(): List<BillRow> =
        helper.readableDatabase.rawQuery(
            """
            SELECT id, title, amount_minor_units, due_year, due_month
            FROM home_bills
            """.trimIndent(),
            null
        ).use { cursor ->
            cursor.mapRows { c ->
                BillRow(
                    id = c.getString(0),
                    title = c.getString(1),
                    amount = c.getLong(2),
                    dueYear = c.getInt(3),
                    dueMonth = c.getInt(4)
                )
            }
        }

    private fun readBillPayments(): List<BillPaymentRow> =
        helper.readableDatabase.rawQuery(
            """
            SELECT id, bill_id, amount_minor_units, paid_at_epoch_millis
            FROM home_bill_payments
            """.trimIndent(),
            null
        ).use { cursor ->
            cursor.mapRows { c ->
                BillPaymentRow(c.getString(0), c.getString(1), c.getLong(2), c.getLong(3))
            }
        }

    private fun readDebtPayments(): List<DebtPaymentRow> =
        helper.readableDatabase.rawQuery(
            """
            SELECT id, debt_id, amount_minor_units, paid_at_epoch_millis
            FROM debt_payments
            """.trimIndent(),
            null
        ).use { cursor ->
            cursor.mapRows { c ->
                DebtPaymentRow(c.getString(0), c.getString(1), c.getLong(2), c.getLong(3))
            }
        }

    private fun isInMonth(epochMillis: Long, month: YearMonth): Boolean =
        toYearMonth(epochMillis) == month

    private fun toYearMonth(epochMillis: Long): YearMonth =
        Instant.ofEpochMilli(epochMillis)
            .atZone(ZoneId.systemDefault())
            .let { YearMonth.of(it.year, it.monthValue) }

    private inline fun <T> Cursor.mapRows(mapper: (Cursor) -> T): List<T> {
        val result = ArrayList<T>(count.coerceAtLeast(0))
        while (moveToNext()) result.add(mapper(this))
        return result
    }

    private fun Cursor.nullableString(index: Int): String? =
        if (isNull(index)) null else getString(index)

    private data class WorkRow(
        val id: String,
        val kind: String,
        val amount: Long,
        val dueYear: Int,
        val dueMonth: Int,
        val timestamp: Long,
        val note: String?
    )

    private data class ExpenseRow(
        val id: String,
        val amount: Long,
        val categoryId: String,
        val timestamp: Long,
        val note: String?
    )

    private data class TransferRow(
        val id: String,
        val amount: Long,
        val timestamp: Long,
        val note: String?
    )

    private data class DebtRow(
        val id: String,
        val direction: String,
        val original: Long,
        val outstanding: Long,
        val dueYear: Int,
        val dueMonth: Int,
        val createdAt: Long,
        val counterparty: String,
        val note: String?
    )

    private data class BillRow(
        val id: String,
        val title: String,
        val amount: Long,
        val dueYear: Int,
        val dueMonth: Int
    )

    private data class BillPaymentRow(
        val id: String,
        val billId: String,
        val amount: Long,
        val timestamp: Long
    )

    private data class DebtPaymentRow(
        val id: String,
        val debtId: String,
        val amount: Long,
        val timestamp: Long
    )
}
