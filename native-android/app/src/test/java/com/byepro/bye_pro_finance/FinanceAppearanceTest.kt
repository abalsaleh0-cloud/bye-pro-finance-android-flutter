package com.byepro.bye_pro_finance

import com.byepro.bye_pro_finance.ui.FinanceAppearance
import com.byepro.bye_pro_finance.ui.FinanceAppearanceMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FinanceAppearanceTest {

    @Test
    fun replacementAppearanceHasOnlyThreeModes() {
        assertEquals(
            listOf("system", "light", "dark"),
            FinanceAppearanceMode.entries.map { it.storageValue }
        )
    }

    @Test
    fun systemModeFollowsTheDeviceAppearance() {
        assertTrue(FinanceAppearance.isDark(FinanceAppearanceMode.SYSTEM, true))
        assertFalse(FinanceAppearance.isDark(FinanceAppearanceMode.SYSTEM, false))
    }

    @Test
    fun lightAndDarkModesOverrideTheDeviceAppearance() {
        assertFalse(FinanceAppearance.isDark(FinanceAppearanceMode.LIGHT, true))
        assertFalse(FinanceAppearance.isDark(FinanceAppearanceMode.LIGHT, false))
        assertTrue(FinanceAppearance.isDark(FinanceAppearanceMode.DARK, true))
        assertTrue(FinanceAppearance.isDark(FinanceAppearanceMode.DARK, false))
    }

    @Test
    fun unknownStoredValuesFallBackToSystem() {
        assertEquals(
            FinanceAppearanceMode.SYSTEM,
            FinanceAppearanceMode.fromStorage("unknown-theme")
        )
        assertEquals(
            FinanceAppearanceMode.SYSTEM,
            FinanceAppearanceMode.fromStorage(null)
        )
    }

    @Test
    fun legacyThemeCleanupDoesNotDeleteTheNewPreferences() {
        assertTrue(FinanceAppearance.LEGACY_SETTING_KEYS.contains("theme_id"))
        assertTrue(FinanceAppearance.LEGACY_SETTING_KEYS.contains("custom_themes"))
        assertTrue(FinanceAppearance.LEGACY_SETTING_KEYS.contains("appearance_preset"))
        assertFalse(FinanceAppearance.LEGACY_SETTING_KEYS.contains("theme_mode"))
        assertFalse(FinanceAppearance.LEGACY_SETTING_KEYS.contains("locale"))
        assertFalse(FinanceAppearance.LEGACY_SETTING_KEYS.contains("ai_engine"))
    }
}
