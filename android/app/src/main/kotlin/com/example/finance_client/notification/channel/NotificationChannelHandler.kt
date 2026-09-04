package com.example.finance_client.notification.channel

import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import com.example.finance_client.notification.config.FinancialAppAllowlist
import com.example.finance_client.notification.config.NotificationConfigStore
import com.example.finance_client.notification.data.AppDatabase
import com.example.finance_client.notification.worker.NotificationSyncWorker
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class NotificationChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    private val scope = CoroutineScope(Dispatchers.Main)

    fun register(flutterEngine: FlutterEngine) {
        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL_NAME
        )
        methodChannel.setMethodCallHandler(this)

        val eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL_NAME
        )
        eventChannel.setStreamHandler(NotificationEventBus)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isNotificationAccessGranted" -> {
                val isGranted = isAccessGranted()
                result.success(isGranted)
            }
            "openNotificationAccessSettings" -> {
                openSettings()
                result.success(true)
            }
            "updateConfig" -> {
                val baseUrl = call.argument<String>("baseUrl")
                val authToken = call.argument<String>("authToken")
                val configStore = NotificationConfigStore.getInstance(context)

                if (!baseUrl.isNullOrBlank()) {
                    configStore.setBaseUrl(baseUrl)
                }
                configStore.setAuthToken(authToken)

                // Trigger sync if there are pending notifications
                NotificationSyncWorker.enqueue(context)
                result.success(true)
            }
            "getRecentNotifications" -> {
                val limit = call.argument<Int>("limit") ?: 50
                scope.launch {
                    val notifications = withContext(Dispatchers.IO) {
                        val dao = AppDatabase.getInstance(context).notificationInboxDao()
                        dao.getRecentNotifications(limit).map { item ->
                            mapOf(
                                "localId" to item.localId,
                                "eventId" to item.eventId,
                                "packageName" to item.packageName,
                                "appName" to FinancialAppAllowlist.getAppName(item.packageName),
                                "title" to item.title,
                                "content" to item.content,
                                "timestamp" to item.timestamp,
                                "source" to item.source,
                                "status" to item.status,
                                "retryCount" to item.retryCount,
                                "lastError" to item.lastError,
                                "createdAt" to item.createdAt,
                                "updatedAt" to item.updatedAt
                            )
                        }
                    }
                    result.success(notifications)
                }
            }
            "triggerManualSync" -> {
                NotificationSyncWorker.enqueue(context)
                result.success(true)
            }
            "getAllowedPackages" -> {
                result.success(FinancialAppAllowlist.getAllowedPackages().toList())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun isAccessGranted(): Boolean {
        val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(context)
        return enabledPackages.contains(context.packageName)
    }

    private fun openSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    companion object {
        const val METHOD_CHANNEL_NAME = "finance_app/notification_access"
        const val EVENT_CHANNEL_NAME = "finance_app/notification_events"
    }
}
