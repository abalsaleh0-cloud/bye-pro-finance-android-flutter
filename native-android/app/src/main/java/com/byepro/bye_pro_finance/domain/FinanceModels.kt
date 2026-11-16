package com.byepro.bye_pro_finance.domain

import java.time.YearMonth

data class MetricRow(
    val label: String,
    val amountMinorUnits: Long,
    val icon: String,
    val emphasized: Boolean = false
)

data class FinanceRecord(
    val id: String,
    val kind: String,
    val title: String,
    val detail: String,
    val amountMinorUnits: Long,
    val timestamp: Long
)

data class ActivityItem(
    val title: String,
    val subtitle: String,
    val amountMinorUnits: Long,
    val timestamp: Long,
    val icon: String
)

data class DashboardSummary(
    val month: YearMonth,
    val availableMonths: List<YearMonth>,
    val homeAvailableBalance: Long,
    val workRemaining: Long,
    val totalWorkOutstanding: Long,
    val salaryTotal: Long,
    val advancesTotal: Long,
    val paymentsTotal: Long,
    val currentSalaryOutstanding: Long,
    val homeExpensesTotal: Long,
    val transfersTotal: Long,
    val billsOutstanding: Long,
    val billsPaid: Long,
    val creditorBalance: Long,
    val debtorBalance: Long,
    val recentActivity: List<ActivityItem>
)
