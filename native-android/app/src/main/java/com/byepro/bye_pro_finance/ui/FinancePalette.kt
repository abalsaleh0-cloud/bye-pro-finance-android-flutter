package com.byepro.bye_pro_finance.ui

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.View

/**
 * Compatibility facade for screens still being moved onto FinanceComponents.
 * All colors and shape values come from FinanceDesignSystem.
 */
object FinancePalette {
    val DARK_BACKGROUND: Int get() = FinanceDesignSystem.dark.background
    val DARK_SURFACE: Int get() = FinanceDesignSystem.dark.surface
    val DARK_RAISED: Int get() = FinanceDesignSystem.dark.raised
    val DARK_TEXT: Int get() = FinanceDesignSystem.dark.text
    val DARK_MUTED: Int get() = FinanceDesignSystem.dark.secondaryText
    val DARK_ACCENT: Int get() = FinanceDesignSystem.dark.accent
    val DARK_DIVIDER: Int get() = FinanceDesignSystem.dark.divider

    val LIGHT_BACKGROUND: Int get() = FinanceDesignSystem.light.background
    val LIGHT_SURFACE: Int get() = FinanceDesignSystem.light.surface
    val LIGHT_RAISED: Int get() = FinanceDesignSystem.light.raised
    val LIGHT_TEXT: Int get() = FinanceDesignSystem.light.text
    val LIGHT_MUTED: Int get() = FinanceDesignSystem.light.secondaryText
    val LIGHT_ACCENT: Int get() = FinanceDesignSystem.light.accent
    val LIGHT_DIVIDER: Int get() = FinanceDesignSystem.light.divider

    fun background(dark: Boolean) = FinanceDesignSystem.colors(dark).background
    fun surface(dark: Boolean) = FinanceDesignSystem.colors(dark).surface
    fun raised(dark: Boolean) = FinanceDesignSystem.colors(dark).raised
    fun text(dark: Boolean) = FinanceDesignSystem.colors(dark).text
    fun muted(dark: Boolean) = FinanceDesignSystem.colors(dark).secondaryText
    fun accent(dark: Boolean) = FinanceDesignSystem.colors(dark).accent
    fun divider(dark: Boolean) = FinanceDesignSystem.colors(dark).divider

    fun rounded(color: Int, radiusDp: Float, context: Context): GradientDrawable =
        FinanceDesignSystem.rounded(
            context,
            color,
            radiusDp.toInt().coerceAtLeast(0)
        )

    fun circle(color: Int): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(color)
        }

    fun View.setRoundedBackground(color: Int, radiusDp: Float) {
        background = rounded(color, radiusDp, context)
    }

    fun parseColor(hex: String): Int =
        try { Color.parseColor(hex) } catch (_: IllegalArgumentException) {
            FinanceDesignSystem.dark.accent
        }
}
