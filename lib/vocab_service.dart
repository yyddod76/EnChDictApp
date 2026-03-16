import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

// VocabListInfo model
class VocabListInfo {
  final String key;
  final String nameEn;
  final String nameZh;
  final int wordCount;
  VocabListInfo({required this.key, required this.nameEn, required this.nameZh, required this.wordCount});
}

// VocabRegistration model
class VocabRegistration {
  final String listKey;
  final int mode; // 0=sequential, 1=random
  final String listNameEn;
  final String listNameZh;
  VocabRegistration({required this.listKey, required this.mode, required this.listNameEn, required this.listNameZh});
}

// VocabCard model
class VocabCard {
  final String word;
  final bool isNew;
  VocabCard({required this.word, required this.isNew});
}

// Ebbinghaus SM-2 simplified: given repetition count, return next interval in days
int ebbinghausNextInterval(int repetitions, int currentIntervalDays) {
  if (repetitions == 0) return 1;
  if (repetitions == 1) return 3;
  if (repetitions == 2) return 7;
  if (repetitions == 3) return 14;
  return (currentIntervalDays * 2.5).round().clamp(30, 365);
}

// Notification service
class VocabNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings, onDidReceiveNotificationResponse: _onNotificationTap);
    _initialized = true;
  }

  static void _onNotificationTap(NotificationResponse response) {
    // App is opened when user taps notification
  }

  static Future<void> scheduleDailyReminder(int langMode) async {
    await _plugin.cancelAll();
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0, 0);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    const androidDetails = AndroidNotificationDetails(
      'vocab_daily', 'Daily Vocabulary',
      channelDescription: 'Daily reminder to review vocabulary',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notifDetails = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    final title = langMode == 0 ? 'Time to review vocabulary!' : '该复习单词啦！';
    final body = langMode == 0 ? "Don't forget your daily vocabulary review." : '每日单词复习任务等待你完成。';
    await _plugin.zonedSchedule(
      1,
      title,
      body,
      scheduledDate,
      notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelReminder() async {
    await _plugin.cancelAll();
  }
}
