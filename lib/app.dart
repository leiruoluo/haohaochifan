import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'db/database.dart' as dbmod;
import 'db/repository.dart';
import 'pages/calendar_page.dart';
import 'pages/plan_page.dart';
import 'pages/recipe_page.dart';
import 'pages/settings_page.dart';
import 'pages/stats_page.dart';
import 'state/app_state.dart';
import 'theme.dart';

/// 主入口壳：手机底部导航 / 桌面侧边导航
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  Timer? _reminderTimer;
  final Set<String> _firedToday = {};

  static const _pages = [
    CalendarPage(),
    StatsPage(),
    RecipePage(),
    PlanPage(),
    SettingsPage(),
  ];

  static const _titles = ['日历', '统计', '菜谱', '计划', '设置'];

  @override
  void initState() {
    super.initState();
    // 桌面端应用内提醒（Android 由系统通知承担）
    _reminderTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _checkReminders());
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  void _checkReminders() {
    if (!mounted) return;
    final p = context.read<AppState>().profile;
    if (p == null) return;
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    final minute = now.hour * 60 + now.minute;

    void fire(String id, int h, int m, String msg) {
      final target = h * 60 + m;
      if (minute < target || minute >= target + 5) return;
      final key = '$todayKey:$id';
      if (_firedToday.contains(key)) return;
      _firedToday.add(key);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 8)));
    }

    if (p.remindBreakfast) fire('bf', 8, 0, '早餐时间 🍳 别忘了好好吃早餐！');
    if (p.remindLunch) fire('lu', 12, 0, '午餐时间 🍱 按时吃饭，营养均衡。');
    if (p.remindDinner) fire('di', 18, 0, '晚餐时间 🥗 晚餐清淡一些。');
    if (p.remindWater) {
      fire('w1', 10, 0, '喝水提醒 💧 补充水分。');
      fire('w2', 15, 0, '喝水提醒 💧 下午也要记得喝水。');
      fire('w3', 20, 0, '喝水提醒 💧 睡前适量喝水。');
    }
    if (p.remindSettle) {
      fire('st', p.settleHour, p.settleMinute, '今日结算提醒 📊 去记今天的饮食和运动吧！');
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      body: Row(
        children: [
          if (wide) _rail(),
          Expanded(
            child: Column(
              children: [
                if (!wide)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.restaurant,
                              color: AppTheme.primary, size: 26),
                          const SizedBox(width: 8),
                          Text(_titles[_index],
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 12),
                          _sloganChip(context),
                        ],
                      ),
                    ),
                  ),
                Expanded(child: _pages[_index]),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: '日历'),
                NavigationDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights),
                    label: '统计'),
                NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: '菜谱'),
                NavigationDestination(
                    icon: Icon(Icons.event_note_outlined),
                    selectedIcon: Icon(Icons.event_note),
                    label: '计划'),
                NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: '设置'),
              ],
            ),
    );
  }

  Widget _rail() {
    return NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      labelType: NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        child: Column(
          children: const [
            Icon(Icons.restaurant, color: AppTheme.primary, size: 34),
            SizedBox(height: 4),
            Text('好好吃饭',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink)),
          ],
        ),
      ),
      destinations: const [
        NavigationRailDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: Text('日历')),
        NavigationRailDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: Text('统计')),
        NavigationRailDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: Text('菜谱')),
        NavigationRailDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: Text('计划')),
        NavigationRailDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: Text('设置')),
      ],
    );
  }

  Widget _sloganChip(BuildContext context) {
    final state = context.watch<AppState>();
    return Expanded(
      child: Text(
        state.profile?.slogan.isNotEmpty == true
            ? state.profile!.slogan
            : '好好吃饭，好好生活',
        textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppTheme.inkLight),
      ),
    );
  }
}

/// 初始化入口（由 main 调用）
Future<AppState> createAppState() async {
  final db = await dbmod.database;
  final repo = AppRepository(db);
  final state = AppState(repo);
  await state.init();
  return state;
}
