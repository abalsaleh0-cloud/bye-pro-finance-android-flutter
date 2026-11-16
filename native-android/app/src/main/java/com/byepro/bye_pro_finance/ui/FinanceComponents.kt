package com.byepro.bye_pro_finance.ui

import android.content.Context
import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

data class FinanceNavigationItem(
    val title: String,
    val iconResource: Int,
    val selected: Boolean,
    val onClick: () -> Unit
)

object FinanceComponents {

    fun topBar(
        context: Context,
        isDark: Boolean,
        title: String,
        actions: List<Pair<Int, Pair<String, () -> Unit>>>
    ): LinearLayout {
        val palette = FinanceDesignSystem.colors(isDark)
        val bar = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(
                FinanceDesignSystem.dp(context, FinanceDesignTokens.PAGE_HORIZONTAL_PADDING),
                0,
                FinanceDesignSystem.dp(context, 8),
                0
            )
            setBackgroundColor(palette.background)
        }

        val heading = FinanceDesignSystem.text(
            context, title, 20f, palette.text, bold = true
        )
        bar.addView(heading, LinearLayout.LayoutParams(0,
            FinanceDesignSystem.dp(context, FinanceDesignTokens.APP_BAR_HEIGHT), 1f))

        actions.forEach { (icon, descriptor) ->
            val action = FinanceDesignSystem.iconAction(
                context, isDark, icon, descriptor.first, descriptor.second
            )
            bar.addView(action, LinearLayout.LayoutParams(
                FinanceDesignSystem.dp(context, FinanceDesignTokens.TOUCH_TARGET_SIZE),
                FinanceDesignSystem.dp(context, FinanceDesignTokens.TOUCH_TARGET_SIZE)
            ))
        }
        return bar
    }

    fun bottomNavigation(
        context: Context,
        isDark: Boolean,
        items: List<FinanceNavigationItem>
    ): LinearLayout {
        val palette = FinanceDesignSystem.colors(isDark)
        val bar = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(
                FinanceDesignSystem.dp(context, 4),
                FinanceDesignSystem.dp(context, 4),
                FinanceDesignSystem.dp(context, 4),
                FinanceDesignSystem.dp(context, 4)
            )
            setBackgroundColor(palette.surface)
        }

        items.forEach { item ->
            val cell = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                isClickable = true
                isFocusable = true
                setOnClickListener { item.onClick() }
                setPadding(
                    FinanceDesignSystem.dp(context, 2),
                    FinanceDesignSystem.dp(context, 2),
                    FinanceDesignSystem.dp(context, 2),
                    FinanceDesignSystem.dp(context, 2)
                )
            }

            val iconHolder = FrameLayout(context).apply {
                // Telegram-style navigation has no filled selected pill:
                // selection is communicated by icon and label color only.
                setBackgroundColor(0x00000000)
                val icon = ImageView(context).apply {
                    setImageResource(item.iconResource)
                    setColorFilter(if (item.selected) palette.accent else palette.secondaryText)
                    scaleType = ImageView.ScaleType.CENTER_INSIDE
                }
                addView(icon, FrameLayout.LayoutParams(
                    FinanceDesignSystem.dp(context, FinanceDesignTokens.STANDARD_ICON_SIZE),
                    FinanceDesignSystem.dp(context, FinanceDesignTokens.STANDARD_ICON_SIZE),
                    Gravity.CENTER
                ))
            }
            cell.addView(iconHolder, LinearLayout.LayoutParams(
                FinanceDesignSystem.dp(context, 38),
                FinanceDesignSystem.dp(context, 30)
            ))

            val label = FinanceDesignSystem.text(
                context,
                item.title,
                11f,
                if (item.selected) palette.accent else palette.secondaryText,
                bold = item.selected
            ).apply {
                gravity = Gravity.CENTER
                maxLines = 1
            }
            cell.addView(label, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                FinanceDesignSystem.dp(context, 20)
            ))
            bar.addView(cell, LinearLayout.LayoutParams(
                0,
                FinanceDesignSystem.dp(context, FinanceDesignTokens.NAVIGATION_BAR_HEIGHT - 8),
                1f
            ))
        }
        return bar
    }

    fun sectionHeader(
        context: Context,
        isDark: Boolean,
        title: String,
        trailing: String? = null
    ): LinearLayout {
        val palette = FinanceDesignSystem.colors(isDark)
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            gravity = Gravity.CENTER_VERTICAL
            val heading = FinanceDesignSystem.sectionTitle(context, title, isDark)
            addView(heading, LinearLayout.LayoutParams(0,
                FinanceDesignSystem.dp(context, FinanceDesignTokens.SECTION_HEADER_HEIGHT), 1f))
            if (!trailing.isNullOrBlank()) {
                addView(FinanceDesignSystem.text(
                    context, trailing, 12f, palette.accent, bold = true
                ))
            }
        }
    }

    fun metricRow(
        context: Context,
        isDark: Boolean,
        iconResource: Int,
        title: String,
        value: String,
        emphasized: Boolean = false
    ): LinearLayout {
        val palette = FinanceDesignSystem.colors(isDark)
        val row = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            gravity = Gravity.CENTER_VERTICAL
            minimumHeight = FinanceDesignSystem.dp(
                context, FinanceDesignTokens.METRIC_TILE_MIN_HEIGHT / 2
            )
            setPadding(
                FinanceDesignSystem.dp(context, 12),
                FinanceDesignSystem.dp(context, 8),
                FinanceDesignSystem.dp(context, 12),
                FinanceDesignSystem.dp(context, 8)
            )
        }
        val icon = FinanceDesignSystem.iconBox(context, isDark, iconResource, emphasized)
        row.addView(icon, LinearLayout.LayoutParams(
            FinanceDesignSystem.dp(context, FinanceDesignTokens.RECORD_ICON_BOX_SIZE),
            FinanceDesignSystem.dp(context, FinanceDesignTokens.RECORD_ICON_BOX_SIZE)
        ))

        val label = FinanceDesignSystem.text(
            context, title, 14f,
            if (emphasized) palette.accent else palette.text,
            bold = emphasized
        ).apply {
            setPadding(FinanceDesignSystem.dp(context, 12), 0,
                FinanceDesignSystem.dp(context, 6), 0)
            maxLines = 2
        }
        row.addView(label, LinearLayout.LayoutParams(0,
            FinanceDesignSystem.dp(context, FinanceDesignTokens.BUTTON_HEIGHT), 1f))

        val amount = FinanceDesignSystem.text(
            context, value, 16f,
            if (emphasized) palette.accent else palette.text,
            bold = true
        )
        row.addView(amount, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            FinanceDesignSystem.dp(context, FinanceDesignTokens.BUTTON_HEIGHT)
        ))
        return row
    }

    fun recordRow(
        context: Context,
        isDark: Boolean,
        iconResource: Int,
        title: String,
        subtitle: String,
        amount: String,
        onClick: (() -> Unit)? = null,
        onLongClick: (() -> Unit)? = null
    ): LinearLayout {
        val palette = FinanceDesignSystem.colors(isDark)
        val row = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            gravity = Gravity.CENTER_VERTICAL
            minimumHeight = FinanceDesignSystem.dp(
                context, FinanceDesignTokens.RECORD_ROW_HEIGHT
            )
            setPadding(
                FinanceDesignSystem.dp(context, 12),
                FinanceDesignSystem.dp(context, 8),
                FinanceDesignSystem.dp(context, 12),
                FinanceDesignSystem.dp(context, 8)
            )
        }

        val icon = FinanceDesignSystem.iconBox(context, isDark, iconResource)
        row.addView(icon, LinearLayout.LayoutParams(
            FinanceDesignSystem.dp(context, FinanceDesignTokens.RECORD_ICON_BOX_SIZE),
            FinanceDesignSystem.dp(context, FinanceDesignTokens.RECORD_ICON_BOX_SIZE)
        ))

        val detail = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(FinanceDesignSystem.dp(context, 12), 0,
                FinanceDesignSystem.dp(context, 8), 0)
        }
        detail.addView(FinanceDesignSystem.text(
            context, title, 14f, palette.text, bold = true
        ))
        if (subtitle.isNotBlank()) {
            detail.addView(FinanceDesignSystem.text(
                context, subtitle, 12f, palette.secondaryText
            ).apply { maxLines = 1 })
        }
        row.addView(detail, LinearLayout.LayoutParams(0,
            FinanceDesignSystem.dp(context, FinanceDesignTokens.RECORD_ROW_HEIGHT), 1f))

        row.addView(FinanceDesignSystem.text(
            context, amount, 15f, palette.text, bold = true
        ))
        if (onClick != null) {
            row.isClickable = true
            row.isFocusable = true
            row.setOnClickListener { onClick() }
        }
        if (onLongClick != null) {
            row.isLongClickable = true
            row.setOnLongClickListener {
                onLongClick()
                true
            }
        }
        return row
    }

    /** A grouped Telegram-style list surface: the rows provide their own
     * horizontal insets, so the container itself must not add another 16dp. */
    fun groupedList(context: Context, isDark: Boolean): LinearLayout =
        FinanceDesignSystem.surface(
            context,
            isDark,
            padding = 0,
            radius = FinanceDesignTokens.CARD_RADIUS
        )

    /** A content card for charts or panels that need their own inner padding. */
    fun card(context: Context, isDark: Boolean): LinearLayout =
        FinanceDesignSystem.surface(
            context,
            isDark,
            FinanceDesignTokens.CARD_PADDING,
            FinanceDesignTokens.CARD_RADIUS
        )

    fun bottomDivider(context: Context, isDark: Boolean): View =
        FinanceDesignSystem.divider(context, isDark)
}
