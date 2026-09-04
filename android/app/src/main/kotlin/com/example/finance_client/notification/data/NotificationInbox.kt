package com.example.finance_client.notification.data

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "notification_inbox",
    indices = [Index(value = ["eventId"], unique = true)]
)
data class NotificationInbox(
    @PrimaryKey(autoGenerate = true)
    val localId: Long = 0,
    val eventId: String,
    val packageName: String,
    val title: String,
    val content: String,
    val timestamp: Long,
    val source: String = "ANDROID_NOTIFICATION",
    val status: String = STATUS_PENDING,
    val retryCount: Int = 0,
    val lastError: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
) {
    companion object {
        const val STATUS_PENDING = "PENDING"
        const val STATUS_SENDING = "SENDING"
        const val STATUS_SENT = "SENT"
        const val STATUS_FAILED = "FAILED"
    }
}
