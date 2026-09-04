import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum NotificationAccessStatus {
  granted,
  denied,
  unsupported,
}

class NotificationService {
  static const MethodChannel _methodChannel =
      MethodChannel('finance_app/notification_access');
  static const EventChannel _eventChannel =
      EventChannel('finance_app/notification_events');

  static Stream<Map<String, dynamic>>? _eventStream;

  /// Check if the notification listener access permission is granted
  static Future<NotificationAccessStatus> isNotificationAccessGranted() async {
    if (kIsWeb || !Platform.isAndroid) {
      return NotificationAccessStatus.unsupported;
    }

    try {
      final granted = await _methodChannel.invokeMethod<bool>(
            'isNotificationAccessGranted',
          ) ??
          false;
      return granted
          ? NotificationAccessStatus.granted
          : NotificationAccessStatus.denied;
    } catch (e) {
      debugPrint('Error checking notification access: $e');
      return NotificationAccessStatus.denied;
    }
  }

  /// Open Android Notification Listener Settings screen
  static Future<bool> openNotificationAccessSettings() async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _methodChannel.invokeMethod<bool>(
            'openNotificationAccessSettings',
          ) ??
          false;
      return result;
    } catch (e) {
      debugPrint('Error opening notification settings: $e');
      return false;
    }
  }

  /// Sync backend base URL and Supabase/JWT auth token to native storage
  static Future<bool> updateConfig({
    required String baseUrl,
    String? authToken,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _methodChannel.invokeMethod<bool>(
            'updateConfig',
            {
              'baseUrl': baseUrl,
              'authToken': authToken,
            },
          ) ??
          false;
      return result;
    } catch (e) {
      debugPrint('Error updating notification config: $e');
      return false;
    }
  }

  /// Get recent notifications collected in Room local database
  static Future<List<Map<String, dynamic>>> getRecentNotifications({
    int limit = 50,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return [];
    }

    try {
      final result = await _methodChannel.invokeListMethod<dynamic>(
        'getRecentNotifications',
        {'limit': limit},
      );
      if (result == null) return [];
      return result.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (e) {
      debugPrint('Error getting recent notifications: $e');
      return [];
    }
  }

  /// Trigger manual sync of pending notifications via WorkManager
  static Future<bool> triggerManualSync() async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _methodChannel.invokeMethod<bool>(
            'triggerManualSync',
          ) ??
          false;
      return result;
    } catch (e) {
      debugPrint('Error triggering manual sync: $e');
      return false;
    }
  }

  /// Stream of real-time notification events when app is in foreground
  static Stream<Map<String, dynamic>> get notificationEvents {
    if (kIsWeb || !Platform.isAndroid) {
      return const Stream.empty();
    }

    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _eventStream!;
  }
}
