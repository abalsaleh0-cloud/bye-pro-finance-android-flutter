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
    val LEGACY_SETTING_KEYS = listOf(
        "theme_id",
        "custom_themes",
        "appearance_preset",
        "theme_background",
        "theme_background_image",
        "background_mode",
        "background_style",
        "background_effects",
        "background_animation",
        "animated_background",
        "cinematic_effects",
        "theme_effects",
        "theme_fx",
        "custom_theme"
    )

    fun isDark(mode: FinanceAppearanceMode, systemIsDark: Boolean): Boolean =
        when (mode) {
            FinanceAppearanceMode.SYSTEM -> systemIsDark
            FinanceAppearanceMode.LIGHT -> false
            FinanceAppearanceMode.DARK -> true
        }
}
