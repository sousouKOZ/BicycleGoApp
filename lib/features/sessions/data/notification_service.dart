import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// セッション関連のローカル通知を管理するサービス。
///
/// - 10分経過通知: 「あと5分でクーポンが届きます」
/// - 15分達成通知: 「🎉 クーポンが発行されました」
///
/// サーバー不要でローカルに予約するため、バックエンド実装を待たずに動作する。
/// 後で FCM に切り替える場合も、このサービスのインタフェースは温存できる。
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'bicycle_go_session';
  static const _channelName = '駐輪セッション通知';
  static const _channelDescription = '15分の駐輪セッション進捗を通知します';

  static const int _reminderId = 1001;
  static const int _achievedId = 1002;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// 通知権限を要求。iOS/Android 13+ で明示的に必要。
  /// 既に許可/拒否済みなら true/false を返す。
  Future<bool> requestPermissions() async {
    await init();
    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? true; // 旧API端末は true
    }
    return false;
  }

  /// セッション開始時に呼び出し。10分経過通知と15分達成通知を同時予約する。
  Future<void> scheduleSessionReminders({
    required DateTime sessionStartAt,
    int reminderSeconds = 10 * 60,
    int achievedSeconds = 15 * 60,
    String? parkingName,
  }) async {
    await init();
    await cancelSessionReminders();

    final reminderAt = sessionStartAt.add(Duration(seconds: reminderSeconds));
    final achievedAt = sessionStartAt.add(Duration(seconds: achievedSeconds));
    final now = DateTime.now();

    if (reminderAt.isAfter(now)) {
      await _plugin.zonedSchedule(
        _reminderId,
        'もう少しでクーポンが届きます',
        parkingName != null
            ? '$parkingName で駐輪中 — あと約5分で発行されます'
            : 'あと約5分で発行されます',
        tz.TZDateTime.from(reminderAt, tz.local),
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    if (achievedAt.isAfter(now)) {
      await _plugin.zonedSchedule(
        _achievedId,
        '🎉 クーポンが発行されました！',
        parkingName != null
            ? '$parkingName での15分駐輪達成 — アプリを開いてクーポンを受け取ろう'
            : '15分駐輪達成 — アプリを開いてクーポンを受け取ろう',
        tz.TZDateTime.from(achievedAt, tz.local),
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// セッションキャンセル/完了時に呼び出し。
  Future<void> cancelSessionReminders() async {
    await init();
    await _plugin.cancel(_reminderId);
    await _plugin.cancel(_achievedId);
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
