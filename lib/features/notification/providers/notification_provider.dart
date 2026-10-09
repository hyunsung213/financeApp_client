import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';

class NotificationAccessNotifier extends AsyncNotifier<NotificationAccessStatus> {
  @override
  Future<NotificationAccessStatus> build() async {
    return await NotificationService.isNotificationAccessGranted();
  }

  Future<void> checkStatus() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => NotificationService.isNotificationAccessGranted());
  }

  Future<bool> openSettings() async {
    final opened = await NotificationService.openNotificationAccessSettings();
    return opened;
  }
}

final notificationAccessProvider =
    AsyncNotifierProvider<NotificationAccessNotifier, NotificationAccessStatus>(
  () {
    return NotificationAccessNotifier();
  },
  // A failed platform check will not fix itself in seconds; show the error
  // at once instead of a spinner through the default retry backoff.
  retry: (_, _) => null,
);

final recentNotificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return await NotificationService.getRecentNotifications(limit: 50);
});

final liveNotificationEventsProvider =
    StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  return NotificationService.notificationEvents;
});
