package com.example.finance_client

import com.example.finance_client.notification.channel.NotificationChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NotificationChannelHandler(this).register(flutterEngine)
    }
}
