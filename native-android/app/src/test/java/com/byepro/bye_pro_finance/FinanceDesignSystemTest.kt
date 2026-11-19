package com.byepro.bye_pro_finance

import com.byepro.bye_pro_finance.ui.FinanceDesignSystem
import com.byepro.bye_pro_finance.ui.FinanceDesignTokens
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FinanceDesignSystemTest {

    @Test
    fun approvedGeometryRemainsCentralized() {
        assertEquals(16, FinanceDesignTokens.PAGE_HORIZONTAL_PADDING)
        assertEquals(12, FinanceDesignTokens.PAGE_VERTICAL_PADDING)
        assertEquals(12, FinanceDesignTokens.SECTION_SPACING)
        assertEquals(16, FinanceDesignTokens.CARD_PADDING)
        assertEquals(12, FinanceDesignTokens.INPUT_VERTICAL_PADDING)

        assertEquals(16, FinanceDesignTokens.CARD_RADIUS)
        assertEquals(12, FinanceDesignTokens.CONTROL_RADIUS)
        assertEquals(20, FinanceDesignTokens.DIALOG_RADIUS)

        assertEquals(56, FinanceDesignTokens.APP_BAR_HEIGHT)
        assertEquals(48, FinanceDesignTokens.BUTTON_HEIGHT)
        assertEquals(44, FinanceDesignTokens.TOUCH_TARGET_SIZE)
        assertEquals(68, FinanceDesignTokens.NAVIGATION_BAR_HEIGHT)
        assertEquals(48, FinanceDesignTokens.SECTION_TAB_HEIGHT)
        assertEquals(36, FinanceDesignTokens.SECTION_HEADER_HEIGHT)

        assertEquals(64, FinanceDesignTokens.METRIC_TILE_MIN_HEIGHT)
        assertEquals(64, FinanceDesignTokens.RECORD_ROW_HEIGHT)
        assertEquals(40, FinanceDesignTokens.RECORD_ICON_BOX_SIZE)
        assertEquals(20, FinanceDesignTokens.STANDARD_ICON_SIZE)
        assertEquals(1, FinanceDesignTokens.DIVIDER_HEIGHT)
        assertEquals(160L, FinanceDesignTokens.MOTION_DURATION_MS)
    }

    @Test
    fun lightAndDarkPalettesUseSeparateSurfaces() {
        assertNotEquals(
            FinanceDesignSystem.dark.background,
            FinanceDesignSystem.light.background
        )
        assertNotEquals(
            FinanceDesignSystem.dark.surface,
            FinanceDesignSystem.light.surface
        )
        assertNotEquals(
            FinanceDesignSystem.dark.text,
            FinanceDesignSystem.light.text
        )
        assertNotEquals(
            FinanceDesignSystem.dark.accent,
            FinanceDesignSystem.light.accent
        )
    }

    @Test
    fun importantTextColorsMeetReadableContrastInBothModes() {
        assertTrue(contrast(FinanceDesignSystem.light.text, FinanceDesignSystem.light.surface) >= 4.5)
        assertTrue(contrast(FinanceDesignSystem.light.secondaryText, FinanceDesignSystem.light.surface) >= 4.5)
        assertTrue(contrast(FinanceDesignSystem.light.accent, FinanceDesignSystem.light.surface) >= 4.5)
        assertTrue(contrast(FinanceDesignSystem.light.onAccent, FinanceDesignSystem.light.accent) >= 4.5)

        assertTrue(contrast(FinanceDesignSystem.dark.text, FinanceDesignSystem.dark.surface) >= 4.5)
        assertTrue(contrast(FinanceDesignSystem.dark.secondaryText, FinanceDesignSystem.dark.surface) >= 4.5)
        assertTrue(contrast(FinanceDesignSystem.dark.accent, FinanceDesignSystem.dark.surface) >= 4.5)
        assertTrue(contrast(FinanceDesignSystem.dark.onAccent, FinanceDesignSystem.dark.accent) >= 4.5)
    }

    private fun contrast(foreground: Int, background: Int): Double {
        fun channel(value: Int): Double {
            val sRgb = value / 255.0
            return if (sRgb <= 0.04045) sRgb / 12.92
            else Math.pow((sRgb + 0.055) / 1.055, 2.4)
        }

        fun component(color: Int, shift: Int): Double =
            channel((color ushr shift) and 0xFF)

        fun luminance(color: Int): Double =
            0.2126 * component(color, 16) +
                0.7152 * component(color, 8) +
                0.0722 * component(color, 0)

        val a = luminance(foreground)
        val b = luminance(background)
        val lighter = maxOf(a, b)
        val darker = minOf(a, b)
        return (lighter + 0.05) / (darker + 0.05)
    }

}
