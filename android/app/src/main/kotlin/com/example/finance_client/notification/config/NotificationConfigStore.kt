package com.example.finance_client.notification.config

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class NotificationConfigStore(context: Context) {
    private val prefs: SharedPreferences = try {
        val masterKey = MasterKey.Builder(context.applicationContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        EncryptedSharedPreferences.create(
            context.applicationContext,
            "finance_secure_notification_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    } catch (e: Exception) {
        // Fallback for environments with KeyStore issues
        context.applicationContext.getSharedPreferences(
            "finance_fallback_notification_prefs",
            Context.MODE_PRIVATE
        )
    }

    fun getBaseUrl(): String {
        return prefs.getString(KEY_BASE_URL, DEFAULT_BASE_URL) ?: DEFAULT_BASE_URL
    }

    fun setBaseUrl(url: String) {
        prefs.edit().putString(KEY_BASE_URL, url).apply()
    }

    fun getAuthToken(): String? {
        return prefs.getString(KEY_AUTH_TOKEN, null)
    }

    fun setAuthToken(token: String?) {
        if (token.isNullOrBlank()) {
            prefs.edit().remove(KEY_AUTH_TOKEN).apply()
        } else {
            prefs.edit().putString(KEY_AUTH_TOKEN, token).apply()
        }
    }

    fun isDebugMode(): Boolean {
        return prefs.getBoolean(KEY_DEBUG_MODE, false)
    }

    fun setDebugMode(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_DEBUG_MODE, enabled).apply()
    }

    companion object {
        private const val KEY_BASE_URL = "notification_base_url"
        private const val KEY_AUTH_TOKEN = "notification_auth_token"
        private const val KEY_DEBUG_MODE = "notification_debug_mode"
        private const val DEFAULT_BASE_URL = "http://10.0.2.2:4000"

        @Volatile
        private var INSTANCE: NotificationConfigStore? = null

        fun getInstance(context: Context): NotificationConfigStore {
            return INSTANCE ?: synchronized(this) {
                val instance = NotificationConfigStore(context)
                INSTANCE = instance
                instance
            }
        }
    }
}
