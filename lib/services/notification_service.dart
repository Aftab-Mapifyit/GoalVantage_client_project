import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String newOddsTopic = 'new_odds';
const String oddsChannelId = 'new_odds_alerts';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Received background odds notification: ${message.messageId}');
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize({bool subscribeToOdds = true}) async {
    if (kIsWeb) return;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      const channel = AndroidNotificationChannel(
        oddsChannelId,
        'New odds alerts',
        description: 'Notifications when GoalVantage publishes new odds.',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await setNewOddsEnabled(subscribeToOdds);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleNotificationOpen(initialMessage);
  }

  Future<void> setNewOddsEnabled(bool enabled) async {
    if (kIsWeb) return;
    if (enabled) {
      await _messaging.subscribeToTopic(newOddsTopic);
    } else {
      await _messaging.unsubscribeFromTopic(newOddsTopic);
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    // iOS foreground presentation is handled by Firebase Messaging above.
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'New GoalVantage odds',
      body: notification.body ?? 'New football odds are now available.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          oddsChannelId,
          'New odds alerts',
          channelDescription: 'Notifications when GoalVantage publishes new odds.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: message.data['predictionId'],
    );
  }

  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('Opened odds notification for ${message.data['predictionId']}');
  }
}
