import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart'
    show showCupertinoModalPopup, CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/settlement.dart';
import '../models/exercise.dart' show WeightRecord;
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// 统计页：月统计（摄入/消耗、缺口、食物次数、体重）+ 年统计
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _yearly = false;
  late DateTime _anchor; // 当前查看的月份或年份
  List<DaySettlement> _settlements = [];
  List<WeightRecord> _weights = [];
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
    final DateTime start, end;
    if (_yearly) {
      start = DateTime(_anchor.year, 1, 1);
      end = DateTime(_anchor.year, 12, 31);
    } else {
      start = DateTime(_anchor.year, _anchor.month, 1);
      end = DateTime(_anchor.year, _anchor.month + 1, 0);
    }
    final logs = await state.logsInRange(start, end);
    final ss = <DaySettlement>[];
    final profile = state.profile ?? const UserProfile();
    for (final log in logs) {
      ss.add(settleDay(
          log: log,
          foods: state.foodMap,
          dishes: state.dishMap,
          profile: profile));
    }
    final weights = await state.weights();
    if (mounted) {
      setState(() {
        _settlements = ss;
        _weights = weights
            .where((w) =>
                !w.date.isBefore(start) && !w.date.isAfter(end))
            .toList();
        _loading = false;
      });
    }
  }

  void _shift(int delta) {
    setState(() {
      if (_yearly) {
        _anchor = DateTime(_anchor.year + delta, 1);
      } else {
        _anchor = DateTime(_anchor.year, _anchor.month + delta, 1);
      }
    });
    _load();
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
      setState(() {
        _anchor = _yearly
            ? DateTime(picked.year, 1)
            : DateTime(picked.year, picked.month, 1);
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: _pickYearMonth,
                    child: Text(
                        _yearly
                            ? '${_anchor.year}年'
                            : '${_anchor.year}年${_anchor.month}月',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              IconButton(
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right)),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('月')),
                  ButtonSegment(value: true, label: Text('年')),
                ],
                selected: {_yearly},
                onSelectionChanged: (s) {
                  setState(() => _yearly = s.first);
                  _load();
                },
                showSelectedIcon: false,
                style: const ButtonStyle(
                    visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (d) {
                    if (d.primaryVelocity == null) return;
                    if (d.primaryVelocity! < -150) _shift(1);
                    if (d.primaryVelocity! > 150) _shift(-1);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                    children: _yearly ? _yearlyCards() : _monthlyCards(),
                  ),
                ),
        ),
      ],
    );
  }

  // ================= 月统计 =================
  List<Widget> _monthlyCards() {
    final days = DateTime(_anchor.year, _anchor.month + 1, 0).day;
    final byDay = <int, DaySettlement>{};
    for (final s in _settlements) {
      byDay[s.date.day] = s;
    }
    final achievedCount =
        _settlements.where((s) => s.achieved).length;
    final waterOk = _settlements.where((s) => s.waterAchieved).length;
    final avgIntake = _settlements.isEmpty
        ? 0.0
        : _settlements.map((s) => s.intakeKcal).reduce((a, b) => a + b) /
            _settlements.length;
    final foodCount = _foodFrequency();

    return [
      _summaryStrip(achievedCount, waterOk, avgIntake),
      _card('每日摄入 / 消耗（kcal）',
          _dualLine(days, byDay, intake: true)),
      _card('每日热量缺口 / 盈余（kcal）',
          _deficitLine(days, byDay)),
      _card('食物 / 菜肴次数 TOP',
          foodCount.isEmpty
              ? const _EmptyHint('本月暂无食物记录')
              : _foodRankList(foodCount)),
      _card('体重趋势（kg）', _weightChart()),
      if (_weights.isEmpty && _settlements.isEmpty)
        const _EmptyHint('本月还没有任何记录，先去日历记一笔吧 📝'),
    ];
  }

  Widget _summaryStrip(int achieved, int waterOk, double avgIntake) {
    Widget item(String v, String l) => Column(
          children: [
            Text(v,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary)),
            Text(l,
                style:
                    const TextStyle(fontSize: 11, color: AppTheme.inkLight)),
          ],
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            item('${_settlements.length}', '记录天数'),
            item('$achieved', '达标天数'),
            item('$waterOk', '饮水达标'),
            item('${avgIntake.round()}', '日均摄入'),
          ],
        ),
      ),
    );
  }

  Map<String, int> _foodFrequency() {
    final map = <String, int>{};
    for (final s in _settlements) {
      for (final r in s.resolvedEntries) {
        map[r.entry.name] = (map[r.entry.name] ?? 0) + 1;
      }
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted.take(10)) e.key: e.value};
  }

  Widget _foodRankList(Map<String, int> freq) {
    final max = freq.values.first;
    return Column(
      children: freq.entries.map((e) {
        final ratio = max <= 0 ? 0.0 : e.value / max;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                  width: 110,
                  child: Text(e.key,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFF2E8DD),
                    color: AppTheme.primary,
                  ),
                ),
              ),
              SizedBox(
                  width: 40,
                  child: Text(' ${e.value}次',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.inkLight))),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ================= 年统计 =================
  List<Widget> _yearlyCards() {
    final totalDays = _settlements.length;
    final achieved = _settlements.where((s) => s.achieved).length;
    final totalDeficit = _settlements.fold<double>(
        0, (sum, s) => sum + s.deficit);
    final avgIntake = totalDays == 0
        ? 0.0
        : _settlements.map((s) => s.intakeKcal).reduce((a, b) => a + b) /
            totalDays;

    // 月度平均摄入
    final monthAvg = <int, double>{};
    final monthCnt = <int, int>{};
    for (final s in _settlements) {
      monthAvg[s.date.month] =
          (monthAvg[s.date.month] ?? 0) + s.intakeKcal;
      monthCnt[s.date.month] = (monthCnt[s.date.month] ?? 0) + 1;
    }

    final foodCount = _foodFrequency();

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _bigStat('$totalDays', '记录天数'),
                  _bigStat('$achieved', '达标天数'),
                  _bigStat(
                      '${(totalDeficit / 1000).toStringAsFixed(1)}k', '年总缺口 kcal'),
                ],
              ),
              const Divider(height: 24),
              _bigStat('${avgIntake.round()}', '日均摄入 kcal'),
            ],
          ),
        ),
      ),
      _card('每月日均摄入（kcal）', _monthlyBar(monthAvg, monthCnt)),
      _card('全年体重趋势（kg）', _weightChart()),
      _card('年度食物 / 菜肴 TOP10',
          foodCount.isEmpty
              ? const _EmptyHint('今年暂无食物记录')
              : _foodRankList(foodCount)),
    ];
  }

  Widget _bigStat(String v, String l) => Column(
        children: [
          Text(v,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primary)),
          Text(l,
              style: const TextStyle(fontSize: 11, color: AppTheme.inkLight)),
        ],
      );

  // ================= 图表 =================
  Widget _card(String title, Widget child) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );

  Widget _dualLine(int days, Map<int, DaySettlement> byDay,
      {required bool intake}) {
    final spotsIn = [
      for (var d = 1; d <= days; d++)
        if (byDay[d] != null)
          FlSpot(d.toDouble(), byDay[d]!.intakeKcal),
    ];
    final spotsOut = [
      for (var d = 1; d <= days; d++)
        if (byDay[d] != null)
          FlSpot(d.toDouble(), byDay[d]!.totalExpenditure),
    ];
    return _lineChart(
      [spotsIn, spotsOut],
      colors: const [AppTheme.primary, AppTheme.blue],
      labels: ['摄入', '消耗'],
      fixedMaxX: days.toDouble(),
    );
  }

  Widget _deficitLine(int days, Map<int, DaySettlement> byDay) {
    final ideal = _settlements.isNotEmpty
        ? _settlements.first.idealDeficit
        : -300.0;
    final spots = [
      for (var d = 1; d <= days; d++)
        if (byDay[d] != null) FlSpot(d.toDouble(), byDay[d]!.deficit),
    ];
    return _lineChart(
      [spots],
      colors: const [AppTheme.red],
      labels: const ['缺口'],
      referenceY: ideal,
      referenceLabel: '理想缺口 ${ideal.round()}',
      fixedMaxX: days.toDouble(),
    );
  }

  Widget _lineChart(
    List<List<FlSpot>> series, {
    required List<Color> colors,
    required List<String> labels,
    double? referenceY,
    String? referenceLabel,
    double? fixedMaxX,
  }) {
    final all = [...series.expand((s) => s)];
    final maxX = fixedMaxX ?? (all.isEmpty ? 31 : all.map((p) => p.x).reduce((a, b) => a > b ? a : b));
    final maxY = all.fold<double>(0, (m, p) => p.y > m ? p.y : m);
    final minY = all.fold<double>(0, (m, p) => p.y < m ? p.y : m);
    final range = (maxY - minY).abs();
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: maxX,
          minY: minY - range * 0.15,
          maxY: maxY + range * 0.15 + 1,
          gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (range / 4).clamp(1, 1000)),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 52),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (maxX / 5).ceilToDouble(),
                getTitlesWidget: (v, meta) =>
                    Text('${v.toInt()}',
                        style: const TextStyle(fontSize: 10, color: AppTheme.inkLight)),
              ),
            ),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            for (var i = 0; i < series.length; i++)
              LineChartBarData(
                spots: series[i],
                isCurved: true,
                color: colors[i],
                barWidth: 2.4,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: i == 0,
                  color: colors[i].withValues(alpha: 0.08),
                ),
              ),
            if (referenceY != null)
              LineChartBarData(
                spots: [
                  for (var x = 1.0; x <= maxX; x += 1)
                    FlSpot(x, referenceY),
                ],
                color: AppTheme.amber.withValues(alpha: 0.6),
                barWidth: 1.4,
                dashArray: [6, 4],
                dotData: const FlDotData(show: false),
              ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (var i = 0; i < spots.length; i++)
                  LineTooltipItem(
                    '${labels[i]}: ${spots[i].y.round()}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _weightChart() {
    // 少于 2 个点无法成线：空白区域（带边框），未输入体重时保持空白
    if (_weights.length < 2) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE8DCCF), width: 1.2),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: _weights.isEmpty
            ? const Text('暂无体重记录',
                style: TextStyle(fontSize: 12, color: AppTheme.inkLight))
            : Text('仅有 1 条体重记录，再多记一条即可生成趋势',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.inkLight)),
      );
    }
    final spots = [
      for (var i = 0; i < _weights.length; i++)
        FlSpot(i.toDouble(), _weights[i].weightKg),
    ];
    final maxX = spots.length - 1.0;
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(6, 8, 12, 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE8DCCF), width: 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (v, meta) => Text(
                        v == v.roundToDouble() ? '${v.toInt()}' : '',
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.inkLight)))),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: (maxX / 6).ceilToDouble(),
                getTitlesWidget: (v, meta) {
                  final i = v.toInt().clamp(0, _weights.length - 1);
                  final d = _weights[i].date;
                  return Text('${d.month}/${d.day}',
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.inkLight));
                },
              ),
            ),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.green,
              barWidth: 2.4,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.green.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChart _monthlyBar(Map<int, double> avg, Map<int, int> cnt) {
    return LineChart(
      LineChartData(
        minX: 1,
        maxX: 12,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: _monthTitle,
            ),
          ),
          topTitles: AxisTitles(),
          rightTitles: AxisTitles(),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var m = 1; m <= 12; m++)
                FlSpot(m.toDouble(), avg[m] ?? 0),
            ],
            isCurved: true,
            color: AppTheme.primary,
            barWidth: 2.4,
            dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 3,
                  color: avg[spot.x.toInt()] == null
                      ? Colors.transparent
                      : AppTheme.primary,
                )),
          ),
        ],
      ),
    );
  }

  Widget _monthTitle(double value, TitleMeta meta) {
    if (value.toInt() == 0) return const SizedBox();
    return Text('${value.toInt()}月',
        style: const TextStyle(fontSize: 10, color: AppTheme.inkLight));
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
            child: Text(text,
                style: const TextStyle(color: AppTheme.inkLight))),
      );
}
