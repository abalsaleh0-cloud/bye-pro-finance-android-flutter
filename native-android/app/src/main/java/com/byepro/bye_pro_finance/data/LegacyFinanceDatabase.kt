package com.byepro.bye_pro_finance.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.io.File

/**
 * Opens the exact SQLite file used by the existing Flutter/Drift app.
 *
 * drift_flutter stores "bye_pro_finance.sqlite" in the app documents folder,
 * which path_provider_android exposes as files/app_flutter on Android.
 * This project deliberately keeps the same applicationId in release builds
 * so Android keeps the same private app directory during an in-place upgrade.
 */
class LegacyFinanceDatabase private constructor(
    context: Context,
    private val databaseFile: File
) : SQLiteOpenHelper(context, databaseFile.absolutePath, null, DATABASE_VERSION) {

    constructor(context: Context) : this(
        context.applicationContext,
        resolveDatabaseFile(context.applicationContext)
    )

    val legacyDatabaseFoundBeforeOpen: Boolean = databaseFile.isFile

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.setForeignKeyConstraintsEnabled(true)
    }

    override fun onCreate(db: SQLiteDatabase) {
        createCoreTables(db)
        createExtendedTables(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS debt_payments (
                    id TEXT NOT NULL PRIMARY KEY,
                    debt_id TEXT NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
                    amount_minor_units INTEGER NOT NULL,
                    paid_at_epoch_millis INTEGER NOT NULL,
                    note TEXT
                )
                """.trimIndent()
            )
        }
    }

    override fun onOpen(db: SQLiteDatabase) {
        super.onOpen(db)
        // These tables are created by Drift's beforeOpen hook rather than by
        // its generated table list. Keep the same behaviour on native Android.
        createExtendedTables(db)
    }

    fun readSetting(key: String): String? {
        readableDatabase.rawQuery(
            "SELECT setting_value FROM app_settings WHERE setting_key = ?",
            arrayOf(key)
        ).use { cursor ->
            return if (cursor.moveToFirst()) cursor.getString(0) else null
        }
    }

    fun writeSetting(key: String, value: String) {
        val values = ContentValues().apply {
            put("setting_key", key)
            put("setting_value", value)
        }
        writableDatabase.insertWithOnConflict(
            "app_settings",
            null,
            values,
            SQLiteDatabase.CONFLICT_REPLACE
        )
    }

    /** Remove obsolete appearance preferences without touching finance records. */
    fun deleteSettings(keys: Collection<String>) {
        if (keys.isEmpty()) return
        val placeholders = keys.joinToString(",") { "?" }
        writableDatabase.delete(
            "app_settings",
            "setting_key IN ($placeholders)",
            keys.toTypedArray()
        )
    }

    fun databaseLocation(): String = databaseFile.absolutePath

    private fun createCoreTables(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS home_expenses (
                id TEXT NOT NULL PRIMARY KEY,
                amount_minor_units INTEGER NOT NULL,
                category_id TEXT NOT NULL,
                expense_date_epoch_millis INTEGER NOT NULL,
                due_year INTEGER NOT NULL,
                due_month INTEGER NOT NULL,
                note TEXT
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS work_entries (
                id TEXT NOT NULL PRIMARY KEY,
                kind TEXT NOT NULL,
                amount_minor_units INTEGER NOT NULL,
                due_year INTEGER NOT NULL,
                due_month INTEGER NOT NULL,
                recorded_at_epoch_millis INTEGER NOT NULL,
                note TEXT
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS work_home_transfers (
                id TEXT NOT NULL PRIMARY KEY,
                amount_minor_units INTEGER NOT NULL,
                transferred_at_epoch_millis INTEGER NOT NULL,
                note TEXT
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS debts (
                id TEXT NOT NULL PRIMARY KEY,
                direction TEXT NOT NULL,
                original_amount_minor_units INTEGER NOT NULL,
                outstanding_amount_minor_units INTEGER NOT NULL,
                due_year INTEGER NOT NULL,
                due_month INTEGER NOT NULL,
                created_at_epoch_millis INTEGER NOT NULL,
                counterparty TEXT NOT NULL,
                note TEXT
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS debt_payments (
                id TEXT NOT NULL PRIMARY KEY,
                debt_id TEXT NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
                amount_minor_units INTEGER NOT NULL,
                paid_at_epoch_millis INTEGER NOT NULL,
                note TEXT
            )
            """.trimIndent()
        )
    }

    private fun createExtendedTables(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS home_bills (
                id TEXT PRIMARY KEY NOT NULL,
                title TEXT NOT NULL,
                kind TEXT NOT NULL CHECK (kind IN ('monthly', 'rent')),
                amount_minor_units INTEGER NOT NULL CHECK (amount_minor_units > 0),
                due_year INTEGER NOT NULL,
                due_month INTEGER NOT NULL CHECK (due_month BETWEEN 1 AND 12),
                note TEXT
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS home_bill_payments (
                id TEXT PRIMARY KEY NOT NULL,
                bill_id TEXT NOT NULL REFERENCES home_bills(id) ON DELETE CASCADE,
                amount_minor_units INTEGER NOT NULL CHECK (amount_minor_units > 0),
                paid_at_epoch_millis INTEGER NOT NULL,
                note TEXT
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS app_settings (
                setting_key TEXT PRIMARY KEY NOT NULL,
                setting_value TEXT NOT NULL
            )
            """.trimIndent()
        )
    }

    companion object {
        private const val DATABASE_VERSION = 2

        private fun resolveDatabaseFile(context: Context): File {
            // PathUtils.getDataDirectory(context) in the Flutter Android engine
            // is implemented as context.getDir("flutter", MODE_PRIVATE).
            // path_provider_android delegates getApplicationDocumentsDirectory()
            // to that exact directory, so Drift's database is stored here.
            val documentsDirectory = context.getDir("flutter", Context.MODE_PRIVATE)
            documentsDirectory.mkdirs()
            return File(documentsDirectory, "bye_pro_finance.sqlite")
        }
    }
}
