package com.byepro.bye_pro_finance.ui

/** The replacement appearance model. It contains no palette/theme catalogue. */
enum class FinanceAppearanceMode(val storageValue: String) {
    SYSTEM("system"),
    LIGHT("light"),
    DARK("dark");

    companion object {
        fun fromStorage(value: String?): FinanceAppearanceMode =
            entries.firstOrNull { it.storageValue == value } ?: SYSTEM
    }
}

object FinanceAppearance {
    const val SETTINGS_KEY = "theme_mode"

    /** Legacy palette/background keys are obsolete in the new design system. */
    // These are the only obsolete appearance keys confirmed in the
    // Flutter AppSettingsController. Do not delete unknown app preferences.
    val LEGACY_SETTING_KEYS = listOf(
        "theme_id",
        "custom_themes",
        "appearance_preset"
    )

    fun isDark(mode: FinanceAppearanceMode, systemIsDark: Boolean): Boolean =
        when (mode) {
            FinanceAppearanceMode.SYSTEM -> systemIsDark
            FinanceAppearanceMode.LIGHT -> false
            FinanceAppearanceMode.DARK -> true
        }
}
