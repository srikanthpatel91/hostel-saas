import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'hostel_service.dart';

// Top-level handler required by firebase_messaging for background isolates.
// FCM shows the notification automatically from the `notification` payload
// on Android; this entry point just satisfies the plugin registration.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

// Handles FCM token registration and foreground notification display.
// Server-side push (rent due, complaints) will trigger via Cloud Functions
// using the fcmToken saved in Firestore — no backend code needed here.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  static const _channelId = 'hostel_saas_main';
  static const _channelName = 'Hostel SaaS';

  Future<void> initialize(String uid) async {
    // Request permission (Android 13+, iOS)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Save token so Cloud Functions can target this device
    final token = await _fcm.getToken();
    if (token != null) {
      await HostelService().saveFcmToken(uid: uid, token: token);
    }
    _fcm.onTokenRefresh.listen((t) {
      HostelService().saveFcmToken(uid: uid, token: t);
    });

    // Init local notifications (used to display FCM messages in foreground)
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Show local notification when app is in foreground and FCM arrives
    FirebaseMessaging.onMessage.listen(_showFromRemote);
  }

  Future<void> _showFromRemote(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await show(title: n.title ?? '', body: n.body ?? '');
  }

  // Show a local OS notification immediately (useful for in-app events
  // like a new notice posted, before Cloud Functions are wired up).
  Future<void> show({required String title, required String body}) async {
    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
