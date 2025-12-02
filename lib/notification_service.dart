import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';

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
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (e) {
      print("Timezone setup error: $e");
    }

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
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }
  }

  // ✅ [수정됨] 알림 내역 저장 시 제목(title)도 함께 저장
  Future<void> _saveNotificationToHistory(String? uid, String title, String body, String type) async {
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'type': type,
        'fromNickname': 'Ailgi',
        'title': title, // 저장할 때 제목 포함
        'body': body,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print("✅ Notification saved: $title");
    } catch (e) {
      print("❌ Failed to save notification: $e");
    }
  }

  Future<void> scheduleDailyNotification(String? uid) async {
    final prefs = await SharedPreferences.getInstance();
    final dailyEnabled = prefs.getBool(_getPrefKey(uid, KEY_DAILY_NOTIFY_ENABLED)) ?? true;

    if (!dailyEnabled) {
      await _plugin.cancel(0);
      return;
    }

    final timeString = prefs.getString(_getPrefKey(uid, KEY_NOTIFY_TIME)) ?? '21:00';
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      0,
      '오늘의 일기를 써볼까요? ✍️',
      'Ailgi가 기다리고 있어요 💬',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ailgi_daily_channel_v2',
          'Ailgi Daily Reminder',
          channelDescription: '매일 일기 쓰기 알림',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> rescheduleNotification(String? uid) async {
    await _plugin.cancel(0);
    await scheduleDailyNotification(uid);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  Future<void> showSimpleNotification({
    required String title,
    required String body,
    String payload = '',
    String? uid,
  }) async {
    const int foregroundNotificationId = 99;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'ailgi_fcm_foreground',
        'Ailgi Realtime',
        channelDescription: '실시간 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    await _plugin.show(foregroundNotificationId, title, body, details, payload: payload);

    if (uid != null) {
      // ✅ 알림 발송 시 제목을 그대로 DB에 저장 (system 타입)
      await _saveNotificationToHistory(uid, title, body, 'system');
    }
  }
}