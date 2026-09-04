package com.example.finance_client.notification.channel

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object NotificationEventBus : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun emitEvent(notificationMap: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(notificationMap)
        }
    }
}
