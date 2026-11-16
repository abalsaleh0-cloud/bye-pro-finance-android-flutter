package com.byepro.bye_pro_finance.ui

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Single source of truth for the native Android interface.
 *
 * Values match the shared app-wide design contract: all surfaces, controls,
 * cards, navigation items and dialog inputs use these tokens.
 */
object FinanceDesignTokens {
    const val PAGE_HORIZONTAL_PADDING = 16
    const val PAGE_VERTICAL_PADDING = 12
    const val SECTION_SPACING = 12
    const val CARD_PADDING = 16
    const val INPUT_VERTICAL_PADDING = 12
    const val APP_BAR_HEIGHT = 56
    const val CARD_RADIUS = 16
    const val CONTROL_RADIUS = 12
    const val DIALOG_RADIUS = 20
    const val BUTTON_HEIGHT = 48
    const val TOUCH_TARGET_SIZE = 44
    const val NAVIGATION_BAR_HEIGHT = 68
    const val SECTION_TAB_HEIGHT = 48
    const val SECTION_HEADER_HEIGHT = 36
    const val METRIC_TILE_MIN_HEIGHT = 64
    const val RECORD_ICON_BOX_SIZE = 40
    const val STANDARD_ICON_SIZE = 20
    const val DIVIDER_HEIGHT = 1
    const val RECORD_ROW_HEIGHT = 64
    const val MOTION_DURATION_MS = 160L
}

data class FinanceDesignColors(
    val background: Int,
    val surface: Int,
    val raised: Int,
    val text: Int,
    val secondaryText: Int,
    val accent: Int,
    val onAccent: Int,
    val accentSoft: Int,
    val divider: Int,
    val danger: Int,
    val positive: Int
)

object FinanceDesignSystem {
    val dark = FinanceDesignColors(
        background = 0xFF17212B.toInt(),
        surface = 0xFF202B36.toInt(),
        raised = 0xFF263442.toInt(),
        text = 0xFFF2F5F8.toInt(),
        secondaryText = 0xFF91A0AE.toInt(),
        accent = 0xFF5AA7E8.toInt(),
        onAccent = 0xFF17212B.toInt(),
        accentSoft = 0xFF28445D.toInt(),
        divider = 0xFF2D3A47.toInt(),
        danger = 0xFFE06C75.toInt(),
        positive = 0xFF63B88C.toInt()
    )

    val light = FinanceDesignColors(
        background = 0xFFF1F3F5.toInt(),
        surface = 0xFFFFFFFF.toInt(),
        raised = 0xFFE9EEF3.toInt(),
        text = 0xFF17212B.toInt(),
        secondaryText = 0xFF626F7A.toInt(),
        accent = 0xFF236DAB.toInt(),
        onAccent = 0xFFFFFFFF.toInt(),
        accentSoft = 0xFFDCEBFA.toInt(),
        divider = 0xFFE5E9ED.toInt(),
        danger = 0xFFD9535D.toInt(),
        positive = 0xFF23885C.toInt()
    )

    fun colors(isDark: Boolean) = if (isDark) dark else light

    fun dp(context: Context, value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()

    fun rounded(context: Context, color: Int, radius: Int): GradientDrawable =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(context, radius).toFloat()
        }

    fun text(
        context: Context,
        value: CharSequence,
        sizeSp: Float = 14f,
        color: Int = colors(
            (context.resources.configuration.uiMode and
                android.content.res.Configuration.UI_MODE_NIGHT_MASK) !=
                android.content.res.Configuration.UI_MODE_NIGHT_NO
        ).text,
        bold: Boolean = false
    ): TextView = TextView(context).apply {
        text = value
        textSize = sizeSp
        setTextColor(color)
        typeface = if (bold) {
            Typeface.create("sans-serif-medium", Typeface.NORMAL)
        } else {
            Typeface.create("sans-serif", Typeface.NORMAL)
        }
        gravity = Gravity.CENTER_VERTICAL
        textDirection = View.TEXT_DIRECTION_FIRST_STRONG
        includeFontPadding = true
    }

    fun surface(
        context: Context,
        isDark: Boolean,
        padding: Int = FinanceDesignTokens.CARD_PADDING,
        radius: Int = FinanceDesignTokens.CARD_RADIUS
    ): LinearLayout = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        layoutDirection = View.LAYOUT_DIRECTION_RTL
        setPadding(dp(context, padding), dp(context, padding),
            dp(context, padding), dp(context, padding))
        background = rounded(context, colors(isDark).surface, radius)
        clipToOutline = true
    }

    fun sectionTitle(context: Context, value: String, isDark: Boolean): TextView =
        text(context, value, 16f, colors(isDark).text, bold = true).apply {
            setPadding(0, dp(context, 4), 0, dp(context, 8))
            minHeight = dp(context, FinanceDesignTokens.SECTION_HEADER_HEIGHT)
        }

    fun divider(context: Context, isDark: Boolean, startInset: Int = 56): View =
        View(context).apply {
            setBackgroundColor(colors(isDark).divider)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(context, FinanceDesignTokens.DIVIDER_HEIGHT)
            ).apply {
                marginStart = dp(context, startInset)
            }
        }

    fun iconBox(
        context: Context,
        isDark: Boolean,
        iconResource: Int,
        selected: Boolean = false
    ): FrameLayout {
        val palette = colors(isDark)
        return FrameLayout(context).apply {
            background = rounded(
                context,
                if (selected) palette.accentSoft else palette.raised,
                FinanceDesignTokens.CONTROL_RADIUS
            )
            val image = ImageView(context).apply {
                setImageResource(iconResource)
                imageTintList = ColorStateList.valueOf(
                    if (selected) palette.accent else palette.secondaryText
                )
                scaleType = ImageView.ScaleType.CENTER_INSIDE
            }
            addView(image, FrameLayout.LayoutParams(
                dp(context, FinanceDesignTokens.STANDARD_ICON_SIZE),
                dp(context, FinanceDesignTokens.STANDARD_ICON_SIZE),
                Gravity.CENTER
            ))
        }
    }

    fun iconAction(
        context: Context,
        isDark: Boolean,
        iconResource: Int,
        description: String,
        onClick: () -> Unit
    ): FrameLayout = FrameLayout(context).apply {
        contentDescription = description
        isClickable = true
        isFocusable = true
        background = rounded(
            context,
            colors(isDark).background,
            FinanceDesignTokens.CONTROL_RADIUS
        )
        val image = ImageView(context).apply {
            setImageResource(iconResource)
            imageTintList = ColorStateList.valueOf(colors(isDark).text)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
        }
        addView(image, FrameLayout.LayoutParams(
            dp(context, FinanceDesignTokens.STANDARD_ICON_SIZE),
            dp(context, FinanceDesignTokens.STANDARD_ICON_SIZE),
            Gravity.CENTER
        ))
        setOnClickListener { onClick() }
    }

    fun input(
        context: Context,
        isDark: Boolean,
        hint: String,
        initialValue: String = "",
        numeric: Boolean = false,
        multiline: Boolean = false
    ): EditText = EditText(context).apply {
        this.hint = hint
        setText(initialValue)
        textSize = 15f
        setTextColor(colors(isDark).text)
        setHintTextColor(colors(isDark).secondaryText)
        background = rounded(
            context,
            colors(isDark).raised,
            FinanceDesignTokens.CONTROL_RADIUS
        )
        setPadding(
            dp(context, 14), dp(context, FinanceDesignTokens.INPUT_VERTICAL_PADDING),
            dp(context, 14), dp(context, FinanceDesignTokens.INPUT_VERTICAL_PADDING)
        )
        minHeight = dp(context, FinanceDesignTokens.BUTTON_HEIGHT)
        inputType = when {
            numeric -> android.text.InputType.TYPE_CLASS_NUMBER or
                android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL
            multiline -> android.text.InputType.TYPE_CLASS_TEXT or
                android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE or
                android.text.InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            else -> android.text.InputType.TYPE_CLASS_TEXT or
                android.text.InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
        }
        isSingleLine = !multiline
    }

    fun button(
        context: Context,
        isDark: Boolean,
        label: String,
        primary: Boolean = true,
        onClick: () -> Unit
    ): TextView {
        val palette = colors(isDark)
        return text(
            context,
            label,
            15f,
            if (primary) palette.onAccent else palette.accent,
            bold = true
        ).apply {
            gravity = Gravity.CENTER
            minHeight = dp(context, FinanceDesignTokens.BUTTON_HEIGHT)
            setPadding(dp(context, 18), 0, dp(context, 18), 0)
            background = rounded(
                context,
                if (primary) palette.accent else palette.accentSoft,
                FinanceDesignTokens.CONTROL_RADIUS
            )
            isClickable = true
            isFocusable = true
            setOnClickListener { onClick() }
        }
    }
}
