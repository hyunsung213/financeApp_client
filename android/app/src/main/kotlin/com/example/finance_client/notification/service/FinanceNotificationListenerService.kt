package com.example.finance_client.notification.service

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.example.finance_client.notification.channel.NotificationEventBus
import com.example.finance_client.notification.config.FinancialAppAllowlist
import com.example.finance_client.notification.data.AppDatabase
import com.example.finance_client.notification.data.NotificationInbox
import com.example.finance_client.notification.utils.EventIdGenerator
import com.example.finance_client.notification.worker.NotificationSyncWorker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class FinanceNotificationListenerService : NotificationListenerService() {

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: return

        // Ignore notifications posted by our own application
        if (packageName == applicationContext.packageName) {
            return
        }

        // Filter by financial and card app allowlist
        if (!FinancialAppAllowlist.isAllowedPackage(packageName)) {
            return
        }

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        // Extract title
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""

        // Extract text (prefer EXTRA_BIG_TEXT if available, fallback to EXTRA_TEXT)
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim()
        val content = when {
            !bigText.isNullOrBlank() -> bigText
            !text.isNullOrBlank() -> text
            else -> ""
        }

        // If both title and content are blank, skip
        if (title.isBlank() && content.isBlank()) {
            return
        }

        // If from ADB shell test, map to appropriate financial package for backend allowlist
        val effectivePackageName = if (packageName == "com.android.shell") {
            when {
                title.contains("국민") || title.contains("KB") -> "com.kbcard.cxh.appcard"
                title.contains("토스") || title.contains("toss", ignoreCase = true) -> "viva.republica.toss"
                title.contains("카카오") -> "com.kakaobank.channel"
                else -> "com.shcard.smartpay"
            }
        } else {
            packageName
        }

        val timestamp = if (sbn.postTime > 0) sbn.postTime else System.currentTimeMillis()
        val eventId = EventIdGenerator.generate(effectivePackageName, timestamp, title, content)

        serviceScope.launch {
            try {
                val database = AppDatabase.getInstance(applicationContext)
                val dao = database.notificationInboxDao()

                val inboxItem = NotificationInbox(
                    eventId = eventId,
                    packageName = effectivePackageName,
                    title = title,
                    content = content,
                    timestamp = timestamp,
                    source = "ANDROID_NOTIFICATION",
                    status = NotificationInbox.STATUS_PENDING
                )

                val insertedRowId = dao.insert(inboxItem)

                // If inserted successfully (not duplicate)
                if (insertedRowId > 0) {
                    // Trigger background upload via WorkManager
                    NotificationSyncWorker.enqueue(applicationContext)

                    // Emit event to Flutter UI if app is in foreground
                    NotificationEventBus.emitEvent(
                        mapOf(
                            "eventId" to eventId,
                            "packageName" to packageName,
                            "appName" to FinancialAppAllowlist.getAppName(packageName),
                            "title" to title,
                            "content" to content,
                            "timestamp" to timestamp,
                            "source" to "ANDROID_NOTIFICATION",
                            "status" to NotificationInbox.STATUS_PENDING
                        )
                    )
                }
            } catch (e: Exception) {
                // Defensive catch to prevent service crash
            }
        }
    }
}
