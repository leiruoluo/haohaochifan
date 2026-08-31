import 'package:flutter/cupertino.dart' show showCupertinoModalPopup, CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/settlement.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'day_detail_page.dart';

/// 日历月视图：每天显示摄入与达标状态圆点
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _anchor;
  Map<int, DaySettlement> _settlements = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _anchor = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final state = context.read<AppState>();
    final first = DateTime(_anchor.year, _anchor.month, 1);
    final last = DateTime(_anchor.year, _anchor.month + 1, 0);
    final logs = await state.logsInRange(first, last);
    final map = <int, DaySettlement>{};
    for (final log in logs) {
      final s = settleDay(
        log: log,
        foods: state.foodMap,
        dishes: state.dishMap,
        profile: state.profile ?? const UserProfile(),
      );
      if (s.hasData) map[log.date.millisecondsSinceEpoch] = s;
    }
    if (mounted) {
      setState(() {
        _settlements = map;
        _loading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _anchor = DateTime(_anchor.year, _anchor.month + delta, 1);
    });
    _load();
  }

  Future<void> _openDay(DateTime day) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DayDetailPage(date: day)));
    _load(); // 返回后刷新
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = DateTime(_anchor.year, _anchor.month, 1);
    final daysInMonth = DateTime(_anchor.year, _anchor.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday % 7; // 周一为第一列
    final totalCells = ((leadingBlanks + daysInMonth) / 7).ceil() * 7;

    return Column(
      children: [
        _header(),
        const SizedBox(height: 4),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : GestureDetector(
                  onHorizontalDragEnd: (d) {
                    // 左右滑动切换月份
                    if (d.primaryVelocity != null) {
                      if (d.primaryVelocity! < -150) _changeMonth(1);
                      if (d.primaryVelocity! > 150) _changeMonth(-1);
                    }
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    children: [
                      _weekRow(),
                      const SizedBox(height: 2),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 0.95,
                        ),
                        itemCount: totalCells,
                        itemBuilder: (context, i) {
                          final dayNum = i - leadingBlanks + 1;
                          if (dayNum < 1 || dayNum > daysInMonth) {
                            return const SizedBox();
                          }
                          final date =
                              DateTime(_anchor.year, _anchor.month, dayNum);
                          return _dayCell(date, dayNum, today);
                        },
                      ),
                      const SizedBox(height: 12),
                      const _Legend(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _header() {
    final isCurrentMonth = _anchor.year == DateTime.now().year &&
        _anchor.month == DateTime.now().month;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: InkWell(
              onTap: _pickYearMonth,
              borderRadius: BorderRadius.circular(8),
              child: Center(
                child: Text('${_anchor.year}年${_anchor.month}月',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          IconButton(
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right)),
          TextButton(
            onPressed: isCurrentMonth
                ? null
                : () {
                    setState(() => _anchor = DateTime.now());
                    _load();
                  },
            child: const Text('今天'),
          ),
        ],
      ),
    );
  }

  /// 点击年月弹出轮盘选择器快速切换
  Future<void> _pickYearMonth() async {
    final now = DateTime.now();
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (_) => Container(
        height: 260,
        color: Colors.white,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: _anchor,
          minimumDate: DateTime(now.year - 10, 1),
          maximumDate: DateTime(now.year + 10, 12, 31),
          onDateTimeChanged: (d) {
            Navigator.of(context).pop(d);
          },
        ),
      ),
    );
    if (picked != null) {
      setState(() => _anchor = DateTime(picked.year, picked.month, 1));
      _load();
    }
  }

  Widget _weekRow() {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: labels
          .map((l) => Expanded(
                child: Center(
                    child: Text(l,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.inkLight))),
              ))
          .toList(),
    );
  }

  Widget _dayCell(DateTime date, int dayNum, DateTime today) {
    final key = date.millisecondsSinceEpoch;
    final s = _settlements[key];
    final isToday = date == today;
    final hasLog = s != null;
    Color? dot;
    if (hasLog) {
      dot = s.achieved
          ? AppTheme.green
          : (s.intakeKcal > 0 ? AppTheme.red : AppTheme.amber);
    }
    final kcal = hasLog ? s.intakeKcal.round() : null;

    return InkWell(
      onTap: () => _openDay(date),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: isToday ? AppTheme.primary.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(10),
          border: isToday
              ? Border.all(color: AppTheme.primary, width: 1.2)
              : null,
        ),
        // 固定布局：数字位置恒定，状态区在数字下方固定高度，不改变数字位置
        child: Column(
          children: [
            const SizedBox(height: 5),
            Text('$dayNum',
                style: TextStyle(
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    color: isToday ? AppTheme.primary : AppTheme.ink)),
            const Spacer(),
            SizedBox(
              height: 13,
              child: Center(
                child: dot != null
                    ? Container(
                        width: 7,
                        height: 7,
                        decoration:
                            BoxDecoration(color: dot, shape: BoxShape.circle))
                    : (kcal != null
                        ? Text('$kcal',
                            style: const TextStyle(
                                fontSize: 9, color: AppTheme.inkLight))
                        : const SizedBox.shrink()),
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(t, style: const TextStyle(fontSize: 11, color: AppTheme.inkLight)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          item(AppTheme.green, '达标'),
          item(AppTheme.red, '已记录·未达标'),
          item(AppTheme.amber, '仅运动/饮水'),
        ],
      ),
    );
  }
}
