package com.byepro.bye_pro_finance

import android.app.Activity
import android.app.AlertDialog
import android.app.DatePickerDialog
import android.content.Context
import android.content.res.Configuration
import android.graphics.Typeface
import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.PopupMenu
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import com.byepro.bye_pro_finance.data.DashboardRepository
import com.byepro.bye_pro_finance.data.LegacyFinanceDatabase
import com.byepro.bye_pro_finance.domain.ActivityItem
import com.byepro.bye_pro_finance.domain.DashboardSummary
import com.byepro.bye_pro_finance.domain.FinanceRecord
import com.byepro.bye_pro_finance.ui.FinancePalette
import com.byepro.bye_pro_finance.ui.FinancePalette.setRoundedBackground
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.text.SimpleDateFormat
import java.time.Instant
import java.time.YearMonth
import java.time.ZoneId
import java.util.Date
import java.util.Locale
import java.util.UUID

class MainActivity : Activity() {

    private enum class Section {
        DASHBOARD, WORK, HOME, DEBTS, AI
    }

    private lateinit var database: LegacyFinanceDatabase
    private lateinit var repository: DashboardRepository
    private lateinit var writeRepository: FinanceWriteRepository
    private lateinit var root: LinearLayout
    private lateinit var scrollView: ScrollView
    private lateinit var pageContent: LinearLayout
    private lateinit var navigation: LinearLayout

    private var activeSection = Section.DASHBOARD
    private var selectedMonth = YearMonth.now()
    private var localeCode = "ar"
    private var themeMode = "system"
    private var darkTheme = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        database = LegacyFinanceDatabase(this)
        repository = DashboardRepository(database)
        writeRepository = FinanceWriteRepository(database)
        localeCode = database.readSetting("locale")?.let {
            if (it == "en") "en" else "ar"
        } ?: "ar"
        themeMode = database.readSetting("theme_mode") ?: "system"
        activeSection = savedInstanceState?.getString("active_section")
            ?.let { runCatching { Section.valueOf(it) }.getOrNull() }
            ?: Section.DASHBOARD
        selectedMonth = savedInstanceState?.getString("selected_month")
            ?.let { runCatching { YearMonth.parse(it) }.getOrNull() }
            ?: YearMonth.now()

        darkTheme = resolveDarkTheme()
        applySystemBars()
        buildApplicationShell()
        renderCurrentSection()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putString("active_section", activeSection.name)
        outState.putString("selected_month", selectedMonth.toString())
        super.onSaveInstanceState(outState)
    }

    override fun onDestroy() {
        if (::database.isInitialized) database.close()
        super.onDestroy()
    }

    private fun localizedContext(): Context {
        val configuration = Configuration(resources.configuration)
        configuration.setLocale(Locale.forLanguageTag(localeCode))
        return createConfigurationContext(configuration)
    }

    private fun s(resourceId: Int): String = localizedContext().getString(resourceId)

    private fun resolveDarkTheme(): Boolean = when (themeMode) {
        "dark" -> true
        "light" -> false
        else -> {
            val mode = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
            mode != Configuration.UI_MODE_NIGHT_NO
        }
    }

    private fun applySystemBars() {
        window.statusBarColor = FinancePalette.background(darkTheme)
        window.navigationBarColor = FinancePalette.background(darkTheme)
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = if (darkTheme) 0 else
            View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
    }

    private fun buildApplicationShell() {
        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            textDirection = View.TEXT_DIRECTION_FIRST_STRONG
            setBackgroundColor(FinancePalette.background(darkTheme))
        }

        root.addView(buildToolbar(), LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(60)
        ))

        scrollView = ScrollView(this).apply {
            isFillViewport = true
            isVerticalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }
        pageContent = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            setPadding(dp(16), dp(10), dp(16), dp(20))
        }
        scrollView.addView(pageContent)
        root.addView(scrollView, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f
        ))

        navigation = buildNavigation()
        root.addView(navigation, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(72)
        ))
        setContentView(root)
    }

    private fun buildToolbar(): LinearLayout {
        val toolbar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), 0, dp(12), 0)
            setBackgroundColor(FinancePalette.background(darkTheme))
        }

        val title = makeText(sectionTitle(activeSection), 21f, true).apply {
            gravity = Gravity.CENTER_VERTICAL or Gravity.START
        }
        toolbar.addView(title, LinearLayout.LayoutParams(0, dp(52), 1f))
        if (activeSection == Section.WORK ||
            activeSection == Section.HOME ||
            activeSection == Section.DEBTS
        ) {
            addToolbarAction(toolbar, "＋", s(com.byepro.bye_pro_finance.R.string.add_record)) {
                showCreateMenu(it)
            }
        }
        addToolbarAction(toolbar, "▦", s(com.byepro.bye_pro_finance.R.string.calendar)) {
            showMonthPicker(it)
        }
        addToolbarAction(toolbar, "⊞", s(com.byepro.bye_pro_finance.R.string.calculator)) {
            showCalculator()
        }
        addToolbarAction(toolbar, "⚙", s(com.byepro.bye_pro_finance.R.string.settings)) {
            showSettings()
        }
        return toolbar
    }

    private fun addToolbarAction(
        parent: LinearLayout,
        glyph: String,
        description: String,
        action: (View) -> Unit
    ) {
        val button = makeText(glyph, 24f, false).apply {
            gravity = Gravity.CENTER
            contentDescription = description
            isClickable = true
            isFocusable = true
            setOnClickListener { action(this) }
        }
        parent.addView(button, LinearLayout.LayoutParams(dp(44), dp(48)))
    }

    private fun buildNavigation(): LinearLayout {
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(4), dp(5), dp(4), dp(4))
            setBackgroundColor(FinancePalette.surface(darkTheme))
        }
        val topDivider = View(this).apply {
            setBackgroundColor(FinancePalette.divider(darkTheme))
        }
        val wrapper = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(topDivider, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(1)
            ))
            addView(bar, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f
            ))
        }
        updateNavigationItems(bar)
        navigation = wrapper
        return wrapper
    }

    private fun updateNavigationItems(bar: LinearLayout) {
        bar.removeAllViews()
        val tabs = listOf(
            Triple(Section.DASHBOARD, "▦", s(com.byepro.bye_pro_finance.R.string.dashboard)),
            Triple(Section.WORK, "▰", s(com.byepro.bye_pro_finance.R.string.work)),
            Triple(Section.HOME, "⌂", s(com.byepro.bye_pro_finance.R.string.home)),
            Triple(Section.DEBTS, "▤", s(com.byepro.bye_pro_finance.R.string.debts)),
            Triple(Section.AI, "✧", s(com.byepro.bye_pro_finance.R.string.ai))
        )
        tabs.forEach { (section, glyph, label) ->
            val selected = section == activeSection
            val item = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                layoutDirection = View.LAYOUT_DIRECTION_RTL
                gravity = Gravity.CENTER
                isClickable = true
                isFocusable = true
                setOnClickListener {
                    activeSection = section
                    renderCurrentSection()
                }
                setPadding(dp(2), dp(3), dp(2), dp(3))
            }
            val icon = makeText(glyph, 22f, selected).apply {
                gravity = Gravity.CENTER
                setTextColor(
                    if (selected) FinancePalette.accent(darkTheme)
                    else FinancePalette.muted(darkTheme)
                )
            }
            val labelView = makeText(label, 11f, selected).apply {
                gravity = Gravity.CENTER
                setPadding(0, dp(2), 0, 0)
                setTextColor(
                    if (selected) FinancePalette.text(darkTheme)
                    else FinancePalette.muted(darkTheme)
                )
            }
            item.addView(icon)
            item.addView(labelView)
            bar.addView(item, LinearLayout.LayoutParams(0, dp(60), 1f))
        }
    }

    private fun renderCurrentSection() {
        pageContent.removeAllViews()
        when (activeSection) {
            Section.DASHBOARD -> renderDashboard()
            Section.WORK -> renderWork()
            Section.HOME -> renderHome()
            Section.DEBTS -> renderDebts()
            Section.AI -> renderAssistant()
        }
        scrollView.scrollTo(0, 0)
        refreshToolbarTitle()
        val bar = navigation.getChildAt(1) as? LinearLayout
        if (bar != null) updateNavigationItems(bar)
    }

    private fun refreshToolbarTitle() {
        val toolbar = root.getChildAt(0) as? LinearLayout ?: return
        val title = toolbar.getChildAt(0) as? TextView ?: return
        title.text = sectionTitle(activeSection)
    }

    private fun renderDashboard() {
        val summary = repository.loadDashboard(selectedMonth)
        addMonthSelector(summary)
        addGap(16)
        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.financial_snapshot))
        addMetricGroup(
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.home_available_balance), summary.homeAvailableBalance, "▣", true),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.work_remaining), summary.workRemaining, "▤"),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.total_work_outstanding), summary.totalWorkOutstanding, "◷")
        )

        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.work))
        addMetricGroup(
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.salary_total), summary.salaryTotal, "▣"),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.advances_total), summary.advancesTotal, "↗"),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.payments_total), summary.paymentsTotal, "↙"),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.current_salary_outstanding), summary.currentSalaryOutstanding, "◷")
        )

        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.home))
        addMetricGroup(
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.home_expenses_total), summary.homeExpensesTotal, "▤"),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.transfers_total), summary.transfersTotal, "⇄"),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.bills_outstanding), summary.billsOutstanding, "▣"),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.bills_paid), summary.billsPaid, "✓")
        )

        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.cash_flow))
        addCashFlowComparison(
            summary.transfersTotal,
            summary.homeExpensesTotal
        )

        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.debts))
        addMetricGroup(
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.creditor_balance), summary.creditorBalance, "↙"),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.debtor_balance), summary.debtorBalance, "↗")
        )

        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.recent_activity))
        addActivityGroup(summary.recentActivity)
        addGap(8)
    }

    private fun addMonthSelector(summary: DashboardSummary) {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            setPadding(dp(12), dp(7), dp(7), dp(7))
            setRoundedBackground(FinancePalette.surface(darkTheme), 14f)
        }
        val calendar = makeText("▦", 20f, true).apply {
            setTextColor(FinancePalette.accent(darkTheme))
            gravity = Gravity.CENTER
        }
        row.addView(calendar, LinearLayout.LayoutParams(dp(34), dp(42)))
        val label = makeText(s(com.byepro.bye_pro_finance.R.string.month_shown), 14f, true)
        row.addView(label, LinearLayout.LayoutParams(0, dp(44), 1f))
        val month = makeText(selectedMonth.toString() + "  ⌄", 16f, true).apply {
            gravity = Gravity.CENTER
            setPadding(dp(14), 0, dp(14), 0)
            setRoundedBackground(FinancePalette.raised(darkTheme), 12f)
            isClickable = true
            isFocusable = true
            setOnClickListener { showMonthPicker(this, summary.availableMonths) }
        }
        row.addView(month, LinearLayout.LayoutParams(dp(150), dp(44)))
        pageContent.addView(row, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ))
    }

    private data class MetricDisplay(
        val label: String,
        val amount: Long,
        val icon: String,
        val emphasized: Boolean = false
    )

    private fun addMetricGroup(vararg metrics: MetricDisplay) {
        val group = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            setRoundedBackground(FinancePalette.surface(darkTheme), 16f)
            clipToOutline = true
        }
        metrics.forEachIndexed { index, metric ->
            if (index > 0) addDivider(group, 64)
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                layoutDirection = View.LAYOUT_DIRECTION_RTL
                setPadding(dp(12), dp(7), dp(12), dp(7))
            }
            val icon = makeText(metric.icon, 18f, true).apply {
                gravity = Gravity.CENTER
                setTextColor(
                    if (metric.emphasized) FinancePalette.text(darkTheme)
                    else FinancePalette.accent(darkTheme)
                )
                setRoundedBackground(
                    if (metric.emphasized) FinancePalette.accent(darkTheme)
                    else FinancePalette.raised(darkTheme),
                    30f
                )
            }
            row.addView(icon, LinearLayout.LayoutParams(dp(40), dp(40)))
            val label = makeText(metric.label, 14f, false).apply {
                setPadding(dp(12), 0, dp(6), 0)
                maxLines = 2
            }
            row.addView(label, LinearLayout.LayoutParams(0, dp(48), 1f))
            val amount = makeText(formatAmount(metric.amount), 18f, true).apply {
                gravity = Gravity.CENTER_VERTICAL or Gravity.END
                setTextColor(
                    if (metric.emphasized) FinancePalette.accent(darkTheme)
                    else FinancePalette.text(darkTheme)
                )
            }
            row.addView(amount, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, dp(48)
            ))
            group.addView(row, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
            ))
        }
        pageContent.addView(group, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = dp(14) })
    }

    private fun addDivider(parent: LinearLayout, indentDp: Int) {
        val line = View(this).apply {
            setBackgroundColor(FinancePalette.divider(darkTheme))
        }
        parent.addView(line, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(1)
        ).apply {
            marginStart = dp(indentDp)
            marginEnd = dp(12)
        })
    }

    private fun addSectionHeading(title: String) {
        val heading = makeText(title, 18f, true).apply {
            setPadding(dp(2), dp(10), dp(2), dp(8))
        }
        pageContent.addView(heading, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ))
    }

    private fun addCashFlowComparison(transfers: Long, expenses: Long) {
        val total = maxOf(transfers, expenses, 1L).toFloat()
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(13), dp(14), dp(13))
            setRoundedBackground(FinancePalette.surface(darkTheme), 14f)
        }
        addComparisonBar(
            container,
            s(com.byepro.bye_pro_finance.R.string.transfers_total),
            transfers,
            transfers / total
        )
        addGapTo(container, 12)
        addComparisonBar(
            container,
            s(com.byepro.bye_pro_finance.R.string.home_expenses_total),
            expenses,
            expenses / total
        )
        pageContent.addView(container, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = dp(14) })
    }

    private fun addComparisonBar(
        parent: LinearLayout,
        label: String,
        value: Long,
        ratio: Float
    ) {
        val head = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }
        head.addView(makeText(label, 13f, false), LinearLayout.LayoutParams(0, dp(24), 1f))
        head.addView(makeText(formatAmount(value), 14f, true), LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, dp(24)
        ))
        parent.addView(head)
        val track = View(this).apply {
            setRoundedBackground(FinancePalette.raised(darkTheme), 5f)
        }
        parent.addView(track, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(7)
        ).apply { topMargin = dp(5) })
        val fill = View(this).apply {
            setRoundedBackground(FinancePalette.accent(darkTheme), 5f)
        }
        // Keep the indicator RTL and proportional without creating a second
        // transaction or changing any stored monetary value.
        val measuredWidth = (resources.displayMetrics.widthPixels - dp(72)).coerceAtLeast(1)
        val width = (measuredWidth * ratio).toInt().coerceAtLeast(if (value == 0L) 0 else dp(3))
        parent.addView(fill, LinearLayout.LayoutParams(width, dp(7)).apply {
            topMargin = -dp(7)
            gravity = Gravity.END
        })
    }

    private fun addActivityGroup(items: List<ActivityItem>) {
        if (items.isEmpty()) {
            addEmptyState(s(com.byepro.bye_pro_finance.R.string.no_recent_activity))
            return
        }
        val group = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setRoundedBackground(FinancePalette.surface(darkTheme), 15f)
            clipToOutline = true
        }
        items.forEachIndexed { index, item ->
            if (index > 0) addDivider(group, 64)
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                layoutDirection = View.LAYOUT_DIRECTION_RTL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(12), dp(7), dp(12), dp(7))
            }
            val icon = makeText(activityGlyph(item.icon), 18f, true).apply {
                gravity = Gravity.CENTER
                setTextColor(FinancePalette.accent(darkTheme))
                setRoundedBackground(FinancePalette.raised(darkTheme), 30f)
            }
            row.addView(icon, LinearLayout.LayoutParams(dp(40), dp(40)))
            val detail = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(12), 0, dp(8), 0)
            }
            detail.addView(makeText(activityTitle(item.title), 13f, true))
            if (item.subtitle.isNotBlank()) {
                detail.addView(makeText(item.subtitle, 11f, false).apply {
                    setTextColor(FinancePalette.muted(darkTheme))
                    maxLines = 1
                })
            }
            row.addView(detail, LinearLayout.LayoutParams(0, dp(48), 1f))
            row.addView(makeText(formatAmount(item.amountMinorUnits), 15f, true))
            group.addView(row)
        }
        pageContent.addView(group)
    }

    private fun renderWork() {
        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.work_records))
        addMonthQuickPicker()
        val records = (
            repository.loadWorkRecords(selectedMonth) +
                repository.loadTransfers(selectedMonth)
            ).sortedByDescending { it.timestamp }
        if (records.isEmpty()) {
            addEmptyState(s(com.byepro.bye_pro_finance.R.string.no_records))
            return
        }
        addRecordGroup(records)
    }

    private fun renderHome() {
        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.home_records))
        addMonthQuickPicker()
        val records = (
            repository.loadHomeExpenses(selectedMonth) +
                repository.loadBills(selectedMonth)
            ).sortedByDescending { if (it.kind == "bill") Long.MAX_VALUE else it.timestamp }
        if (records.isEmpty()) {
            addEmptyState(s(com.byepro.bye_pro_finance.R.string.no_records))
            return
        }
        addRecordGroup(records)
    }

    private fun renderDebts() {
        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.debt_records))
        val records = repository.loadDebts()
        if (records.isEmpty()) {
            addEmptyState(s(com.byepro.bye_pro_finance.R.string.no_records))
            return
        }
        addRecordGroup(records)
    }

    private fun renderAssistant() {
        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.ai))
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
            setRoundedBackground(FinancePalette.surface(darkTheme), 16f)
        }
        panel.addView(makeText("✧", 28f, true).apply {
            setTextColor(FinancePalette.accent(darkTheme))
        })
        panel.addView(makeText(
            s(com.byepro.bye_pro_finance.R.string.ai_migration_notice),
            14f,
            false
        ).apply {
            setPadding(0, dp(8), 0, 0)
        })
        pageContent.addView(panel, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ))
    }

    private fun addMonthQuickPicker() {
        val summary = repository.loadDashboard(selectedMonth)
        addMonthSelector(summary)
        addGap(12)
    }

    private fun addRecordGroup(records: List<FinanceRecord>) {
        val group = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            setRoundedBackground(FinancePalette.surface(darkTheme), 15f)
            clipToOutline = true
        }
        records.forEachIndexed { index, record ->
            if (index > 0) addDivider(group, 64)
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                layoutDirection = View.LAYOUT_DIRECTION_RTL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(12), dp(8), dp(12), dp(8))
            }
            val icon = makeText(recordGlyph(record.kind), 18f, true).apply {
                gravity = Gravity.CENTER
                setTextColor(FinancePalette.accent(darkTheme))
                setRoundedBackground(FinancePalette.raised(darkTheme), 30f)
            }
            row.addView(icon, LinearLayout.LayoutParams(dp(40), dp(40)))
            val details = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(12), 0, dp(8), 0)
            }
            details.addView(makeText(recordTitle(record), 14f, true))
            if (record.detail.isNotBlank()) {
                details.addView(makeText(record.detail, 11f, false).apply {
                    setTextColor(FinancePalette.muted(darkTheme))
                    maxLines = 1
                })
            }
            row.addView(details, LinearLayout.LayoutParams(0, dp(48), 1f))
            val amount = makeText(formatAmount(record.amountMinorUnits), 15f, true)
            row.addView(amount)
            row.isLongClickable = true
            row.setOnLongClickListener {
                showRecordActions(it, record)
                true
            }
            if (record.kind == "bill" || record.kind == "creditor" || record.kind == "debtor") {
                row.isClickable = true
                row.setOnClickListener { showRecordActions(it, record) }
            }
            group.addView(row)
        }
        pageContent.addView(group)
    }

    private fun addEmptyState(message: String) {
        val text = makeText(message, 14f, false).apply {
            gravity = Gravity.CENTER
            setTextColor(FinancePalette.muted(darkTheme))
            setPadding(dp(12), dp(24), dp(12), dp(24))
        }
        pageContent.addView(text, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ))
    }

    private fun showMonthPicker(anchor: View, months: List<YearMonth>? = null) {
        val available = months ?: repository.loadDashboard(selectedMonth).availableMonths
        val popup = PopupMenu(this, anchor)
        available.forEach { month ->
            popup.menu.add(month.toString()).setOnMenuItemClickListener {
                selectedMonth = month
                renderCurrentSection()
                true
            }
        }
        popup.show()
    }

    private fun showCalculator() {
        val form = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(12), dp(20), 0)
        }
        val first = EditText(this).apply {
            hint = s(com.byepro.bye_pro_finance.R.string.enter_amount)
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_SIGNED
        }
        val second = EditText(this).apply {
            hint = s(com.byepro.bye_pro_finance.R.string.enter_amount)
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_SIGNED
        }
        form.addView(first)
        form.addView(second)
        AlertDialog.Builder(this)
            .setTitle(s(com.byepro.bye_pro_finance.R.string.calculator))
            .setView(form)
            .setPositiveButton(s(com.byepro.bye_pro_finance.R.string.result)) { _, _ ->
                val a = first.text.toString().toLongOrNull() ?: 0L
                val b = second.text.toString().toLongOrNull() ?: 0L
                AlertDialog.Builder(this)
                    .setMessage(formatAmount(a + b))
                    .setPositiveButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
                    .show()
            }
            .setNegativeButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
            .show()
    }

    private fun showSettings() {
        val options = arrayOf(
            s(com.byepro.bye_pro_finance.R.string.dark),
            s(com.byepro.bye_pro_finance.R.string.light),
            s(com.byepro.bye_pro_finance.R.string.system),
            s(com.byepro.bye_pro_finance.R.string.arabic),
            s(com.byepro.bye_pro_finance.R.string.english)
        )
        AlertDialog.Builder(this)
            .setTitle(s(com.byepro.bye_pro_finance.R.string.settings))
            .setItems(options) { _, which ->
                when (which) {
                    0 -> themeMode = "dark"
                    1 -> themeMode = "light"
                    2 -> themeMode = "system"
                    3 -> localeCode = "ar"
                    4 -> localeCode = "en"
                }
                database.writeSetting("theme_mode", themeMode)
                database.writeSetting("locale", localeCode)
                recreate()
            }
            .setNegativeButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
            .show()
    }

    private fun sectionTitle(section: Section): String = when (section) {
        Section.DASHBOARD -> s(com.byepro.bye_pro_finance.R.string.dashboard)
        Section.WORK -> s(com.byepro.bye_pro_finance.R.string.work)
        Section.HOME -> s(com.byepro.bye_pro_finance.R.string.home)
        Section.DEBTS -> s(com.byepro.bye_pro_finance.R.string.debts)
        Section.AI -> s(com.byepro.bye_pro_finance.R.string.ai)
    }

    private fun recordTitle(record: FinanceRecord): String = when (record.kind) {
        "salary" -> s(com.byepro.bye_pro_finance.R.string.salary)
        "advance" -> s(com.byepro.bye_pro_finance.R.string.advance)
        "payment", "salaryPayment" -> s(com.byepro.bye_pro_finance.R.string.payment)
        "expense" -> categoryTitle(record.title)
        "creditor" -> s(com.byepro.bye_pro_finance.R.string.creditor_balance)
        "debtor" -> s(com.byepro.bye_pro_finance.R.string.debtor_balance)
        else -> record.title
    }

    private fun categoryTitle(category: String): String {
        val ar = localeCode == "ar"
        return when (category) {
            "groceries" -> if (ar) "مواد غذائية" else "Groceries"
            "utilities" -> if (ar) "فواتير وخدمات" else "Utilities"
            "housing" -> if (ar) "السكن" else "Housing"
            "cleaning" -> if (ar) "تنظيف" else "Cleaning"
            "maintenance" -> if (ar) "صيانة" else "Maintenance"
            "transport" -> if (ar) "مواصلات" else "Transport"
            "personal" -> if (ar) "شخصي" else "Personal"
            "health" -> if (ar) "صحة" else "Health"
            "other" -> if (ar) "أخرى" else "Other"
            else -> category
        }
    }

    private fun activityTitle(title: String): String = when (title) {
        "salary" -> s(com.byepro.bye_pro_finance.R.string.salary)
        "advance" -> s(com.byepro.bye_pro_finance.R.string.advance)
        "payment" -> s(com.byepro.bye_pro_finance.R.string.payment)
        "transfer_to_home" -> s(com.byepro.bye_pro_finance.R.string.transfer_to_home)
        "expense" -> s(com.byepro.bye_pro_finance.R.string.expense)
        "bill_payment" -> s(com.byepro.bye_pro_finance.R.string.bill_payment)
        "debt_created" -> s(com.byepro.bye_pro_finance.R.string.debt_created)
        "debt_payment" -> s(com.byepro.bye_pro_finance.R.string.debt_payment)
        else -> title
    }

    private fun activityGlyph(icon: String): String = when (icon) {
        "work" -> "▰"
        "home" -> "▤"
        "transfer" -> "⇄"
        "bill" -> "▣"
        else -> "↗"
    }

    private fun recordGlyph(kind: String): String = when (kind) {
        "salary" -> "▣"
        "advance" -> "↗"
        "payment" -> "↙"
        "creditor" -> "↙"
        "debtor" -> "↗"
        else -> "▤"
    }

    private fun makeText(value: String, sizeSp: Float, bold: Boolean): TextView =
        TextView(this).apply {
            text = value
            textSize = sizeSp
            setTextColor(FinancePalette.text(darkTheme))
            typeface = if (bold) Typeface.create("sans-serif-medium", Typeface.NORMAL)
                else Typeface.create("sans-serif", Typeface.NORMAL)
            gravity = Gravity.CENTER_VERTICAL
            textDirection = View.TEXT_DIRECTION_FIRST_STRONG
        }

    private fun addGap(heightDp: Int) {
        pageContent.addView(View(this), LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(heightDp)
        ))
    }

    private fun addGapTo(parent: LinearLayout, heightDp: Int) {
        parent.addView(View(this), LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(heightDp)
        ))
    }

    private fun formatAmount(amount: Long): String =
        DecimalFormat("#,##0", DecimalFormatSymbols.getInstance(Locale.US)).format(amount)

    private fun formatDate(epochMillis: Long): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(epochMillis))

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
