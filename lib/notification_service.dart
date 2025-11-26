// lib/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// 친구 관련 키 삭제됨
const String KEY_ALL_NOTIFY_ENABLED = '_all_notify_enabled';
const String KEY_DAILY_NOTIFY_ENABLED = '_daily_push_notify_enabled';
const String KEY_NOTIFY_TIME = '_notify_time';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  String _getPrefKey(String? uid, String suffix) {
    return "${uid ?? 'GUEST'}$suffix";
  }

  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: darwin, macOS: darwin);

    await _plugin.initialize(settings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      print("🔔 Notification permission granted: $granted");
    }
  }

  /// 🔔 매일 알림 예약 (UID 필요)
  Future<void> scheduleDailyNotification(String? uid) async {
    final prefs = await SharedPreferences.getInstance();

    final allEnabled = prefs.getBool(_getPrefKey(uid, KEY_ALL_NOTIFY_ENABLED)) ?? true;
    final dailyEnabled = prefs.getBool(_getPrefKey(uid, KEY_DAILY_NOTIFY_ENABLED)) ?? true;

    if (!allEnabled || !dailyEnabled) {
      await _plugin.cancel(0);
      return;
    }

    final timeString = prefs.getString(_getPrefKey(uid, KEY_NOTIFY_TIME)) ?? '21:00';
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      0, // 매일 알림 ID
      '오늘의 일기를 써볼까요? ✍️',
      'Ailgi가 기다리고 있어요 💬',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ailgi_daily_channel',
          'Ailgi Daily',
          channelDescription: 'Ailgi 매일 알림',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // 친구, 공감, 댓글 알림 메서드 삭제됨

  /// 🔁 설정 변경 시 재예약 (UID 필요)
  Future<void> rescheduleNotification(String? uid) async {
    await _plugin.cancel(0);
    await scheduleDailyNotification(uid);
  }

  /// ❌ 알림 전체 취소
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  /// 📱 (FCM용) 앱이 켜져있을 때 간단한 알림 띄우기
  Future<void> showSimpleNotification({
    required String title,
    required String body,
    String payload = '',
  }) async {
    const int foregroundNotificationId = 99; // 포그라운드 전용 ID

    const String channelId = 'ailgi_fcm_foreground_channel';
    const String channelName = 'Ailgi 실시간 알림';
    const String channelDescription = '앱 사용 중 도착하는 실시간 알림';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      foregroundNotificationId,
      title,
      body,
      details,
      payload: payload,
    );
  }
}