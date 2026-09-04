package com.example.finance_client.notification.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface NotificationInboxDao {
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insert(notification: NotificationInbox): Long

    @Query("SELECT * FROM notification_inbox WHERE status IN ('PENDING', 'FAILED') ORDER BY createdAt ASC")
    suspend fun getPendingOrFailedNotifications(): List<NotificationInbox>

    @Query("SELECT * FROM notification_inbox WHERE status = 'PENDING' ORDER BY createdAt ASC")
    suspend fun getPendingNotifications(): List<NotificationInbox>

    @Query("UPDATE notification_inbox SET status = :status, retryCount = :retryCount, lastError = :lastError, updatedAt = :updatedAt WHERE eventId = :eventId")
    suspend fun updateStatus(
        eventId: String,
        status: String,
        retryCount: Int,
        lastError: String?,
        updatedAt: Long = System.currentTimeMillis()
    )

    @Query("SELECT * FROM notification_inbox ORDER BY timestamp DESC LIMIT :limit")
    suspend fun getRecentNotifications(limit: Int = 50): List<NotificationInbox>

    @Query("SELECT COUNT(*) FROM notification_inbox WHERE eventId = :eventId")
    suspend fun countByEventId(eventId: String): Int
}
