import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../engine/settlement.dart';
import '../engine/slogan.dart';
import '../models/exercise.dart' show WeightRecord;
import '../models/log.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/uuid.dart';
import '../widgets/exercise_picker.dart';
import '../widgets/food_picker.dart';

/// 某一天的详情页：餐次记录 / 饮水 / 运动 / 实时结算
class DayDetailPage extends StatefulWidget {
  final DateTime date;
  const DayDetailPage({super.key, required this.date});

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  DayLog? _log;
  DaySettlement? _s;
  String _slogan = '';
  WeightRecord? _weight;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final state = context.read<AppState>();
    final log = await state.dayLog(widget.date);
    final s = await state.settlement(widget.date);
    final profile = state.profile ?? const UserProfile();
    final weight = await state.weightForDate(widget.date);
    if (mounted) {
      setState(() {
        _log = log;
        _s = s;
        _weight = weight;
        _slogan = pickSlogan(
            profile: profile, s: s, dayOfYear: widget.date.difference(DateTime(widget.date.year)).inDays);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = _log;
    final s = _s;
    if (log == null || s == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_title())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_title()),
        actions: [
          TextButton.icon(
            onPressed: () => _showSettlement(s),
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('结算'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          _sloganBar(),
          _summaryCard(s),
          _waterCard(log, s),
          _weightCard(log),
          ..._mealCards(log),
          _addMealButton(),
          _exerciseCard(log, s),
          if (log.note.isNotEmpty)
            Card(
                child: ListTile(
                    leading: const Icon(Icons.notes),
                    title: Text(log.note))),
        ],
      ),
    );
  }

  String _title() {
    final d = widget.date;
    final today = DateTime.now();
    final isToday = DateTime(today.year, today.month, today.day) ==
        DateTime(d.year, d.month, d.day);
    final wd = DateFormat('EEEE', 'zh_CN').format(d);
    return isToday ? '今天 · $wd' : '${d.month}月${d.day}日 · $wd';
  }

  Widget _sloganBar() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_outlined,
                size: 18, color: AppTheme.amber),
            const SizedBox(width: 6),
            Expanded(
              child: Text('$_slogan',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.inkLight,
                      fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      );

  Widget _summaryCard(DaySettlement s) {
    final gap = s.gapFromIdeal;
    final status = s.achieved
        ? '达标 🎉'
        : (gap > 0 ? '缺口不足' : (gap < 0 ? '缺口过大' : ''));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('摄入', s.intakeKcal.round(), AppTheme.primary),
                _stat('日常活动', s.dailyActivityKcal.round(), AppTheme.blue),
                _stat('运动', s.exerciseKcal.round(), AppTheme.amber),
                _stat('缺口/盈余', s.deficit.round(),
                    s.deficit >= 0 ? AppTheme.green : AppTheme.red),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: s.achieved
                    ? AppTheme.green.withValues(alpha: 0.12)
                    : AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('理想缺口 ${s.idealDeficit.round()} kcal · 今日 $status',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: s.achieved ? AppTheme.green : AppTheme.ink)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _macroBar(s),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value, Color color) => Column(
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.inkLight)),
        ],
      );

  Widget _macroBar(DaySettlement s) {
    final ratio = s.intake.macroRatio();
    if (ratio.every((r) => r == 0)) return const SizedBox();
    Widget seg(Color c, double w) => Expanded(
        flex: (w * 100).round().clamp(1, 1000),
        child: Container(height: 8, color: c));
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              seg(const Color(0xFF4CAF50), ratio[0]),
              seg(const Color(0xFFFFB300), ratio[1]),
              seg(const Color(0xFF42A5F5), ratio[2]),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
            '蛋白 ${ratio[0].round()}% · 脂肪 ${ratio[1].round()}% · 碳水 ${ratio[2].round()}%',
            style: const TextStyle(fontSize: 11, color: AppTheme.inkLight)),
      ],
    );
  }

  Widget _waterCard(DayLog log, DaySettlement s) {
    final target = s.waterTargetMl;
    final progress =
        (target <= 0 ? 0.0 : (log.waterMl / target).clamp(0, 1)).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.water_drop, color: AppTheme.blue),
                const SizedBox(width: 6),
                Text('喝水  ${log.waterMl.round()} / $target ml',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (s.waterAchieved)
                  const Text('达标 ✅',
                      style:
                          TextStyle(fontSize: 12, color: AppTheme.green)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE3F0FC),
                  color: AppTheme.blue),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _waterBtn(context, log, 100),
                _waterBtn(context, log, 250),
                _waterBtn(context, log, 500),
                SizedBox(
                  width: 110,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    onSubmitted: (v) {
                      final ml = double.tryParse(v);
                      if (ml != null) _setWater(log, ml);
                    },
                    decoration: const InputDecoration(
                        hintText: '自定义ml', isDense: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _waterBtn(BuildContext context, DayLog log, double ml) =>
      OutlinedButton(
        onPressed: () => _setWater(log, log.waterMl + ml),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12)),
        child: Text('+${ml.round()}ml'),
      );

  Future<void> _setWater(DayLog log, double ml) async {
    await context.read<AppState>().updateWater(widget.date, ml.clamp(0, 99999));
    await _reload();
  }

  List<Widget> _mealCards(DayLog log) {
    if (log.meals.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('今天还没有记录，点下方按钮添加第一餐 🍚',
                style: TextStyle(color: AppTheme.inkLight)),
          ),
        ),
      ];
    }
    return log.meals.map((m) => _mealCard(log, m)).toList();
  }

  Widget _mealCard(DayLog log, MealLog meal) {
    final state = context.read<AppState>();
    var kcal = 0.0;
    for (final e in meal.entries) {
      if (e.isDish) {
        final d = state.dishMap[e.refId];
        if (d != null) kcal += d.computeNutrition(state.foodMap).energyKcal * e.amount;
      } else {
        final f = state.foodMap[e.refId];
        if (f != null) {
          kcal += f.per100.energyKcal *
              f.amountToBase(e.amount, e.unitName) /
              100;
        }
      }
    }
    return Card(
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Row(
              children: [
                Text(meal.mealName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('${kcal.round()} kcal',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.inkLight)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _removeMeal(meal.id),
            ),
          ),
          ...meal.entries.map((e) => ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                title: Text(e.name),
                subtitle: Text(
                    '${_fmtAmount(e.amount)} ${e.unitName}'
                    '${e.isDish ? '（菜肴）' : ''}'),
                trailing: Text('${_entryKcal(e).round()} kcal',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.inkLight)),
                onLongPress: () => _confirmDeleteEntry(meal, e),
              )),
          ListTile(
            dense: true,
            leading: const Icon(Icons.add_circle_outline,
                color: AppTheme.primary, size: 20),
            title: Text('添加到${meal.mealName}',
                style: const TextStyle(color: AppTheme.primary, fontSize: 13)),
            onTap: () => _addEntry(meal.mealName),
          ),
        ],
      ),
    );
  }

  double _entryKcal(LogEntry e) {
    final state = context.read<AppState>();
    if (e.isDish) {
      final d = state.dishMap[e.refId];
      if (d == null) return 0;
      return d.computeNutrition(state.foodMap).energyKcal * e.amount;
    }
    final f = state.foodMap[e.refId];
    if (f == null) return 0;
    return f.per100.energyKcal * f.amountToBase(e.amount, e.unitName) / 100;
  }

  Widget _addMealButton() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: OutlinedButton.icon(
          onPressed: _addNewMeal,
          icon: const Icon(Icons.add),
          label: const Text('添加餐次'),
        ),
      );

  Future<void> _addNewMeal() async {
    final name = await _promptMealName();
    if (name == null) return;
    await context.read<AppState>().saveDayLog(
        (await context.read<AppState>().dayLog(widget.date))
            .copyWith(meals: [
          ...?_log?.meals,
          MealLog(id: genUuid(), mealName: name, entries: const [])
        ]));
    await _reload();
  }

  Future<String?> _promptMealName() async {
    const presets = ['早餐', '午餐', '晚餐', '加餐'];
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新餐次名称'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 6,
              children: presets
                  .map((p) => ActionChip(
                      label: Text(p),
                      onPressed: () => Navigator.pop(ctx, p)))
                  .toList(),
            ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: '或输入自定义名称'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(
                  ctx, controller.text.trim().isEmpty ? null : controller.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
  }

  Future<void> _addEntry(String mealName) async {
    final entry = await showFoodPicker(context);
    if (entry == null) return;
    await context.read<AppState>().addEntry(widget.date, mealName, entry);
    await _reload();
  }

  Future<void> _removeMeal(String mealId) async {
    await context.read<AppState>().removeMeal(widget.date, mealId);
    await _reload();
  }

  Future<void> _confirmDeleteEntry(MealLog meal, LogEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: Text('${e.name} × ${_fmtAmount(e.amount)} ${e.unitName}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    final state = context.read<AppState>();
    final log = await state.dayLog(widget.date);
    final meals = log.meals
        .map((m) => m.id == meal.id
            ? MealLog(
                id: m.id,
                mealName: m.mealName,
                entries: m.entries.where((x) => x.id != e.id).toList())
            : m)
        .where((m) => m.entries.isNotEmpty || m.id != meal.id)
        .toList();
    await state.saveDayLog(log.copyWith(meals: meals));
    await _reload();
  }

  Widget _weightCard(DayLog log) {
    final w = _weight;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.monitor_weight_outlined,
            color: AppTheme.green),
        title: Text(w == null ? '体重' : '体重 ${w!.weightKg.toStringAsFixed(1)} kg'),
        subtitle: Text(w == null
            ? '记录今天的体重（可不用每天记）'
            : '已记录 · 点按可修改'),
        trailing: w == null
            ? FilledButton(
                onPressed: () => _editWeight(),
                child: const Text('记录'))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _editWeight(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _removeWeight(),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _editWeight() async {
    final controller = TextEditingController(
        text: _weight?.weightKg.toStringAsFixed(1) ?? '');
    final kg = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('记录体重'),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
              hintText: '如 65.5', suffixText: 'kg'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text)),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (kg != null && kg > 0 && kg < 500) {
      await context
          .read<AppState>()
          .saveWeightForDate(widget.date, kg);
      await _reload();
    }
  }

  Future<void> _removeWeight() async {
    final id = _weight?.id;
    if (id == null) return;
    await context.read<AppState>().removeWeight(id);
    await _reload();
  }

  Widget _exerciseCard(DayLog log, DaySettlement s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_run, color: AppTheme.amber),
                const SizedBox(width: 6),
                Text('运动 共消耗 ${s.exerciseKcal.round()} kcal',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            ...log.exercises.map((e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.exerciseName),
                  subtitle: Text('${_fmtAmount(e.minutes)} 分钟'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          '${(e.manualKcal ?? _estimateKcal(e)).round()} kcal',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.inkLight)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => _removeExercise(e.id),
                      ),
                    ],
                  ),
                )),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_circle_outline,
                  color: AppTheme.primary, size: 20),
              title: const Text('添加运动',
                  style: TextStyle(color: AppTheme.primary, fontSize: 13)),
              onTap: () => _addExercise(),
            ),
          ],
        ),
      ),
    );
  }

  double _estimateKcal(ExerciseLog e) {
    final profile = context.read<AppState>().profile ?? const UserProfile();
    return (e.met ?? 5) * 3.5 * profile.weightKg / 200 * e.minutes;
  }

  Future<void> _addExercise() async {
    final ex = await showExercisePicker(context);
    if (ex == null) return;
    await context.read<AppState>().addExercise(widget.date, ex);
    await _reload();
  }

  Future<void> _removeExercise(String id) async {
    await context.read<AppState>().removeExercise(widget.date, id);
    await _reload();
  }

  void _showSettlement(DaySettlement s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            const Center(
              child: Text('今日结算',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 16),
            _detailRow('摄入热量', '${s.intakeKcal.round()} kcal', AppTheme.primary),
            _detailRow('蛋白质', '${s.intake.proteinG.toStringAsFixed(1)} g', AppTheme.ink),
            _detailRow('脂肪', '${s.intake.fatG.toStringAsFixed(1)} g', AppTheme.ink),
            _detailRow('碳水化合物', '${s.intake.carbsG.toStringAsFixed(1)} g', AppTheme.ink),
            _detailRow('钠', '${s.intake.sodiumMg.toStringAsFixed(0)} mg', AppTheme.ink),
            _detailRow('钙', '${s.intake.calciumMg.toStringAsFixed(0)} mg', AppTheme.ink),
            const Divider(),
            _detailRow('日常活动消耗', '${s.dailyActivityKcal.round()} kcal', AppTheme.blue),
            _detailRow('运动消耗', '${s.exerciseKcal.round()} kcal', AppTheme.amber),
            const Divider(),
            _detailRow('热量缺口/盈余', '${s.deficit.round()} kcal',
                s.deficit >= 0 ? AppTheme.green : AppTheme.red),
            _detailRow('理想缺口', '${s.idealDeficit.round()} kcal', AppTheme.inkLight),
            const SizedBox(height: 8),
            Center(
              child: Text(
                s.achieved ? '🎉 今日达标，继续保持！' : '今日未达标，明天继续加油 💪',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: s.achieved ? AppTheme.green : AppTheme.ink),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('$_slogan',
                  style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: AppTheme.inkLight)),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text('消耗为估算值（Mifflin-St Jeor 公式 × 活动系数 + MET 运动），仅供参考',
                  style: TextStyle(fontSize: 10, color: AppTheme.inkLight)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: AppTheme.inkLight)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 15)),
          ],
        ),
      );

  String _fmtAmount(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}
