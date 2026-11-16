package com.byepro.bye_pro_finance.ui

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.View

object FinancePalette {
    const val DARK_BACKGROUND = 0xFF21242B.toInt()
    const val DARK_SURFACE = 0xFF292D36.toInt()
    const val DARK_RAISED = 0xFF343A45.toInt()
    const val DARK_TEXT = 0xFFF2F3F5.toInt()
    const val DARK_MUTED = 0xFFADB4C0.toInt()
    const val DARK_ACCENT = 0xFF6AB2F2.toInt()
    const val DARK_DIVIDER = 0xFF3B424D.toInt()

    const val LIGHT_BACKGROUND = 0xFFF4F5F7.toInt()
    const val LIGHT_SURFACE = 0xFFFFFFFF.toInt()
    const val LIGHT_RAISED = 0xFFE8EBF0.toInt()
    const val LIGHT_TEXT = 0xFF20242B.toInt()
    const val LIGHT_MUTED = 0xFF69717D.toInt()
    const val LIGHT_ACCENT = 0xFF367FC0.toInt()
    const val LIGHT_DIVIDER = 0xFFE1E4E9.toInt()

    fun background(dark: Boolean) = if (dark) DARK_BACKGROUND else LIGHT_BACKGROUND
    fun surface(dark: Boolean) = if (dark) DARK_SURFACE else LIGHT_SURFACE
    fun raised(dark: Boolean) = if (dark) DARK_RAISED else LIGHT_RAISED
    fun text(dark: Boolean) = if (dark) DARK_TEXT else LIGHT_TEXT
    fun muted(dark: Boolean) = if (dark) DARK_MUTED else LIGHT_MUTED
    fun accent(dark: Boolean) = if (dark) DARK_ACCENT else LIGHT_ACCENT
    fun divider(dark: Boolean) = if (dark) DARK_DIVIDER else LIGHT_DIVIDER

    fun rounded(color: Int, radiusDp: Float, context: Context): GradientDrawable =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = radiusDp * context.resources.displayMetrics.density
        }

    fun circle(color: Int): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(color)
        }

    fun View.setRoundedBackground(color: Int, radiusDp: Float) {
        background = rounded(color, radiusDp, context)
    }

    fun parseColor(hex: String): Int =
        try { Color.parseColor(hex) } catch (_: IllegalArgumentException) { DARK_ACCENT }
}
