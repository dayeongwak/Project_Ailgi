import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class NotificationService {
  NotificationService(this._plugin);
  final FlutterLocalNotificationsPlugin _plugin;

  /// 알림 채널(안드로이드)
  static const AndroidNotificationDetails _androidDetails =
  AndroidNotificationDetails(
    'ailgi_daily_reminder',          // 채널 ID
    'Daily Diary Reminder',          // 채널 이름
    channelDescription: '매일 21시에 일기 알림',
    importance: Importance.max,
    priority: Priority.high,
  );

  static const NotificationDetails _details =
  NotificationDetails(android: _androidDetails);

  /// 날짜를 정수 알림 ID로 바꿔 고유성 보장 (예: 2025-10-01 -> 20251001)
  int _idFromDate(DateTime day) =>
      int.parse(DateFormat('yyyyMMdd').format(day));

  /// 오늘 21:00 TZ
  tz.TZDateTime _todayAt21() {
    final now = tz.TZDateTime.now(tz.local);
    return tz.TZDateTime(tz.local, now.year, now.month, now.day, 21, 0);
  }

  /// 특정 날짜 21:00
  tz.TZDateTime _dateAt21(DateTime date) =>
      tz.TZDateTime(tz.local, date.year, date.month, date.day, 21, 0);

  /// 오늘 알림 예약 (이미 예약되어 있으면 덮어씀)
  Future<void> scheduleTodayIfNeeded({
    required bool hasWrittenToday,
  }) async {
    if (hasWrittenToday) {
      // 이미 작성했으면 오늘 알림 취소
      await cancelForDate(DateTime.now());
      return;
    }
    final id = _idFromDate(DateTime.now());
    await _plugin.zonedSchedule(
      id,
      '오늘 하루 어땠어요?',
      '아직 일기 안 썼다면, 잠깐 정리해볼까요? ✍️',
      _todayAt21(),
      _details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      payload: 'daily_diary',
    );
  }

  /// 임의 날짜에 대한 알림 예약 (필요하면 내일/모레용도)
  Future<void> scheduleForDateIfNeeded({
    required DateTime date,
    required bool hasWritten,
  }) async {
    if (hasWritten) {
      await cancelForDate(date);
      return;
    }
    final id = _idFromDate(date);
    await _plugin.zonedSchedule(
      id,
      '오늘 하루 어땠어요?',
      '아직 일기 안 썼다면, 잠깐 정리해볼까요? ✍️',
      _dateAt21(date),
      _details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      payload: 'daily_diary',
    );
  }

  /// 해당 날짜 알림 취소
  Future<void> cancelForDate(DateTime date) async {
    await _plugin.cancel(_idFromDate(date));
  }
}
