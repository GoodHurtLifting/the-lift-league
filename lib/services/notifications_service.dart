import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Make sure ic_stat_liftleague.png is in res/drawable/
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('ic_stat_liftleague'); // 👈 use custom icon!
    const DarwinInitializationSettings iOSInit = DarwinInitializationSettings();

    await _localNotifications.initialize(
      InitializationSettings(android: androidInit, iOS: iOSInit),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print("Notification tapped: ${response.payload}");
        // TODO: handle navigation if needed
      },
    );
  }

  void showNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'high_importance_channel', 'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_stat_liftleague',
      ticker: 'ticker',
    );

    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformDetails,
      payload: message.data['payload'] ?? '',
    );
  }

  void showTestNotification() async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_stat_liftleague', // <-- your icon file
      ticker: 'ticker',
    );

    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // unique ID
      'Test Notification',
      'This is a test of your notification icon.',
      platformDetails,
      payload: 'test_payload',
    );
  }

}
