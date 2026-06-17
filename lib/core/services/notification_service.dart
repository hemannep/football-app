import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationPermissionStatus {
  const NotificationPermissionStatus({
    required this.authorizationStatus,
    required this.localNotificationsAllowed,
  });

  final AuthorizationStatus authorizationStatus;
  final bool localNotificationsAllowed;

  bool get isAllowed =>
      authorizationStatus == AuthorizationStatus.authorized ||
      authorizationStatus == AuthorizationStatus.provisional ||
      localNotificationsAllowed;
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const AndroidNotificationChannel _matchAlertsChannel =
      AndroidNotificationChannel(
    'match_alerts',
    'Match alerts',
    description: 'Live match updates, football news, and app alerts.',
    importance: Importance.high,
    playSound: true,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
      ),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification tapped: ${response.payload ?? ''}');
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_matchAlertsChannel);

    _initialized = true;
  }

  Future<NotificationPermissionStatus> requestPermissions() async {
    await initialize();

    final messagingSettings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    var localAllowed = false;

    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      localAllowed = await android.requestNotificationsPermission() ?? false;
    }

    final ios = _localNotifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      localAllowed = await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return NotificationPermissionStatus(
      authorizationStatus: messagingSettings.authorizationStatus,
      localNotificationsAllowed: localAllowed,
    );
  }

  Future<void> configureForegroundPresentation() {
    return FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> showRemoteMessage(RemoteMessage message) async {
    if (kIsWeb) return;

    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    await show(
      title: title ?? 'Football Fan Hub 2026',
      body: body ?? '',
      payload:
          message.data.isEmpty ? message.messageId : message.data.toString(),
      id: _notificationIdFor(message),
    );
  }

  Future<void> show({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    await initialize();

    await _localNotifications.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'match_alerts',
          'Match alerts',
          channelDescription:
              'Live match updates, football news, and app alerts.',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      ),
      payload: payload,
    );
  }

  int _notificationIdFor(RemoteMessage message) {
    final sentTime = message.sentTime?.millisecondsSinceEpoch;
    if (sentTime != null) return sentTime.remainder(2147483647);
    final id = message.messageId;
    if (id != null && id.isNotEmpty) return id.hashCode & 0x7fffffff;
    return DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
  }
}
