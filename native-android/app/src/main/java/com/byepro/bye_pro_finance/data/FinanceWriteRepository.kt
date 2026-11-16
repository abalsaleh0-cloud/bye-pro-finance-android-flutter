package com.byepro.bye_pro_finance.data

import android.content.ContentValues
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import java.time.Instant
import java.time.YearMonth
import java.time.ZoneId

class FinanceRuleException(
    val rule: Rule,
    val availableMinorUnits: Long = 0L,
    val requestedMinorUnits: Long = 0L
) : IllegalStateException(rule.name) {
    enum class Rule {
        INVALID_AMOUNT,
        INVALID_MONTH,
        INSUFFICIENT_WORK_BALANCE,
        TRANSFER_WOULD_OVERDRAW_HOME,
        INSUFFICIENT_HOME_BALANCE,
        DEBT_PAYMENT_EXCEEDS_BALANCE,
        DEBT_HAS_PAYMENT_HISTORY,
        BILL_PAYMENT_EXCEEDS_BALANCE,
        INSUFFICIENT_BILL_PAYMENT_BALANCE,
        BILL_HAS_PAYMENT_HISTORY,
        BILL_AMOUNT_BELOW_PAYMENTS,
        DEBT_BALANCE_DOES_NOT_MATCH_HISTORY,
        RECORD_NOT_FOUND
    }
}

/**
 * Native write operations ported from the Flutter repositories.
 *
 * Every balance validation and its write occur inside one SQLite transaction.
 * Amounts use integer minor units only; no floating-point money arithmetic.
 */
class FinanceWriteRepository(private val helper: LegacyFinanceDatabase) {

    fun saveWorkEntry(
        id: String,
        kind: String,
        amountMinorUnits: Long,
        dueYear: Int,
        dueMonth: Int,
        recordedAtEpochMillis: Long,
        note: String?
    ) {
        requirePositive(amountMinorUnits)
        requireMonth(dueYear, dueMonth)
        requireNonBlank(id)
        if (kind !in setOf("salary", "advance", "payment", "salaryPayment")) {
            throw IllegalArgumentException("Unsupported work entry kind: $kind")
        }
        val storedKind = if (kind == "salaryPayment") "payment" else kind

        db().inTransaction {
            val previous = queryOne(
                "SELECT kind, amount_minor_units, due_year, due_month FROM work_entries WHERE id = ?",
                arrayOf(id)
            ) { cursor ->
                ExistingWork(
                    kind = cursor.getString(0),
                    amount = cursor.getLong(1),
                    dueYear = cursor.getInt(2),
                    dueMonth = cursor.getInt(3)
                )
            }
            val affected = linkedSetOf<YearMonth>()
            if (previous != null && isCashReceived(previous.kind)) {
                affected.add(YearMonth.of(previous.dueYear, previous.dueMonth))
            }
            if (isCashReceived(storedKind)) {
                affected.add(YearMonth.of(dueYear, dueMonth))
            }

            affected.forEach { month ->
                val receivedBefore = receivedCash(month)
                val receivedAfter = receivedBefore -
                    if (previous != null &&
                        isCashReceived(previous.kind) &&
                        previous.dueYear == month.year &&
                        previous.dueMonth == month.monthValue
                    ) previous.amount else 0L
                    + if (isCashReceived(storedKind) &&
                        dueYear == month.year &&
                        dueMonth == month.monthValue
                    ) amountMinorUnits else 0L

                val transferred = transferred(month)
                if (receivedAfter < transferred && receivedAfter < receivedBefore) {
                    throw FinanceRuleException(
                        FinanceRuleException.Rule.INSUFFICIENT_WORK_BALANCE,
                        availableMinorUnits = receivedBefore - transferred,
                        requestedMinorUnits = receivedAfter - receivedBefore
                    )
                }
            }

            val values = ContentValues().apply {
                put("id", id)
                put("kind", storedKind)
                put("amount_minor_units", amountMinorUnits)
                put("due_year", dueYear)
                put("due_month", dueMonth)
                put("recorded_at_epoch_millis", recordedAtEpochMillis)
                put("note", note)
            }
            db().insertWithOnConflict(
                "work_entries", null, values, SQLiteDatabase.CONFLICT_REPLACE
            )
        }
    }

    fun deleteWorkEntry(id: String) {
        db().inTransaction {
            val target = queryOne(
                "SELECT kind, amount_minor_units, due_year, due_month FROM work_entries WHERE id = ?",
                arrayOf(id)
            ) { c ->
                ExistingWork(c.getString(0), c.getLong(1), c.getInt(2), c.getInt(3))
            } ?: return@inTransaction

            if (isCashReceived(target.kind)) {
                val month = YearMonth.of(target.dueYear, target.dueMonth)
                val receivedAfter = receivedCash(month) - target.amount
                val transferred = transferred(month)
                if (receivedAfter < transferred) {
                    throw FinanceRuleException(
                        FinanceRuleException.Rule.INSUFFICIENT_WORK_BALANCE,
                        availableMinorUnits = receivedAfter - transferred
                    )
                }
            }
            db().delete("work_entries", "id = ?", arrayOf(id))
        }
    }

    fun saveTransfer(
        id: String,
        amountMinorUnits: Long,
        transferredAtEpochMillis: Long,
        note: String?
    ) {
        requirePositive(amountMinorUnits)
        requireNonBlank(id)
        val targetMonth = toYearMonth(transferredAtEpochMillis)

        db().inTransaction {
            val previous = queryOne(
                "SELECT amount_minor_units, transferred_at_epoch_millis FROM work_home_transfers WHERE id = ?",
                arrayOf(id)
            ) { c -> ExistingTransfer(c.getLong(0), c.getLong(1)) }

            val transferredBefore = transferred(targetMonth)
            val previousInTargetMonth = previous?.takeIf {
                toYearMonth(it.timestamp) == targetMonth
            }?.amount ?: 0L
            val transferredAfter = transferredBefore -
                previousInTargetMonth + amountMinorUnits
            val received = receivedCash(targetMonth)

            // Match WorkRepository: existing overdrawn data is not blocked
            // unless the proposed change increases the overdraw.
            if (transferredAfter > received && transferredAfter > transferredBefore) {
                throw FinanceRuleException(
                    FinanceRuleException.Rule.INSUFFICIENT_WORK_BALANCE,
                    availableMinorUnits = received - transferredBefore,
                    requestedMinorUnits = amountMinorUnits
                )
            }

            if (previous != null) {
                val previousMonth = toYearMonth(previous.timestamp)
                if (previousMonth != targetMonth) {
                    val remainingPreviousMonth =
                        transferred(previousMonth) - previous.amount
                    val previousCommitted = homeCommitted(previousMonth)
                    if (remainingPreviousMonth < previousCommitted) {
                        throw FinanceRuleException(
                            FinanceRuleException.Rule.TRANSFER_WOULD_OVERDRAW_HOME,
                            availableMinorUnits = remainingPreviousMonth,
                            requestedMinorUnits = previousCommitted
                        )
                    }
                }
            }

            val committed = homeCommitted(targetMonth)
            if (transferredAfter < committed) {
                throw FinanceRuleException(
                    FinanceRuleException.Rule.TRANSFER_WOULD_OVERDRAW_HOME,
                    availableMinorUnits = transferredAfter,
                    requestedMinorUnits = committed
                )
            }

            val values = ContentValues().apply {
                put("id", id)
                put("amount_minor_units", amountMinorUnits)
                put("transferred_at_epoch_millis", transferredAtEpochMillis)
                put("note", note)
            }
            db().insertWithOnConflict(
                "work_home_transfers", null, values, SQLiteDatabase.CONFLICT_REPLACE
            )
        }
    }

    fun deleteTransfer(id: String) {
        db().inTransaction {
            val target = queryOne(
                "SELECT amount_minor_units, transferred_at_epoch_millis FROM work_home_transfers WHERE id = ?",
                arrayOf(id)
            ) { c -> ExistingTransfer(c.getLong(0), c.getLong(1)) }
                ?: return@inTransaction
            val month = toYearMonth(target.timestamp)
            val transferredAfter = transferred(month) - target.amount
            val committed = homeCommitted(month)
            if (transferredAfter < committed) {
                throw FinanceRuleException(
                    FinanceRuleException.Rule.TRANSFER_WOULD_OVERDRAW_HOME,
                    availableMinorUnits = transferredAfter,
                    requestedMinorUnits = committed
                )
            }
            db().delete("work_home_transfers", "id = ?", arrayOf(id))
        }
    }

    fun saveHomeExpense(
        id: String,
        amountMinorUnits: Long,
        categoryId: String,
        expenseDateEpochMillis: Long,
        dueYear: Int,
        dueMonth: Int,
        note: String?
    ) {
        requirePositive(amountMinorUnits)
        requireNonBlank(id)
        requireNonBlank(categoryId)
        requireMonth(dueYear, dueMonth)
        val month = toYearMonth(expenseDateEpochMillis)

        db().inTransaction {
            val previous = queryOne(
                "SELECT amount_minor_units, expense_date_epoch_millis FROM home_expenses WHERE id = ?",
                arrayOf(id)
            ) { c -> ExistingExpense(c.getLong(0), c.getLong(1)) }

            val transfers = transferred(month)
            val expensesBefore = expenses(month)
            val previousInMonth = previous?.takeIf {
                toYearMonth(it.timestamp) == month
            }?.amount ?: 0L
            val payments = billPayments(month)
            val outstanding = outstandingBills(month)
            val available = transfers -
                expensesBefore -
                payments -
                outstanding +
                previousInMonth

            if (amountMinorUnits > available) {
                throw FinanceRuleException(
                    FinanceRuleException.Rule.INSUFFICIENT_HOME_BALANCE,
                    availableMinorUnits = available,
                    requestedMinorUnits = amountMinorUnits
                )
            }

            val values = ContentValues().apply {
                put("id", id)
                put("amount_minor_units", amountMinorUnits)
                put("category_id", categoryId)
                put("expense_date_epoch_millis", expenseDateEpochMillis)
                put("due_year", dueYear)
                put("due_month", dueMonth)
                put("note", note)
            }
            db().insertWithOnConflict(
                "home_expenses", null, values, SQLiteDatabase.CONFLICT_REPLACE
            )
        }
    }

    fun deleteHomeExpense(id: String) {
        db().delete("home_expenses", "id = ?", arrayOf(id))
    }

    fun saveDebt(
        id: String,
        direction: String,
        originalAmountMinorUnits: Long,
        outstandingAmountMinorUnits: Long,
        dueYear: Int,
        dueMonth: Int,
        createdAtEpochMillis: Long,
        counterparty: String,
        note: String?
    ) {
        requireNonBlank(id)
        requireNonBlank(counterparty)
        requireMonth(dueYear, dueMonth)
        if (direction !in setOf("creditor", "debtor")) {
            throw IllegalArgumentException("Unsupported debt direction: $direction")
        }
        requirePositive(originalAmountMinorUnits)
        if (outstandingAmountMinorUnits < 0L ||
            outstandingAmountMinorUnits > originalAmountMinorUnits
        ) throw FinanceRuleException(FinanceRuleException.Rule.INVALID_AMOUNT)

        db().inTransaction {
            val paid = scalar(
                "SELECT COALESCE(SUM(amount_minor_units), 0) FROM debt_payments WHERE debt_id = ?",
                arrayOf(id)
            )
            if (paid > 0L &&
                outstandingAmountMinorUnits != originalAmountMinorUnits - paid
            ) {
                throw FinanceRuleException(
                    FinanceRuleException.Rule.DEBT_BALANCE_DOES_NOT_MATCH_HISTORY
                )
            }
            if (originalAmountMinorUnits < paid) {
                throw FinanceRuleException(
                    FinanceRuleException.Rule.DEBT_BALANCE_DOES_NOT_MATCH_HISTORY
                )
            }

            val values = ContentValues().apply {
                put("id", id)
                put("direction", direction)
                put("original_amount_minor_units", originalAmountMinorUnits)
                put("outstanding_amount_minor_units", outstandingAmountMinorUnits)
                put("due_year", dueYear)
                put("due_month", dueMonth)
                put("created_at_epoch_millis", createdAtEpochMillis)
                put("counterparty", counterparty)
                put("note", note)
            }
            val exists = scalar(
                "SELECT COUNT(*) FROM debts WHERE id = ?",
                arrayOf(id)
            ) > 0L
            if (exists) {
                // Updating an existing parent row must not REPLACE it:
                // SQLite REPLACE may cascade-delete immutable payment history.
                db().update("debts", values, "id = ?", arrayOf(id))
            } else {
                db().insertOrThrow("debts", null, values)
            }
        }
    }

    fun deleteDebt(id: String) {
        db().inTransaction {
            val payments = scalar(
                "SELECT COUNT(*) FROM debt_payments WHERE debt_id = ?",
                arrayOf(id)
            )
            if (payments > 0L) {
                throw FinanceRuleException(
                    FinanceRuleException.Rule.DEBT_HAS_PAYMENT_HISTORY
                )
            }
            db().delete("debts", "id = ?", arrayOf(id))
        }
    }

    fun recordDebtPayment(
        id: String,
        debtId: String,
        amountMinorUnits: Long,
        paidAtEpochMillis: Long,
        note: String?
    ) {
        requirePositive(amountMinorUnits)
        requireNonBlank(id)
        requireNonBlank(debtId)

        db().inTransaction {
            val outstanding = queryOne(
                "SELECT outstanding_amount_minor_units FROM debts WHERE id = ?",
                arrayOf(debtId)
            ) { c -> c.getLong(0) } ?: throw FinanceRuleException(
                FinanceRuleException.Rule.RECORD_NOT_FOUND
            )
            if (amountMinorUnits > outstanding) {
                throw FinanceRuleException(
                    FinanceRuleException.Rule.DEBT_PAYMENT_EXCEEDS_BALANCE,
                    availableMinorUnits = outstanding,
                    requestedMinorUnits = amountMinorUnits
                )
            }

            val values = ContentValues().apply {
                put("id", id)
                put("debt_id", debtId)
                put("amount_minor_units", amountMinorUnits)
                put("paid_at_epoch_millis", paidAtEpochMillis)
                put("note", note)
            }
            db().insertOrThrow("debt_payments", null, values)
            db().execSQL(
                "UPDATE debts SET outstanding_amount_minor_units = outstanding_amount_minor_units - ? WHERE id = ?",
                arrayOf(amountMinorUnits, debtId)
            )
        }
    }

    fun undoDebtPayment(paymentId: String) {
        db().inTransaction {
            val payment = queryOne(
                "SELECT debt_id, amount_minor_units FROM debt_payments WHERE id = ?",
                arrayOf(paymentId)
            ) { c -> Pair(c.getString(0), c.getLong(1)) }
                ?: throw FinanceRuleException(FinanceRuleException.Rule.RECORD_NOT_FOUND)

            val original = scalar(
                "SELECT original_amount_minor_units FROM debts WHERE id = ?",
                arrayOf(payment.first)
            )
            val outstanding = scalar(
                "SELECT outstanding_amount_minor_units FROM debts WHERE id = ?",
                arrayOf(payment.first)
            )
            if (outstanding + payment.second > original) {
                throw FinanceRuleException(
                    FinanceRuleException.Rule.DEBT_BALANCE_DOES_NOT_MATCH_HISTORY
                )
            }
            db().delete("debt_payments", "id = ?", arrayOf(paymentId))
            db().execSQL(
                "UPDATE debts SET outstanding_amount_minor_units = outstanding_amount_minor_units + ? WHERE id = ?",
                arrayOf(payment.second, payment.first)
            )
        }
    }

    fun saveBill(
        id: String,
        title: String,
        kind: String,
        amountMinorUnits: Long,
        dueYear: Int,
        dueMonth: Int,
        note: String?
    ) {
        requireNonBlank(id)
        requireNonBlank(title)
        requireMonth(dueYear, dueMonth)
        if (kind !in setOf("monthly", "rent")) {
            throw IllegalArgumentException("Unsupported bill kind: $kind")
        }
        requirePositive(amountMinorUnits)
        val month = YearMonth.of(dueYear, dueMonth)

        db().inTransaction {
            val existing = queryOne(
                "SELECT amount_minor_units, due_year, due_month FROM home_bills WHERE id = ?",
                arrayOf(id)
            ) { c -> ExistingBill(c.getLong(0), c.getInt(1), c.getInt(2)) }

            if (existing != null) {
                val paid = scalar(
                    "SELECT COALESCE(SUM(amount_minor_units), 0) FROM home_bill_payments WHERE bill_id = ?",
                    arrayOf(id)
                )
                if (amountMinorUnits < paid) {
                    throw FinanceRuleException(
                        FinanceRuleException.Rule.BILL_AMOUNT_BELOW_PAYMENTS
                    )
                }

                val previousMonth = YearMonth.of(existing.dueYear, existing.dueMonth)
                val previousRemaining = existing.amount - paid
                val nextRemaining = amountMinorUnits - paid
                val targetCommitted = homeCommitted(month)
                val targetTransfers = transferred(month)
                val targetAlreadyIncluded =
                    if (previousMonth == month) previousRemaining else 0L
                val projectedCommitted =
                    targetCommitted - targetAlreadyIncluded + nextRemaining
                if (projectedCommitted > targetTransfers &&
                    projectedCommitted > targetCommitted
                ) {
                    throw FinanceRuleException(
                        FinanceRuleException.Rule.INSUFFICIENT_BILL_PAYMENT_BALANCE,
                        availableMinorUnits =
                            targetTransfers - targetCommitted + targetAlreadyIncluded,
                        requestedMinorUnits = nextRemaining
                    )
                }
                val values = ContentValues().apply {
                    put("title", title.trim())
                    put("kind", kind)
                    put("amount_minor_units", amountMinorUnits)
                    put("due_year", dueYear)
                    put("due_month", dueMonth)
                    put("note", note)
                }
                db().update("home_bills", values, "id = ?", arrayOf(id))
            } else {
                val values = ContentValues().apply {
                    put("id", id)
                    put("title", title.trim())
                    put("kind", kind)
                    put("amount_minor_units", amountMinorUnits)
                    put("due_year", dueYear)
                    put("due_month", dueMonth)
                    put("note", note)
                }
                db().insertOrThrow("home_bills", null, values)
            }
        }
    }

    fun recordBillPayment(
        id: String,
        billId: String,
        amountMinorUnits: Long,
        paidAtEpochMillis: Long,
        note: String?
    ) {
        requirePositive(amountMinorUnits)
        requireNonBlank(id)
        val paymentMonth = toYearMonth(paidAtEpochMillis)

        db().inTransaction {
            val bill = queryOne(
                "SELECT amount_minor_units, due_year, due_month FROM home_bills WHERE id = ?",
                arrayOf(billId)
            ) { c -> ExistingBill(c.getLong(0), c.getInt(1), c.getInt(2)) }
                ?: throw FinanceRuleException(FinanceRuleException.Rule.RECORD_NOT_FOUND)

            val paidAlready = scalar(
                "SELECT COALESCE(SUM(amount_minor_units), 0) FROM home_bill_payments WHERE bill_id = ?",
                arrayOf(billId)
            )
            if (paidAlready + amountMinorUnits > bill.amount) {
                throw FinanceRuleException(
                    FinanceRuleException.Rule.BILL_PAYMENT_EXCEEDS_BALANCE,
                    availableMinorUnits = bill.amount - paidAlready,
                    requestedMinorUnits = amountMinorUnits
                )
            }

            val excludeCurrentBill = if (
                bill.dueYear == paymentMonth.year &&
                bill.dueMonth == paymentMonth.monthValue
            ) billId else null
            val available = transferred(paymentMonth) -
                expenses(paymentMonth) -
                billPayments(paymentMonth) -
                outstandingBills(paymentMonth, excludingBillId = excludeCurrentBill)
            if (amountMinorUnits > available) {
                throw FinanceRuleException(
                    FinanceRuleException.Rule.INSUFFICIENT_BILL_PAYMENT_BALANCE,
                    availableMinorUnits = available,
                    requestedMinorUnits = amountMinorUnits
                )
            }

            val values = ContentValues().apply {
                put("id", id)
                put("bill_id", billId)
                put("amount_minor_units", amountMinorUnits)
                put("paid_at_epoch_millis", paidAtEpochMillis)
                put("note", note)
            }
            db().insertOrThrow("home_bill_payments", null, values)
        }
    }

    fun undoBillPayment(paymentId: String) {
        db().inTransaction {
            val payment = queryOne(
                """
                SELECT p.amount_minor_units, p.paid_at_epoch_millis, b.due_year, b.due_month
                FROM home_bill_payments p
                JOIN home_bills b ON b.id = p.bill_id
                WHERE p.id = ?
                """.trimIndent(),
                arrayOf(paymentId)
            ) { c ->
                BillPaymentToUndo(
                    amount = c.getLong(0),
                    paidAt = c.getLong(1),
                    dueYear = c.getInt(2),
                    dueMonth = c.getInt(3)
                )
            } ?: throw FinanceRuleException(FinanceRuleException.Rule.RECORD_NOT_FOUND)

            val dueMonth = YearMonth.of(payment.dueYear, payment.dueMonth)
            val paymentMonth = toYearMonth(payment.paidAt)
            if (paymentMonth != dueMonth) {
                val available = transferred(dueMonth) - homeCommitted(dueMonth)
                if (payment.amount > available) {
                    throw FinanceRuleException(
                        FinanceRuleException.Rule.INSUFFICIENT_BILL_PAYMENT_BALANCE,
                        availableMinorUnits = available,
                        requestedMinorUnits = payment.amount
                    )
                }
            }
            db().delete("home_bill_payments", "id = ?", arrayOf(paymentId))
        }
    }

    fun deleteBill(id: String) {
        db().inTransaction {
            val payments = scalar(
                "SELECT COUNT(*) FROM home_bill_payments WHERE bill_id = ?",
                arrayOf(id)
            )
            if (payments > 0L) {
                throw FinanceRuleException(
                    FinanceRuleException.Rule.BILL_HAS_PAYMENT_HISTORY
                )
            }
            db().delete("home_bills", "id = ?", arrayOf(id))
        }
    }

    private fun homeCommitted(month: YearMonth): Long =
        expenses(month) + billPayments(month) + outstandingBills(month)

    private fun expenses(month: YearMonth): Long {
        val (start, finish) = monthRange(month)
        return scalar(
            "SELECT COALESCE(SUM(amount_minor_units), 0) FROM home_expenses WHERE expense_date_epoch_millis >= ? AND expense_date_epoch_millis < ?",
            arrayOf(start.toString(), finish.toString())
        )
    }

    private fun billPayments(month: YearMonth): Long {
        val (start, finish) = monthRange(month)
        return scalar(
            "SELECT COALESCE(SUM(amount_minor_units), 0) FROM home_bill_payments WHERE paid_at_epoch_millis >= ? AND paid_at_epoch_millis < ?",
            arrayOf(start.toString(), finish.toString())
        )
    }

    private fun transferred(month: YearMonth): Long {
        val (start, finish) = monthRange(month)
        return scalar(
            "SELECT COALESCE(SUM(amount_minor_units), 0) FROM work_home_transfers WHERE transferred_at_epoch_millis >= ? AND transferred_at_epoch_millis < ?",
            arrayOf(start.toString(), finish.toString())
        )
    }

    private fun receivedCash(month: YearMonth): Long =
        scalar(
            """
            SELECT COALESCE(SUM(amount_minor_units), 0)
            FROM work_entries
            WHERE due_year = ? AND due_month = ?
              AND kind IN ('advance', 'payment', 'salaryPayment')
            """.trimIndent(),
            arrayOf(month.year.toString(), month.monthValue.toString())
        )

    private fun outstandingBills(
        month: YearMonth,
        excludingBillId: String? = null
    ): Long {
        val exclusion = if (excludingBillId == null) "" else " AND b.id != ?"
        val args = mutableListOf(month.year.toString(), month.monthValue.toString())
        if (excludingBillId != null) args.add(excludingBillId)
        return scalar(
            """
            SELECT COALESCE(
                SUM(b.amount_minor_units - COALESCE(p.paid_minor_units, 0)), 0
            )
            FROM home_bills b
            LEFT JOIN (
                SELECT bill_id, SUM(amount_minor_units) AS paid_minor_units
                FROM home_bill_payments
                GROUP BY bill_id
            ) p ON p.bill_id = b.id
            WHERE b.due_year = ? AND b.due_month = ?$exclusion
            """.trimIndent(),
            args.toTypedArray()
        )
    }

    private fun monthRange(month: YearMonth): Pair<Long, Long> {
        val start = month.atDay(1).atStartOfDay(ZoneId.systemDefault())
            .toInstant().toEpochMilli()
        val finish = month.plusMonths(1).atDay(1)
            .atStartOfDay(ZoneId.systemDefault())
            .toInstant().toEpochMilli()
        return start to finish
    }

    private fun toYearMonth(epochMillis: Long): YearMonth =
        Instant.ofEpochMilli(epochMillis)
            .atZone(ZoneId.systemDefault())
            .let { YearMonth.of(it.year, it.monthValue) }

    private fun requirePositive(amount: Long) {
        if (amount <= 0L) {
            throw FinanceRuleException(FinanceRuleException.Rule.INVALID_AMOUNT)
        }
    }

    private fun requireNonBlank(value: String) {
        require(value.isNotBlank())
    }

    private fun requireMonth(year: Int, month: Int) {
        if (year !in 1..9999 || month !in 1..12) {
            throw FinanceRuleException(FinanceRuleException.Rule.INVALID_MONTH)
        }
    }

    private fun isCashReceived(kind: String): Boolean =
        kind == "advance" || kind == "payment" || kind == "salaryPayment"

    private fun db(): SQLiteDatabase = helper.writableDatabase

    private fun scalar(sql: String, args: Array<String>? = null): Long =
        db().rawQuery(sql, args).use { c ->
            if (c.moveToFirst()) c.getLong(0) else 0L
        }

    private inline fun <T> queryOne(
        sql: String,
        args: Array<String>,
        mapper: (Cursor) -> T
    ): T? = db().rawQuery(sql, args).use { c ->
        if (c.moveToFirst()) mapper(c) else null
    }

    private inline fun <T> SQLiteDatabase.inTransaction(block: () -> T): T {
        beginTransaction()
        try {
            val result = block()
            setTransactionSuccessful()
            return result
        } finally {
            endTransaction()
        }
    }

    private data class ExistingWork(
        val kind: String,
        val amount: Long,
        val dueYear: Int,
        val dueMonth: Int
    )

    private data class ExistingTransfer(val amount: Long, val timestamp: Long)
    private data class ExistingExpense(val amount: Long, val timestamp: Long)
    private data class ExistingBill(val amount: Long, val dueYear: Int, val dueMonth: Int)
    private data class BillPaymentToUndo(
        val amount: Long,
        val paidAt: Long,
        val dueYear: Int,
        val dueMonth: Int
    )
}
