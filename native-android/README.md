# Bye Pro Finance — Native Android application

This is the new Android-native implementation. The active native UI uses one centralized design system inspired by Telegram's clean Android presentation. It does not use the old 77-theme catalogue, custom palettes, animated backgrounds, cinematic effects, or theme-specific layouts.

## New appearance system
- Exactly three appearance modes: **System**, **Light**, and **Dark**.
- One shared light palette and one shared dark palette.
- Switching modes changes colors only. Component sizes, page structure, spacing, icons, typography, and RTL layout stay the same.
- Appearance and language are separate settings.
- Old appearance keys (`theme_id`, `custom_themes`, and `appearance_preset`) are removed from `app_settings` on native app startup. The new `theme_mode`, language preference, and AI engine preference are retained.
- No financial tables or transaction records are touched by this cleanup.

## Design system
The native design system is centralized in `FinanceDesignSystem.kt`, `FinanceAppearance.kt`, and `FinanceComponents.kt`.
- Page padding: 16 horizontal / 12 vertical.
- Card radius: 16; control radius: 12; dialog radius: 20.
- Button and standard input height: 48; touch target: 44.
- App bar: 56; bottom navigation: 68; five separate destinations.
- Record and metric rows: 64; record icon box: 40; standard icon: 20.
- Dividers: 1; section spacing: 12; motion: 160 ms.
- Common components define app bars, section headers, grouped lists, record rows, metric rows, fields, buttons, dialogs and popups.

## Native stack
- Kotlin and Android framework Views.
- SQLiteOpenHelper opening the existing Drift SQLite file.
- No Compose, WebView, paid SDK, or extra runtime UI package in this migration stage.

## Existing data compatibility
- Release application ID: `com.byepro.bye_pro_finance`.
- Existing database: `context.getDir("flutter", MODE_PRIVATE)/bye_pro_finance.sqlite`.
- Existing SQLite user_version: `2`.
- Debug builds use the separate package suffix `.nativepreview` and therefore do not overwrite the installed Flutter app. The preview build has its own app sandbox and cannot display production records.
- Release builds must use the same production signing key as the installed application before an in-place upgrade can be performed.

## Build and validation
From the repository root, with JDK 17, Android SDK 36, and Gradle 9.5:

```bash
gradle -p native-android :app:testDebugUnitTest --no-daemon
gradle -p native-android :app:assembleDebug --no-daemon
```

GitHub Actions runs both the design/appearance unit tests and native debug APK assembly. A successful preview build does not mean that the production signing or migration is complete.

## Migration boundary
The native implementation is being brought to feature parity in stages. Do not replace the installed production APK until data continuity, sign-in behaviour, all financial workflows, backup/restore, AI assistant integration, and device-level UI checks are complete.
