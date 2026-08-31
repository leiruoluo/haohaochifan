import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../engine/settlement.dart';
import '../engine/slogan.dart';
import '../models/exercise.dart' show WeightRecord;
import '../models/food.dart';
import '../models/log.dart';
import '../models/plan.dart';
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
  List<PlanDay> _plans = [];
  final TextEditingController _waterCtrl = TextEditingController();
  final FocusNode _waterFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _waterCtrl.dispose();
    _waterFocus.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final state = context.read<AppState>();
    final log = await state.dayLog(widget.date);
    final s = await state.settlement(widget.date);
    final profile = state.profile ?? const UserProfile();
    final weight = await state.weightForDate(widget.date);
    final plans = await state.plansForDate(widget.date);
    if (mounted) {
      setState(() {
        _log = log;
        _s = s;
        _weight = weight;
        _plans = plans;
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
          IconButton(
            tooltip: '复制历史记录',
            icon: const Icon(Icons.content_copy_outlined),
            onPressed: () => _copyHistory(),
          ),
          IconButton(
            tooltip: '快速记录',
            icon: const Icon(Icons.bolt_outlined),
            onPressed: () => _quickRecord(),
          ),
          TextButton.icon(
            onPressed: () => _showSettlement(s),
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('结算'),
          ),
        ],
      ),
      body: GestureDetector(
        // 点击空白处收起键盘（输入框与键盘焦点同步）
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
          children: [
            _sloganBar(),
            _summaryCard(s),
            _waterCard(log, s),
            _weightCard(log),
            ..._planCards(),
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
              child: Text(_slogan,
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
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _waterBtn(context, log, 100),
                _waterBtn(context, log, 250),
                _waterBtn(context, log, 500),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _waterCtrl,
                    focusNode: _waterFocus,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onSubmitted: (_) => _addCustomWater(log),
                    decoration: InputDecoration(
                      hintText: '添加饮水量',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: AppTheme.blue, size: 20),
                        onPressed: () => _addCustomWater(log),
                      ),
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
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

  /// 添加自定义饮水量（在原总量上累加，并收起键盘）
  Future<void> _addCustomWater(DayLog log) async {
    final ml = double.tryParse(_waterCtrl.text);
    _waterCtrl.clear();
    _waterFocus.unfocus();
    if (ml != null && ml > 0) {
      await _setWater(log, log.waterMl + ml);
    }
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
        if (d != null) {
          kcal += d
              .nutritionFor(state.foodMap,
                  amount: e.amount, unitName: e.unitName)
              .energyKcal;
        }
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
                onTap: () => _editEntry(meal, e),
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
      return d
          .nutritionFor(state.foodMap,
              amount: e.amount, unitName: e.unitName)
          .energyKcal;
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

  /// 点按条目编辑份量
  Future<void> _editEntry(MealLog meal, LogEntry e) async {
    final ctrl = TextEditingController(text: _fmtAmount(e.amount));
    final unit = e.unitName;
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改 ${e.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: unit, isDense: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)),
              child: const Text('保存')),
        ],
      ),
    );
    if (v == null || v <= 0) return;
    final state = context.read<AppState>();
    final log = await state.dayLog(widget.date);
    final meals = log.meals
        .map((m) => m.id == meal.id
            ? MealLog(
                id: m.id,
                mealName: m.mealName,
                entries: m.entries
                    .map((x) => x.id == e.id ? x.copyWith(amount: v) : x)
                    .toList(),
              )
            : m)
        .toList();
    await state.saveDayLog(log.copyWith(meals: meals));
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
        title: Text(w == null ? '体重' : '体重 ${w.weightKg.toStringAsFixed(1)} kg'),
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

  /// 当日计划参考卡片：显示绑定到该日期的计划（独立计划，不混入当日饮食），
  /// 结算时可对比实际饮食与食谱
  List<Widget> _planCards() {
    final state = context.read<AppState>();
    return [
      for (final plan in _plans)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note_outlined,
                        size: 18, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '计划${plan.name.isEmpty ? '' : '：${plan.name}'}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      tooltip: '删除该计划',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _detachPlan(plan),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final m in plan.meals)
                  if (m.items.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${m.mealName}：${m.items.map((i) => '${i.name}×${_fmtAmount(i.amount)}${i.unitName}').join('、')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.inkLight),
                      ),
                    ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                        '计划摄入 ${planNutrition(plan, state.foodMap, state.dishMap).energyKcal.round()} kcal'
                        ' · 当天实际 ${_s?.intakeKcal.round() ?? 0} kcal',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.inkLight,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      if (_plans.isEmpty)
        Card(
          child: ListTile(
            leading:
                const Icon(Icons.event_note_outlined, color: AppTheme.primary),
            title: const Text('导入计划（独立参考，不占用当日饮食）',
                style: TextStyle(fontSize: 13)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => _importPlan(),
          ),
        ),
    ];
  }

  /// 从模板/既有计划中多选，作为独立计划绑定到当天（不填入当日饮食）
  Future<void> _importPlan() async {
    final state = context.read<AppState>();
    final candidates = state.plans
        .where((p) => !p.deleted)
        .toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('还没有计划可导入，先去"计划"页新建一个吧')));
      return;
    }
    final selected = <String>{};
    final v = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('导入计划（可多选）'),
          content: SizedBox(
            width: 360,
            height: 380,
            child: ListView(
              children: candidates.map((p) {
                final checked = selected.contains(p.id);
                return CheckboxListTile(
                  dense: true,
                  value: checked,
                  title: Text(p.name.isEmpty ? '未命名计划' : p.name),
                  subtitle: Text(
                      '${p.meals.fold<int>(0, (s, m) => s + m.items.length)} 个条目'
                      '${p.date == null ? '' : ' · 已绑定${DateFormat('M月d日').format(p.date!)}'}'),
                  onChanged: (v) => setDlg(() {
                    if (v == true) {
                      selected.add(p.id);
                    } else {
                      selected.remove(p.id);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('导入')),
          ],
        ),
      ),
    );
    if (v != true || selected.isEmpty) return;
    final chosen =
        candidates.where((p) => selected.contains(p.id)).toList();
    await state.importPlansToDate(chosen, widget.date);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已导入 ${chosen.length} 个计划到当天（独立参考，未占用当日饮食）✅')));
    await _reload();
  }

  Future<void> _detachPlan(PlanDay plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解除这个计划？'),
        content: const Text('仅解除当天绑定的计划，计划本身不会被删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
              child: const Text('解除')),
        ],
      ),
    );
    if (ok == true) {
      await context.read<AppState>().deletePlan(plan.id);
      await _reload();
    }
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
                  onTap: () => _editExercise(e),
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

  /// 点按运动条目编辑时长/消耗
  Future<void> _editExercise(ExerciseLog ex) async {
    final minCtrl = TextEditingController(text: _fmtAmount(ex.minutes));
    final manual = ex.manualKcal != null;
    final kcalCtrl = TextEditingController(
        text: ex.manualKcal?.round().toString() ?? '');
    final v = await showDialog<ExerciseLog>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('修改 ${ex.exerciseName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: '时长', suffixText: '分钟', isDense: true),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('手动输入消耗'),
                value: manual,
                onChanged: (v) => setDlg(() {}),
              ),
              if (manual)
                TextField(
                  controller: kcalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: '消耗（kcal）', isDense: true),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                ExerciseLog(
                  id: ex.id,
                  exerciseName: ex.exerciseName,
                  minutes: double.tryParse(minCtrl.text) ?? ex.minutes,
                  met: ex.met,
                  manualKcal: manual ? double.tryParse(kcalCtrl.text) : null,
                ),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (v == null) return;
    final state = context.read<AppState>();
    final log = await state.dayLog(widget.date);
    await state.saveDayLog(log.copyWith(exercises: [
      for (final x in log.exercises) x.id == v.id ? v : x,
    ]));
    await _reload();
  }

  /// 复制历史记录（支付宝账单式：按天列出，点条目复制到当天）
  Future<void> _copyHistory() async {
    final state = context.read<AppState>();
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final logs = await state.logsInRange(
        DateTime(start.year, start.month, start.day), now);
    final nonEmpty = logs
        .where((l) => l.entryCount > 0 || l.exercises.isNotEmpty)
        .toList()
        .reversed
        .toList();
    if (nonEmpty.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('近30天暂无历史记录')));
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(12),
          children: [
            const Center(
              child: Text('复制历史记录（点条目复制到今天）',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            for (final l in nonEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                child: Text('${l.date.month}月${l.date.day}日',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.inkLight)),
              ),
              for (final m in l.meals)
                for (final e in m.entries)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.content_copy,
                        size: 16, color: AppTheme.primary),
                    title: Text(e.name),
                    subtitle: Text(
                        '${m.mealName} · ${_fmtAmount(e.amount)} ${e.unitName}'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await state.addEntry(
                          widget.date, m.mealName, e.copyWith(id: genUuid()));
                      await _reload();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('已复制：${e.name}')));
                      }
                    },
                  ),
              for (final x in l.exercises)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.directions_run,
                      size: 16, color: AppTheme.amber),
                  title: Text('${x.exerciseName} ${_fmtAmount(x.minutes)}分钟'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await state.addExercise(widget.date,
                        ExerciseLog(id: genUuid(), exerciseName: x.exerciseName,
                            minutes: x.minutes, met: x.met,
                            manualKcal: x.manualKcal));
                    await _reload();
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// 快速记录：餐别+热量必填，其余选填
  Future<void> _quickRecord() async {
    var meal = '早餐';
    final kcalCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('快速记录'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('餐别', style: TextStyle(fontSize: 13)),
                Wrap(
                  spacing: 6,
                  children: ['早餐', '午餐', '晚餐', '加餐']
                      .map((m) => ChoiceChip(
                            label: Text(m),
                            selected: meal == m,
                            onSelected: (_) => setDlg(() => meal = m),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: kcalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: '热量 kcal *', isDense: true),
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: '食物名称（选填）', isDense: true),
                ),
                TextField(
                  controller: carbsCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: '碳水化合物 g（选填）', isDense: true),
                ),
                TextField(
                  controller: proteinCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: '蛋白质 g（选填）', isDense: true),
                ),
                TextField(
                  controller: fatCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: '脂肪 g（选填）', isDense: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    final kcal = double.tryParse(kcalCtrl.text);
    if (saved == true && kcal != null && kcal > 0) {
      final state = context.read<AppState>();
      final name = nameCtrl.text.trim().isEmpty ? '快速记录' : nameCtrl.text.trim();
      // 以隐藏食物的形式入库，保证营养计算链路一致
      final food = Food(
        id: genUuid(),
        name: name,
        category: '自定义',
        per100: Nutrition(
          energyKcal: kcal,
          carbsG: double.tryParse(carbsCtrl.text) ?? 0,
          proteinG: double.tryParse(proteinCtrl.text) ?? 0,
          fatG: double.tryParse(fatCtrl.text) ?? 0,
        ),
        updatedAt: DateTime.now(),
      );
      await state.upsertFood(food);
      await state.addEntry(widget.date, meal, LogEntry(
        id: genUuid(),
        refId: food.id,
        isDish: false,
        name: name,
        amount: 100,
        unitName: '克',
      ));
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已添加：$name $kcal kcal')));
      }
    }
  }

  void _showSettlement(DaySettlement s) {    showModalBottomSheet(
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
            if (_plans.isNotEmpty) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('与食谱对比',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              for (final p in _plans)
                _planCompareRow(p, s),
              _planCompareTotal(),
            ],
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

  /// 单个食谱与当天实际的对比行
  Widget _planCompareRow(PlanDay p, DaySettlement s) {
    final state = context.read<AppState>();
    final planKcal =
        planNutrition(p, state.foodMap, state.dishMap).energyKcal;
    final diff = s.intakeKcal - planKcal;
    final color = diff.abs() <= 100
        ? AppTheme.green
        : (diff > 0 ? AppTheme.red : AppTheme.amber);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
                '${p.name.isEmpty ? '计划' : p.name}\n实际 ${s.intakeKcal.round()} vs 食谱 ${planKcal.round()} kcal',
                style: const TextStyle(fontSize: 12, color: AppTheme.ink)),
          ),
          Text(
            diff > 0 ? '超 ${diff.round()} kcal' : '少 ${(-diff).round()} kcal',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: color),
          ),
        ],
      ),
    );
  }

  /// 所有食谱合计 vs 当天实际
  Widget _planCompareTotal() {
    final state = context.read<AppState>();
    final s = _s!;
    var totalPlan = 0.0;
    for (final p in _plans) {
      totalPlan +=
          planNutrition(p, state.foodMap, state.dishMap).energyKcal;
    }
    final diff = s.intakeKcal - totalPlan;
    final color = diff.abs() <= 100
        ? AppTheme.green
        : (diff > 0 ? AppTheme.red : AppTheme.amber);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
                '合计\n实际 ${s.intakeKcal.round()} vs 食谱合计 ${totalPlan.round()} kcal',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          Text(
            diff > 0 ? '超 ${diff.round()} kcal' : '少 ${(-diff).round()} kcal',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }

  String _fmtAmount(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}
