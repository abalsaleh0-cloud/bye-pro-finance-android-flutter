# Bye Pro Finance — Native Android migration

This directory is the independent Android-native application track. It is kept separate from the Flutter reference app until native feature parity is verified.

## Native stack
- Kotlin and Android framework Views (Activity, LinearLayout, ScrollView, PopupMenu, AlertDialog).
- SQLiteOpenHelper opening the existing Drift SQLite file.
- No Compose, WebView, paid SDK, or extra runtime UI package in this first migration stage.

## Existing data compatibility
- Release application ID: `com.byepro.bye_pro_finance` (kept identical to the Flutter app).
- Existing database: `files/app_flutter/bye_pro_finance.sqlite`.
- Existing SQLite user_version: `2`.
- The native helper opens the same file and uses the existing table/column names. It does not create a second database when the expected file is present.
- Debug builds use the separate package suffix `.nativepreview`, so they cannot overwrite the installed Flutter app while development is in progress. Debug previews use their own sandbox and therefore do not read production records.
- Release builds must be signed with the same production key as the installed app before they can update it in place.

## Build
From the repository root, with JDK 17, Android SDK 36, and Gradle 9.5:

```bash
gradle -p native-android :app:assembleDebug --no-daemon
```

## Migration status
The first native slice includes the five-section shell, dashboard read model, and read-only Work/Home/Debts lists. Native data-entry workflows, payment history actions, backup/restore, settings/theme parity, and the local Gemma assistant must pass their own tests before this APK can replace the Flutter installation.
