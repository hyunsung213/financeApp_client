package com.example.finance_client.notification.worker

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.example.finance_client.notification.config.NotificationConfigStore
import com.example.finance_client.notification.data.AppDatabase
import com.example.finance_client.notification.data.NotificationInbox
import com.google.gson.Gson
import com.google.gson.JsonObject
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

class NotificationSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .build()

    private val gson = Gson()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    override suspend fun doWork(): Result {
        val database = AppDatabase.getInstance(applicationContext)
        val dao = database.notificationInboxDao()
        val configStore = NotificationConfigStore.getInstance(applicationContext)

        val pendingList = dao.getPendingOrFailedNotifications()
        if (pendingList.isEmpty()) {
            return Result.success()
        }

        val baseUrl = configStore.getBaseUrl().trimEnd('/')
        val url = "$baseUrl/api/notifications"
        val authToken = configStore.getAuthToken()

        var hasTransientError = false

        android.util.Log.d("NotificationSyncWorker", "Executing sync for ${pendingList.size} notifications to $url")

        for (item in pendingList) {
            // Update status to SENDING
            dao.updateStatus(
                eventId = item.eventId,
                status = NotificationInbox.STATUS_SENDING,
                retryCount = item.retryCount,
                lastError = item.lastError
            )

            val payload = JsonObject().apply {
                addProperty("eventId", item.eventId)
                addProperty("packageName", item.packageName)
                addProperty("title", item.title)
                addProperty("content", item.content)
                addProperty("timestamp", item.timestamp)
                addProperty("source", item.source)
            }

            val requestBody = gson.toJson(payload).toRequestBody(jsonMediaType)
            val requestBuilder = Request.Builder()
                .url(url)
                .post(requestBody)
                .header("Content-Type", "application/json")

            if (!authToken.isNullOrBlank()) {
                requestBuilder.header("Authorization", "Bearer $authToken")
            }

            try {
                httpClient.newCall(requestBuilder.build()).execute().use { response ->
                    val statusCode = response.code
                    val responseBody = response.body?.string() ?: ""
                    android.util.Log.d("NotificationSyncWorker", "Server response code: $statusCode, body: $responseBody")

                    when {
                        // 2xx Success or 409 Conflict (Duplicate): Mark as SENT
                        response.isSuccessful || statusCode == 409 -> {
                            dao.updateStatus(
                                eventId = item.eventId,
                                status = NotificationInbox.STATUS_SENT,
                                retryCount = item.retryCount,
                                lastError = null
                            )
                        }
                        // 408 (Timeout) or 429 (Too Many Requests): Transient, retry
                        statusCode == 408 || statusCode == 429 -> {
                            hasTransientError = true
                            dao.updateStatus(
                                eventId = item.eventId,
                                status = NotificationInbox.STATUS_PENDING,
                                retryCount = item.retryCount + 1,
                                lastError = "HTTP $statusCode (Transient)"
                            )
                        }
                        // Other 4xx client errors: Mark as FAILED, do not retry
                        statusCode in 400..499 -> {
                            dao.updateStatus(
                                eventId = item.eventId,
                                status = NotificationInbox.STATUS_FAILED,
                                retryCount = item.retryCount,
                                lastError = "HTTP $statusCode: $responseBody"
                            )
                        }
                        // 5xx server errors: Mark as PENDING, retry with backoff
                        else -> {
                            hasTransientError = true
                            dao.updateStatus(
                                eventId = item.eventId,
                                status = NotificationInbox.STATUS_PENDING,
                                retryCount = item.retryCount + 1,
                                lastError = "HTTP $statusCode: $responseBody"
                            )
                        }
                    }
                }
            } catch (e: IOException) {
                android.util.Log.e("NotificationSyncWorker", "IOException sending to $url: ${e.message}", e)
                hasTransientError = true
                dao.updateStatus(
                    eventId = item.eventId,
                    status = NotificationInbox.STATUS_PENDING,
                    retryCount = item.retryCount + 1,
                    lastError = "Network error: ${e.localizedMessage}"
                )
            } catch (e: Exception) {
                android.util.Log.e("NotificationSyncWorker", "Unexpected error sending to $url: ${e.message}", e)
                hasTransientError = true
                dao.updateStatus(
                    eventId = item.eventId,
                    status = NotificationInbox.STATUS_PENDING,
                    retryCount = item.retryCount + 1,
                    lastError = "Unexpected error: ${e.localizedMessage}"
                )
            }
        }

        return if (hasTransientError) {
            Result.retry()
        } else {
            Result.success()
        }
    }

    companion object {
        const val WORK_NAME = "finance_notification_sync_work"

        fun enqueue(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val syncRequest = OneTimeWorkRequestBuilder<NotificationSyncWorker>()
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    10,
                    TimeUnit.SECONDS
                )
                .build()

            WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
                WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                syncRequest
            )
        }
    }
}
