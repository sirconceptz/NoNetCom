part of '../../main.dart';

class AppNotifications {
  static const _channelId = 'messages';
  static const _channelName = 'Wiadomości';
  static const _channelDescription =
      'Powiadomienia o nowych wiadomościach NoNetCom';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> load() async {
    try {
      const androidSettings = AndroidInitializationSettings('ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
          macOS: iosSettings,
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
              playSound: true,
            ),
          );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _ready = true;
    } on Object {
      _ready = false;
    }
  }

  Future<void> showMessage({
    required String title,
    required String body,
    required String messageId,
    required String threadId,
  }) async {
    if (!_ready) return;
    final notificationBody = body.length > 140
        ? '${body.substring(0, 137)}...'
        : body;
    try {
      await _plugin.show(
        id: messageId.hashCode & 0x7fffffff,
        title: title,
        body: notificationBody,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
            groupKey: threadId,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            presentBanner: true,
            presentList: true,
          ),
          macOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: threadId,
      );
    } on Object {
      _ready = false;
    }
  }
}
