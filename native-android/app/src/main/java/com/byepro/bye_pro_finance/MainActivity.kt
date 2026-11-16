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
import android.view.ContextThemeWrapper
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.PopupMenu
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import com.byepro.bye_pro_finance.data.DashboardRepository
import com.byepro.bye_pro_finance.data.FinanceWriteRepository
import com.byepro.bye_pro_finance.data.FinanceRuleException
import com.byepro.bye_pro_finance.data.LegacyFinanceDatabase
import com.byepro.bye_pro_finance.domain.ActivityItem
import com.byepro.bye_pro_finance.domain.DashboardSummary
import com.byepro.bye_pro_finance.domain.FinanceRecord
import com.byepro.bye_pro_finance.ui.FinanceComponents
import com.byepro.bye_pro_finance.ui.FinanceDesignSystem
import com.byepro.bye_pro_finance.ui.FinanceDesignTokens
import com.byepro.bye_pro_finance.ui.FinanceNavigationItem
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
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(FinanceDesignTokens.APP_BAR_HEIGHT)
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
            setPadding(
                dp(FinanceDesignTokens.PAGE_HORIZONTAL_PADDING),
                dp(FinanceDesignTokens.PAGE_VERTICAL_PADDING),
                dp(FinanceDesignTokens.PAGE_HORIZONTAL_PADDING),
                dp(FinanceDesignTokens.PAGE_VERTICAL_PADDING)
            )
        }
        scrollView.addView(pageContent)
        root.addView(scrollView, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f
        ))

        navigation = buildNavigation()
        root.addView(navigation, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(FinanceDesignTokens.NAVIGATION_BAR_HEIGHT)
        ))
        setContentView(root)
    }

    private fun buildToolbar(): LinearLayout {
        val actions = mutableListOf<Pair<Int, Pair<String, () -> Unit>>>()
        if (activeSection == Section.WORK ||
            activeSection == Section.HOME ||
            activeSection == Section.DEBTS
        ) {
            actions += R.drawable.ic_add to (
                s(R.string.add_record) to {
                    showCreateMenu(root.getChildAt(0))
                }
            )
        }
        actions += R.drawable.ic_calendar to (
            s(R.string.calendar) to {
                showMonthPicker(root.getChildAt(0))
            }
        )
        actions += R.drawable.ic_calculator to (
            s(R.string.calculator) to { showCalculator() }
        )
        actions += R.drawable.ic_settings to (
            s(R.string.settings) to { showSettings() }
        )
        return FinanceComponents.topBar(
            context = this,
            isDark = darkTheme,
            title = sectionTitle(activeSection),
            actions = actions
        )
    }

    private fun buildBottomNavigationBar(): LinearLayout =
        FinanceComponents.bottomNavigation(
            this,
            darkTheme,
            listOf(
                FinanceNavigationItem(
                    s(R.string.dashboard), R.drawable.ic_dashboard,
                    activeSection == Section.DASHBOARD
                ) { activeSection = Section.DASHBOARD; renderCurrentSection() },
                FinanceNavigationItem(
                    s(R.string.work), R.drawable.ic_work,
                    activeSection == Section.WORK
                ) { activeSection = Section.WORK; renderCurrentSection() },
                FinanceNavigationItem(
                    s(R.string.home), R.drawable.ic_home,
                    activeSection == Section.HOME
                ) { activeSection = Section.HOME; renderCurrentSection() },
                FinanceNavigationItem(
                    s(R.string.debts), R.drawable.ic_debts,
                    activeSection == Section.DEBTS
                ) { activeSection = Section.DEBTS; renderCurrentSection() },
                FinanceNavigationItem(
                    s(R.string.ai), R.drawable.ic_ai,
                    activeSection == Section.AI
                ) { activeSection = Section.AI; renderCurrentSection() }
            )
        )

    private fun buildNavigation(): LinearLayout {
        navigation = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(FinancePalette.surface(darkTheme))
        }
        updateNavigationItems()
        return navigation
    }

    private fun updateNavigationItems() {
        navigation.removeAllViews()
        navigation.addView(
            FinanceComponents.bottomDivider(this, darkTheme),
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(FinanceDesignTokens.DIVIDER_HEIGHT)
            )
        )
        navigation.addView(
            buildBottomNavigationBar(),
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        )
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
        refreshToolbar()
        updateNavigationItems()
    }

    private fun refreshToolbar() {
        if (root.childCount == 0) return
        root.removeViewAt(0)
        root.addView(
            buildToolbar(),
            0,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(FinanceDesignTokens.APP_BAR_HEIGHT)
            )
        )
    }

    private fun renderDashboard() {
        val summary = repository.loadDashboard(selectedMonth)
        addMonthSelector(summary)
        addGap(16)
        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.financial_snapshot))
        addMetricGroup(
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.home_available_balance), summary.homeAvailableBalance, R.drawable.ic_payments, true),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.work_remaining), summary.workRemaining, R.drawable.ic_work),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.total_work_outstanding), summary.totalWorkOutstanding, R.drawable.ic_calendar)
        )

        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.work))
        addMetricGroup(
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.salary_total), summary.salaryTotal, R.drawable.ic_payments),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.advances_total), summary.advancesTotal, R.drawable.ic_advance),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.payments_total), summary.paymentsTotal, R.drawable.ic_payments),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.current_salary_outstanding), summary.currentSalaryOutstanding, R.drawable.ic_calendar)
        )

        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.home))
        addMetricGroup(
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.home_expenses_total), summary.homeExpensesTotal, R.drawable.ic_work),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.transfers_total), summary.transfersTotal, R.drawable.ic_transfer),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.bills_outstanding), summary.billsOutstanding, R.drawable.ic_payments),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.bills_paid), summary.billsPaid, R.drawable.ic_bill)
        )

        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.cash_flow))
        addCashFlowComparison(
            summary.transfersTotal,
            summary.homeExpensesTotal
        )

        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.debts))
        addMetricGroup(
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.creditor_balance), summary.creditorBalance, R.drawable.ic_payments),
            MetricDisplay(s(com.byepro.bye_pro_finance.R.string.debtor_balance), summary.debtorBalance, R.drawable.ic_advance)
        )

        addSectionHeading(s(com.byepro.bye_pro_finance.R.string.recent_activity))
        addActivityGroup(summary.recentActivity)
        addGap(8)
    }

    private fun addMonthSelector(summary: DashboardSummary) {
        // The month caption is a title, not a card. Only the date is interactive.
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(2), 0, dp(2))
        }

        val label = FinanceDesignSystem.text(
            this,
            s(R.string.month_shown),
            13f,
            FinancePalette.muted(darkTheme),
            bold = true
        )
        row.addView(label, LinearLayout.LayoutParams(
            0,
            dp(FinanceDesignTokens.BUTTON_HEIGHT),
            1f
        ))

        val month = FinanceDesignSystem.text(
            this,
            selectedMonth.toString() + "  ▾",
            14f,
            FinancePalette.accent(darkTheme),
            bold = true
        ).apply {
            gravity = Gravity.CENTER
            setPadding(dp(8), 0, dp(8), 0)
            minHeight = dp(FinanceDesignTokens.TOUCH_TARGET_SIZE)
            isClickable = true
            isFocusable = true
            contentDescription = s(R.string.month_shown) + ": " + selectedMonth
            setOnClickListener {
                showMonthPicker(this, summary.availableMonths)
            }
        }

        row.addView(month, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            dp(FinanceDesignTokens.TOUCH_TARGET_SIZE)
        ))

        pageContent.addView(row, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ))
    }

    private data class MetricDisplay(
        val label: String,
        val amount: Long,
        val icon: Int,
        val emphasized: Boolean = false
    )

    private fun addMetricGroup(vararg metrics: MetricDisplay) {
        val group = FinanceComponents.groupedList(this, darkTheme)
        metrics.forEachIndexed { index, metric ->
            if (index > 0) {
                group.addView(FinanceComponents.bottomDivider(this, darkTheme))
            }
            group.addView(
                FinanceComponents.metricRow(
                    context = this,
                    isDark = darkTheme,
                    iconResource = metric.icon,
                    title = metric.label,
                    value = formatAmount(metric.amount),
                    emphasized = metric.emphasized
                ),
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )
            )
        }
        pageContent.addView(group, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = dp(FinanceDesignTokens.SECTION_SPACING)
        })
    }

    private fun addSectionHeading(title: String) {
        pageContent.addView(
            FinanceComponents.sectionHeader(this, darkTheme, title),
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(FinanceDesignTokens.SECTION_HEADER_HEIGHT)
            )
        )
    }

    private fun addCashFlowComparison(transfers: Long, expenses: Long) {
        val total = maxOf(transfers, expenses, 1L).toFloat()
        val container = FinanceComponents.card(this, darkTheme)
        addComparisonBar(
            container,
            s(R.string.transfers_total),
            transfers,
            transfers / total
        )
        addGapTo(container, FinanceDesignTokens.SECTION_SPACING)
        addComparisonBar(
            container,
            s(R.string.home_expenses_total),
            expenses,
            expenses / total
        )
        pageContent.addView(container, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = dp(FinanceDesignTokens.SECTION_SPACING)
        })
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
            addEmptyState(s(R.string.no_recent_activity))
            return
        }
        val group = FinanceComponents.groupedList(this, darkTheme)
        items.forEachIndexed { index, item ->
            if (index > 0) {
                group.addView(FinanceComponents.bottomDivider(this, darkTheme))
            }
            group.addView(
                FinanceComponents.recordRow(
                    context = this,
                    isDark = darkTheme,
                    iconResource = activityIcon(item.icon),
                    title = activityTitle(item.title),
                    subtitle = item.subtitle.ifBlank { formatDate(item.timestamp) },
                    amount = formatAmount(item.amountMinorUnits)
                )
            )
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
        val group = FinanceComponents.groupedList(this, darkTheme)
        records.forEachIndexed { index, record ->
            if (index > 0) {
                group.addView(FinanceComponents.bottomDivider(this, darkTheme))
            }
            group.addView(
                FinanceComponents.recordRow(
                    context = this,
                    isDark = darkTheme,
                    iconResource = recordIcon(record.kind),
                    title = recordTitle(record),
                    subtitle = recordDetail(record),
                    amount = formatAmount(record.amountMinorUnits),
                    onClick = {
                        if (record.kind in setOf(
                            "bill", "creditor", "debtor", "debtPayment", "billPayment"
                        )) showRecordActions(group, record)
                    },
                    onLongClick = { showRecordActions(group, record) }
                )
            )
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

    private fun showCreateMenu(anchor: View) {
        val menu = PopupMenu(popupContext(), anchor)
        when (activeSection) {
            Section.WORK -> {
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.new_salary)) {
                    showWorkEntryForm("salary")
                }
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.new_advance)) {
                    showWorkEntryForm("advance")
                }
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.new_work_payment)) {
                    showWorkEntryForm("payment")
                }
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.new_transfer)) {
                    showTransferForm()
                }
            }
            Section.HOME -> {
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.new_expense)) {
                    showHomeExpenseForm()
                }
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.new_bill)) {
                    showBillForm()
                }
            }
            Section.DEBTS -> {
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.new_creditor)) {
                    showDebtForm("creditor")
                }
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.new_debtor)) {
                    showDebtForm("debtor")
                }
            }
            else -> Unit
        }
        menu.show()
    }

    private fun addMenuAction(menu: PopupMenu, title: String, action: () -> Unit) {
        menu.menu.add(title).setOnMenuItemClickListener {
            action()
            true
        }
    }

    private fun createForm(): LinearLayout = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        layoutDirection = View.LAYOUT_DIRECTION_RTL
        setPadding(
            dp(FinanceDesignTokens.CARD_PADDING),
            dp(FinanceDesignTokens.SECTION_SPACING),
            dp(FinanceDesignTokens.CARD_PADDING),
            dp(FinanceDesignTokens.SECTION_SPACING / 2)
        )
    }

    private fun formInput(
        form: LinearLayout,
        hint: String,
        initial: String = "",
        numeric: Boolean = false
    ): EditText {
        val multiline = hint == s(R.string.note_optional)
        val field = FinanceDesignSystem.input(
            context = this,
            isDark = darkTheme,
            hint = hint,
            initialValue = initial,
            numeric = numeric,
            multiline = multiline
        )
        form.addView(field, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            if (multiline) dp(80) else dp(FinanceDesignTokens.BUTTON_HEIGHT)
        ).apply {
            bottomMargin = dp(FinanceDesignTokens.SECTION_SPACING / 2)
        })
        return field
    }

    private data class DateField(
        val view: TextView,
        val value: () -> Long
    )

    private fun addDateField(
        form: LinearLayout,
        label: String,
        initialEpochMillis: Long
    ): DateField {
        var selectedMillis = initialEpochMillis
        val view = FinanceDesignSystem.text(
            this, "", 14f, FinancePalette.accent(darkTheme), bold = true
        ).apply {
            setPadding(dp(14), 0, dp(14), 0)
            background = FinanceDesignSystem.rounded(
                this@MainActivity,
                FinancePalette.raised(darkTheme),
                FinanceDesignTokens.CONTROL_RADIUS
            )
            minHeight = dp(FinanceDesignTokens.BUTTON_HEIGHT)
            isClickable = true
            isFocusable = true
        }
        fun refresh() {
            view.text = "$label: ${formatDate(selectedMillis)}  ▾"
        }
        refresh()
        view.setOnClickListener {
            val calendar = java.util.Calendar.getInstance().apply {
                timeInMillis = selectedMillis
            }
            DatePickerDialog(
                ContextThemeWrapper(
                    this,
                    if (darkTheme) R.style.NativeFinanceDialogDarkTheme
                    else R.style.NativeFinanceDialogLightTheme
                ),
                { _, year, month, day ->
                    val date = java.util.Calendar.getInstance().apply {
                        set(year, month, day, calendar.get(java.util.Calendar.HOUR_OF_DAY),
                            calendar.get(java.util.Calendar.MINUTE), 0)
                        set(java.util.Calendar.MILLISECOND, 0)
                    }
                    selectedMillis = date.timeInMillis
                    refresh()
                },
                calendar.get(java.util.Calendar.YEAR),
                calendar.get(java.util.Calendar.MONTH),
                calendar.get(java.util.Calendar.DAY_OF_MONTH)
            ).show()
        }
        form.addView(view, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(FinanceDesignTokens.BUTTON_HEIGHT)
        ).apply {
            topMargin = dp(FinanceDesignTokens.SECTION_SPACING / 2)
            bottomMargin = dp(FinanceDesignTokens.SECTION_SPACING / 2)
        })
        return DateField(view) { selectedMillis }
    }

    private fun showWorkEntryForm(kind: String, existing: FinanceRecord? = null) {
        val form = createForm()
        val amount = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.amount),
            existing?.amountMinorUnits?.toString().orEmpty(),
            numeric = true
        )
        val note = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.note_optional),
            existing?.note.orEmpty()
        )
        val dueYear = existing?.dueYear ?: selectedMonth.year
        val dueMonth = existing?.dueMonth ?: selectedMonth.monthValue

        dialogBuilder()
            .setTitle(
                when (kind) {
                    "salary" -> s(com.byepro.bye_pro_finance.R.string.new_salary)
                    "advance" -> s(com.byepro.bye_pro_finance.R.string.new_advance)
                    else -> s(com.byepro.bye_pro_finance.R.string.new_work_payment)
                }
            )
            .setView(form)
            .setPositiveButton(s(com.byepro.bye_pro_finance.R.string.save)) { _, _ ->
                val value = amount.text.toString().trim().toLongOrNull()
                if (value == null || value <= 0L) {
                    showRuleMessage(FinanceRuleException(FinanceRuleException.Rule.INVALID_AMOUNT))
                    return@setPositiveButton
                }
                try {
                    writeRepository.saveWorkEntry(
                        id = existing?.id ?: UUID.randomUUID().toString(),
                        kind = existing?.kind ?: kind,
                        amountMinorUnits = value,
                        dueYear = dueYear,
                        dueMonth = dueMonth,
                        recordedAtEpochMillis = existing?.timestamp ?: System.currentTimeMillis(),
                        note = note.text.toString().trim().ifEmpty { null }
                    )
                    showToast(s(com.byepro.bye_pro_finance.R.string.saved_successfully))
                    renderCurrentSection()
                } catch (error: Throwable) {
                    showRuleMessage(error)
                }
            }
            .setNegativeButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
            .show()
    }

    private fun showTransferForm(existing: FinanceRecord? = null) {
        val form = createForm()
        val amount = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.amount),
            existing?.amountMinorUnits?.toString().orEmpty(),
            numeric = true
        )
        val note = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.note_optional),
            existing?.note.orEmpty()
        )
        val date = addDateField(
            form,
            s(com.byepro.bye_pro_finance.R.string.payment_date),
            existing?.timestamp ?: System.currentTimeMillis()
        )

        dialogBuilder()
            .setTitle(s(com.byepro.bye_pro_finance.R.string.new_transfer))
            .setView(form)
            .setPositiveButton(s(com.byepro.bye_pro_finance.R.string.save)) { _, _ ->
                val value = amount.text.toString().trim().toLongOrNull()
                if (value == null || value <= 0L) {
                    showRuleMessage(FinanceRuleException(FinanceRuleException.Rule.INVALID_AMOUNT))
                    return@setPositiveButton
                }
                try {
                    writeRepository.saveTransfer(
                        id = existing?.id ?: UUID.randomUUID().toString(),
                        amountMinorUnits = value,
                        transferredAtEpochMillis = date.value(),
                        note = note.text.toString().trim().ifEmpty { null }
                    )
                    showToast(s(com.byepro.bye_pro_finance.R.string.saved_successfully))
                    renderCurrentSection()
                } catch (error: Throwable) {
                    showRuleMessage(error)
                }
            }
            .setNegativeButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
            .show()
    }

    private fun showHomeExpenseForm(existing: FinanceRecord? = null) {
        val form = createForm()
        val amount = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.amount),
            existing?.amountMinorUnits?.toString().orEmpty(),
            numeric = true
        )
        val categories = listOf(
            "groceries", "utilities", "housing", "cleaning", "maintenance",
            "transport", "personal", "health", "other"
        )
        val category = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.category),
            existing?.categoryId ?: "other"
        )
        val note = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.note_optional),
            existing?.note.orEmpty()
        )
        val date = addDateField(
            form,
            s(com.byepro.bye_pro_finance.R.string.payment_date),
            existing?.timestamp ?: System.currentTimeMillis()
        )
        val dueYear = existing?.dueYear ?: selectedMonth.year
        val dueMonth = existing?.dueMonth ?: selectedMonth.monthValue

        dialogBuilder()
            .setTitle(s(com.byepro.bye_pro_finance.R.string.new_expense))
            .setView(form)
            .setPositiveButton(s(com.byepro.bye_pro_finance.R.string.save)) { _, _ ->
                val value = amount.text.toString().trim().toLongOrNull()
                val categoryId = category.text.toString().trim()
                if (value == null || value <= 0L || categoryId.isBlank()) {
                    showRuleMessage(FinanceRuleException(FinanceRuleException.Rule.INVALID_AMOUNT))
                    return@setPositiveButton
                }
                try {
                    writeRepository.saveHomeExpense(
                        id = existing?.id ?: UUID.randomUUID().toString(),
                        amountMinorUnits = value,
                        categoryId = categoryId,
                        expenseDateEpochMillis = date.value(),
                        dueYear = dueYear,
                        dueMonth = dueMonth,
                        note = note.text.toString().trim().ifEmpty { null }
                    )
                    showToast(s(com.byepro.bye_pro_finance.R.string.saved_successfully))
                    renderCurrentSection()
                } catch (error: Throwable) {
                    showRuleMessage(error)
                }
            }
            .setNegativeButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
            .show()
    }

    private fun showDebtForm(direction: String, existing: FinanceRecord? = null) {
        val form = createForm()
        val counterparty = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.counterparty),
            existing?.title.orEmpty()
        )
        val originalAmount = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.amount),
            (existing?.originalAmountMinorUnits ?: existing?.amountMinorUnits)
                ?.toString().orEmpty(),
            numeric = true
        )
        val note = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.note_optional),
            existing?.note.orEmpty()
        )
        val dueYear = existing?.dueYear ?: selectedMonth.year
        val dueMonth = existing?.dueMonth ?: selectedMonth.monthValue

        dialogBuilder()
            .setTitle(
                if (direction == "creditor")
                    s(com.byepro.bye_pro_finance.R.string.new_creditor)
                else s(com.byepro.bye_pro_finance.R.string.new_debtor)
            )
            .setView(form)
            .setPositiveButton(s(com.byepro.bye_pro_finance.R.string.save)) { _, _ ->
                val party = counterparty.text.toString().trim()
                val value = originalAmount.text.toString().trim().toLongOrNull()
                if (party.isBlank() || value == null || value <= 0L) {
                    showRuleMessage(FinanceRuleException(FinanceRuleException.Rule.INVALID_AMOUNT))
                    return@setPositiveButton
                }
                try {
                    writeRepository.saveDebt(
                        id = existing?.id ?: UUID.randomUUID().toString(),
                        direction = existing?.kind ?: direction,
                        originalAmountMinorUnits = value,
                        outstandingAmountMinorUnits = existing?.amountMinorUnits ?: value,
                        dueYear = dueYear,
                        dueMonth = dueMonth,
                        createdAtEpochMillis = existing?.timestamp ?: System.currentTimeMillis(),
                        counterparty = party,
                        note = note.text.toString().trim().ifEmpty { null }
                    )
                    showToast(s(com.byepro.bye_pro_finance.R.string.saved_successfully))
                    renderCurrentSection()
                } catch (error: Throwable) {
                    showRuleMessage(error)
                }
            }
            .setNegativeButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
            .show()
    }

    private fun showBillForm(existing: FinanceRecord? = null) {
        val form = createForm()
        val title = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.bill_title),
            existing?.title.orEmpty()
        )
        val amount = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.amount),
            (existing?.originalAmountMinorUnits ?: existing?.amountMinorUnits)
                ?.toString().orEmpty(),
            numeric = true
        )
        val note = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.note_optional),
            existing?.note.orEmpty()
        )
        val dueYear = existing?.dueYear ?: selectedMonth.year
        val dueMonth = existing?.dueMonth ?: selectedMonth.monthValue
        val kind = if (existing?.detail?.startsWith("rent") == true) "rent" else "monthly"

        dialogBuilder()
            .setTitle(s(com.byepro.bye_pro_finance.R.string.new_bill))
            .setView(form)
            .setPositiveButton(s(com.byepro.bye_pro_finance.R.string.save)) { _, _ ->
                val name = title.text.toString().trim()
                val value = amount.text.toString().trim().toLongOrNull()
                if (name.isBlank() || value == null || value <= 0L) {
                    showRuleMessage(FinanceRuleException(FinanceRuleException.Rule.INVALID_AMOUNT))
                    return@setPositiveButton
                }
                try {
                    writeRepository.saveBill(
                        id = existing?.id ?: UUID.randomUUID().toString(),
                        title = name,
                        kind = kind,
                        amountMinorUnits = value,
                        dueYear = dueYear,
                        dueMonth = dueMonth,
                        note = note.text.toString().trim().ifEmpty { null }
                    )
                    showToast(s(com.byepro.bye_pro_finance.R.string.saved_successfully))
                    renderCurrentSection()
                } catch (error: Throwable) {
                    showRuleMessage(error)
                }
            }
            .setNegativeButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
            .show()
    }

    private fun showDebtPaymentForm(debt: FinanceRecord) {
        val form = createForm()
        form.addView(makeText(
            s(com.byepro.bye_pro_finance.R.string.remaining_amount) + ": " +
                formatAmount(debt.amountMinorUnits),
            14f,
            true
        ))
        val amount = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.amount),
            numeric = true
        )
        val note = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.note_optional)
        )
        dialogBuilder()
            .setTitle(s(com.byepro.bye_pro_finance.R.string.record_payment))
            .setView(form)
            .setPositiveButton(s(com.byepro.bye_pro_finance.R.string.save)) { _, _ ->
                val value = amount.text.toString().trim().toLongOrNull()
                if (value == null || value <= 0L) {
                    showRuleMessage(FinanceRuleException(FinanceRuleException.Rule.INVALID_AMOUNT))
                    return@setPositiveButton
                }
                try {
                    writeRepository.recordDebtPayment(
                        id = UUID.randomUUID().toString(),
                        debtId = debt.id,
                        amountMinorUnits = value,
                        paidAtEpochMillis = System.currentTimeMillis(),
                        note = note.text.toString().trim().ifEmpty { null }
                    )
                    showToast(s(com.byepro.bye_pro_finance.R.string.payment_saved))
                    renderCurrentSection()
                } catch (error: Throwable) {
                    showRuleMessage(error)
                }
            }
            .setNegativeButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
            .show()
    }

    private fun showBillPaymentForm(bill: FinanceRecord) {
        val form = createForm()
        form.addView(makeText(
            s(com.byepro.bye_pro_finance.R.string.remaining_amount) + ": " +
                formatAmount(bill.amountMinorUnits),
            14f,
            true
        ))
        val amount = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.amount),
            numeric = true
        )
        val note = formInput(
            form,
            s(com.byepro.bye_pro_finance.R.string.note_optional)
        )
        dialogBuilder()
            .setTitle(s(com.byepro.bye_pro_finance.R.string.pay_bill))
            .setView(form)
            .setPositiveButton(s(com.byepro.bye_pro_finance.R.string.save)) { _, _ ->
                val value = amount.text.toString().trim().toLongOrNull()
                if (value == null || value <= 0L) {
                    showRuleMessage(FinanceRuleException(FinanceRuleException.Rule.INVALID_AMOUNT))
                    return@setPositiveButton
                }
                try {
                    writeRepository.recordBillPayment(
                        id = UUID.randomUUID().toString(),
                        billId = bill.id,
                        amountMinorUnits = value,
                        paidAtEpochMillis = System.currentTimeMillis(),
                        note = note.text.toString().trim().ifEmpty { null }
                    )
                    showToast(s(com.byepro.bye_pro_finance.R.string.payment_saved))
                    renderCurrentSection()
                } catch (error: Throwable) {
                    showRuleMessage(error)
                }
            }
            .setNegativeButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
            .show()
    }

    private fun showRecordActions(anchor: View, record: FinanceRecord) {
        val menu = PopupMenu(popupContext(), anchor)
        when (record.kind) {
            "creditor", "debtor" -> {
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.record_payment)) {
                    showDebtPaymentForm(record)
                }
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.payment_history)) {
                    showPaymentHistory(record, debtPayments = true)
                }
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.edit)) {
                    showDebtForm(record.kind, record)
                }
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.delete)) {
                    confirmDeleteRecord(record)
                }
            }
            "bill" -> {
                if (record.amountMinorUnits > 0L) {
                    addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.pay_bill)) {
                        showBillPaymentForm(record)
                    }
                }
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.payment_history)) {
                    showPaymentHistory(record, debtPayments = false)
                }
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.edit)) {
                    showBillForm(record)
                }
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.delete)) {
                    confirmDeleteRecord(record)
                }
            }
            "debtPayment", "billPayment" -> {
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.undo_payment)) {
                    confirmUndoPayment(record)
                }
            }
            else -> {
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.edit)) {
                    when (record.kind) {
                        "transfer" -> showTransferForm(record)
                        "expense" -> showHomeExpenseForm(record)
                        else -> showWorkEntryForm(record.kind, record)
                    }
                }
                addMenuAction(menu, s(com.byepro.bye_pro_finance.R.string.delete)) {
                    confirmDeleteRecord(record)
                }
            }
        }
        menu.show()
    }

    private fun showPaymentHistory(record: FinanceRecord, debtPayments: Boolean) {
        val payments = if (debtPayments) {
            repository.loadDebtPayments(record.id)
        } else {
            repository.loadBillPayments(record.id)
        }
        if (payments.isEmpty()) {
            dialogBuilder()
                .setTitle(s(com.byepro.bye_pro_finance.R.string.payment_history))
                .setMessage(s(com.byepro.bye_pro_finance.R.string.no_payment_history))
                .setPositiveButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
                .show()
            return
        }
        val items = payments.map {
            formatDate(it.timestamp) + " • " + formatAmount(it.amountMinorUnits)
        }.toTypedArray()
        dialogBuilder()
            .setTitle(s(com.byepro.bye_pro_finance.R.string.payment_history))
            .setItems(items) { _, index ->
                confirmUndoPayment(payments[index])
            }
            .setNegativeButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
            .show()
    }

    private fun confirmUndoPayment(payment: FinanceRecord) {
        dialogBuilder()
            .setTitle(s(com.byepro.bye_pro_finance.R.string.undo_payment))
            .setMessage(formatDate(payment.timestamp) + " • " +
                formatAmount(payment.amountMinorUnits))
            .setPositiveButton(s(com.byepro.bye_pro_finance.R.string.undo_payment)) { _, _ ->
                try {
                    if (payment.kind == "debtPayment") {
                        writeRepository.undoDebtPayment(payment.id)
                    } else {
                        writeRepository.undoBillPayment(payment.id)
                    }
                    showToast(s(com.byepro.bye_pro_finance.R.string.deleted_successfully))
                    renderCurrentSection()
                } catch (error: Throwable) {
                    showRuleMessage(error)
                }
            }
            .setNegativeButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
            .show()
    }

    private fun confirmDeleteRecord(record: FinanceRecord) {
        dialogBuilder()
            .setTitle(s(com.byepro.bye_pro_finance.R.string.delete))
            .setMessage(s(com.byepro.bye_pro_finance.R.string.confirm_delete))
            .setPositiveButton(s(com.byepro.bye_pro_finance.R.string.delete)) { _, _ ->
                try {
                    when (record.kind) {
                        "transfer" -> writeRepository.deleteTransfer(record.id)
                        "expense" -> writeRepository.deleteHomeExpense(record.id)
                        "creditor", "debtor" -> writeRepository.deleteDebt(record.id)
                        "bill" -> writeRepository.deleteBill(record.id)
                        else -> writeRepository.deleteWorkEntry(record.id)
                    }
                    showToast(s(com.byepro.bye_pro_finance.R.string.deleted_successfully))
                    renderCurrentSection()
                } catch (error: Throwable) {
                    showRuleMessage(error)
                }
            }
            .setNegativeButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
            .show()
    }

    private fun dialogBuilder(): AlertDialog.Builder =
        AlertDialog.Builder(
            this,
            if (darkTheme) R.style.NativeFinanceDialogDarkTheme
            else R.style.NativeFinanceDialogLightTheme
        )

    private fun popupContext(): Context = ContextThemeWrapper(
        this,
        if (darkTheme) R.style.NativeFinancePopupDarkTheme
        else R.style.NativeFinancePopupLightTheme
    )

    private fun showRuleMessage(error: Throwable) {
        val resource = when ((error as? FinanceRuleException)?.rule) {
            FinanceRuleException.Rule.INVALID_AMOUNT,
            FinanceRuleException.Rule.INVALID_MONTH ->
                com.byepro.bye_pro_finance.R.string.invalid_amount
            FinanceRuleException.Rule.INSUFFICIENT_WORK_BALANCE ->
                com.byepro.bye_pro_finance.R.string.insufficient_work_balance
            FinanceRuleException.Rule.TRANSFER_WOULD_OVERDRAW_HOME ->
                com.byepro.bye_pro_finance.R.string.transfer_overdraw_warning
            FinanceRuleException.Rule.INSUFFICIENT_HOME_BALANCE ->
                com.byepro.bye_pro_finance.R.string.insufficient_home_balance
            FinanceRuleException.Rule.DEBT_PAYMENT_EXCEEDS_BALANCE ->
                com.byepro.bye_pro_finance.R.string.debt_payment_exceeds
            FinanceRuleException.Rule.BILL_PAYMENT_EXCEEDS_BALANCE ->
                com.byepro.bye_pro_finance.R.string.bill_payment_exceeds
            FinanceRuleException.Rule.DEBT_HAS_PAYMENT_HISTORY,
            FinanceRuleException.Rule.BILL_HAS_PAYMENT_HISTORY ->
                com.byepro.bye_pro_finance.R.string.record_has_payment_history
            FinanceRuleException.Rule.BILL_AMOUNT_BELOW_PAYMENTS ->
                com.byepro.bye_pro_finance.R.string.bill_payment_exceeds
            FinanceRuleException.Rule.DEBT_BALANCE_DOES_NOT_MATCH_HISTORY ->
                com.byepro.bye_pro_finance.R.string.debt_payment_exceeds
            FinanceRuleException.Rule.INSUFFICIENT_BILL_PAYMENT_BALANCE ->
                com.byepro.bye_pro_finance.R.string.insufficient_home_balance
            FinanceRuleException.Rule.RECORD_NOT_FOUND -> 
                com.byepro.bye_pro_finance.R.string.data_error
            null -> com.byepro.bye_pro_finance.R.string.data_error
        }
        dialogBuilder()
            .setMessage(s(resource))
            .setPositiveButton(s(com.byepro.bye_pro_finance.R.string.cancel), null)
            .show()
    }

    private fun showToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }

    private fun showMonthPicker(anchor: View, months: List<YearMonth>? = null) {
        val available = months ?: repository.loadDashboard(selectedMonth).availableMonths
        val popup = PopupMenu(popupContext(), anchor)
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
        val first = FinanceDesignSystem.input(
            context = this,
            isDark = darkTheme,
            hint = s(R.string.enter_amount),
            numeric = true
        )
        val second = FinanceDesignSystem.input(
            context = this,
            isDark = darkTheme,
            hint = s(R.string.enter_amount),
            numeric = true
        )
        form.addView(first)
        form.addView(second)
        dialogBuilder()
            .setTitle(s(com.byepro.bye_pro_finance.R.string.calculator))
            .setView(form)
            .setPositiveButton(s(com.byepro.bye_pro_finance.R.string.result)) { _, _ ->
                val a = first.text.toString().toLongOrNull() ?: 0L
                val b = second.text.toString().toLongOrNull() ?: 0L
                dialogBuilder()
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
        dialogBuilder()
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
        "salary" -> s(R.string.salary)
        "advance" -> s(R.string.advance)
        "payment", "salaryPayment" -> s(R.string.payment)
        "transfer" -> s(R.string.transfer_to_home)
        "expense" -> categoryTitle(record.title)
        "creditor" -> record.title
        "debtor" -> record.title
        "bill" -> record.title
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

    private fun activityIcon(icon: String): Int = when (icon) {
        "work" -> R.drawable.ic_work
        "home" -> R.drawable.ic_expense
        "transfer" -> R.drawable.ic_transfer
        "bill" -> R.drawable.ic_bill
        else -> R.drawable.ic_debts
    }

    private fun recordIcon(kind: String): Int = when (kind) {
        "salary" -> R.drawable.ic_payments
        "advance" -> R.drawable.ic_advance
        "payment", "salaryPayment" -> R.drawable.ic_payments
        "transfer" -> R.drawable.ic_transfer
        "expense" -> R.drawable.ic_expense
        "bill", "billPayment" -> R.drawable.ic_bill
        "creditor", "debtor", "debtPayment" -> R.drawable.ic_debts
        else -> R.drawable.ic_work
    }

    private fun recordDetail(record: FinanceRecord): String {
        val parts = mutableListOf<String>()
        when (record.kind) {
            "salary", "advance", "payment", "salaryPayment", "bill" -> {
                if (record.dueYear != null && record.dueMonth != null) {
                    parts.add("%04d-%02d".format(record.dueYear, record.dueMonth))
                }
            }
            else -> if (record.timestamp > 0L) parts.add(formatDate(record.timestamp))
        }
        record.note?.takeIf { it.isNotBlank() }?.let(parts::add)
        if (record.note.isNullOrBlank() && record.detail.isNotBlank()) {
            if (record.kind == "bill") {
                val type = if (record.detail.startsWith("rent")) {
                    s(R.string.rent_bill)
                } else {
                    s(R.string.monthly_bill)
                }
                parts.add(type)
            } else if (record.kind == "creditor") {
                parts.add(s(R.string.creditor_balance))
            } else if (record.kind == "debtor") {
                parts.add(s(R.string.debtor_balance))
            }
        }
        return parts.joinToString(" • ")
    }

    private fun makeText(value: String, sizeSp: Float, bold: Boolean): TextView =
        FinanceDesignSystem.text(
            context = this,
            value = value,
            sizeSp = sizeSp,
            color = FinancePalette.text(darkTheme),
            bold = bold
        )

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
