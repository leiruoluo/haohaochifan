/// 本地提醒服务（Android 通知；Windows 用应用内提示兜底）
/// Android 受系统省电策略影响可能延迟，需引导用户加入白名单
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/profile.dart';

class ReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;
    _inited = true; // 防止重入
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(settings);
    } catch (_) {
      // 平台不支持（如测试环境）时静默降级
    }
  }

  static Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  /// 按档案设置安排每日提醒；先清空再重建（幂等）
  /// 任何平台异常都不应影响主流程
  static Future<void> scheduleAll(UserProfile p) async {
    try {
      await _plugin.cancelAll();
      final now = tz.TZDateTime.now(tz.local);

    Future<void> daily(int id, int hour, int minute, String title,
        String body) async {
      try {
        var next = tz.TZDateTime(
            tz.local, now.year, now.month, now.day, hour, minute);
        if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          next,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_reminder',
              '每日提醒',
              channelDescription: '三餐、喝水与结算提醒',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (_) {}
    }

    if (p.remindBreakfast) {
      await daily(101, 8, 0, '早餐时间 🍳', '别忘了好好吃早餐！');
    }
    if (p.remindLunch) {
      await daily(102, 12, 0, '午餐时间 🍱', '按时吃饭，营养均衡。');
    }
    if (p.remindDinner) {
      await daily(103, 18, 0, '晚餐时间 🥗', '晚餐清淡一些，睡前别吃太饱。');
    }
    if (p.remindWater) {
      await daily(104, 10, 0, '喝水提醒 💧', '补充水分，代谢更好。');
      await daily(105, 15, 0, '喝水提醒 💧', '下午也要记得喝水。');
      await daily(106, 20, 0, '喝水提醒 💧', '睡前适量喝水。');
    }
    if (p.remindSettle) {
      await daily(107, p.settleHour, p.settleMinute, '今日结算提醒 📊',
          '该结算今天的饮食和运动啦，去看看吧。');
    }
    } catch (_) {
      // 任何平台异常静默降级
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
