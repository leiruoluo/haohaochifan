import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/plan.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/uuid.dart';
import '../widgets/food_picker.dart';

/// 饮食计划页：模板 + 指定日期计划；条目可复制、可导入日历
class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final templates = state.plans.where((p) => p.date == null).toList();
    final dated = state.plans.where((p) => p.date != null).toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPlan,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('新建计划'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: [
          if (templates.isNotEmpty) ...[
            const _SectionTitle('模板计划'),
            ...templates.map((p) => _planTile(p)),
          ],
          if (dated.isNotEmpty) ...[
            const _SectionTitle('日期计划'),
            ...dated.map((p) => _planTile(p)),
          ],
          if (state.plans.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                    '还没有计划。\n先建一个"模板计划"（如工作日减脂），\n到日历某天点"导入计划"即可一键填好当天的记录。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.inkLight, height: 1.6)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _planTile(PlanDay p) {
    final meals = p.meals.map((m) => m.mealName).join(' · ');
    final itemCount =
        p.meals.fold<int>(0, (s, m) => s + m.items.length);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(
            backgroundColor: Color(0xFFFFE8D6),
            child: Icon(Icons.event_note, color: AppTheme.primary)),
        title: Text(p.name.isEmpty ? '未命名计划' : p.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${p.date == null ? '模板' : DateFormat('M月d日').format(p.date!)} · '
            '$itemCount 个条目${meals.isEmpty ? '' : ' · $meals'}'),
        onTap: () => _openEditor(p),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'delete') _deletePlan(p);
            if (v == 'copy') _copyToDate(p);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'copy', child: Text('复制到某天…')),
            PopupMenuItem(value: 'delete', child: Text('删除计划')),
          ],
        ),
      ),
    );
  }

  Future<void> _createPlan() async {
    final name = await _promptName('新计划名称', '如：工作日减脂模板');
    if (name == null) return;
    final p = PlanDay(
      id: genUuid(),
      name: name,
      updatedAt: DateTime.now(),
    );
    await context.read<AppState>().upsertPlan(p);
    await _openEditor(p);
  }

  Future<String?> _promptName(String title, String hint) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(
                  ctx, ctrl.text.trim().isEmpty ? null : ctrl.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
  }

  Future<void> _openEditor(PlanDay plan) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlanEditorPage(plan: plan)));
    await context.read<AppState>().reloadPlans();
  }

  Future<void> _deletePlan(PlanDay p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个计划？'),
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
    if (ok == true) {
      await context.read<AppState>().deletePlan(p.id);
    }
  }

  Future<void> _copyToDate(PlanDay p) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked == null) return;
    final state = context.read<AppState>();
    // 生成一份绑定到日期的计划（独立副本）
    final copy = PlanDay(
      id: genUuid(),
      name: p.name,
      date: picked,
      meals: p.meals,
      updatedAt: DateTime.now(),
    );
    await state.upsertPlan(copy);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已复制到 ${DateFormat('M月d日').format(picked)}')));
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.inkLight)),
      );
}

/// 计划编辑器：餐次 + 条目（复制、删除、导入当天）
class PlanEditorPage extends StatefulWidget {
  final PlanDay plan;
  const PlanEditorPage({super.key, required this.plan});

  @override
  State<PlanEditorPage> createState() => _PlanEditorPageState();
}

class _PlanEditorPageState extends State<PlanEditorPage> {
  late PlanDay _plan = widget.plan;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = _plan.name;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    await state.upsertPlan(_plan.copyWith(name: _nameCtrl.text.trim()));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
    }
  }

  Future<void> _addMeal() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('餐次名称'),
        content: Wrap(
          spacing: 8,
          children: ['早餐', '午餐', '晚餐', '加餐']
              .map((p) => ActionChip(
                    label: Text(p),
                    onPressed: () => Navigator.pop(ctx, p),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
    if (name == null) return;
    setState(() {
      _plan = _plan.copyWith(
          meals: [..._plan.meals, PlanMeal(id: genUuid(), mealName: name)]);
    });
    await _save();
  }

  Future<void> _addItem(PlanMeal meal) async {
    final entry = await showFoodPicker(context);
    if (entry == null) return;
    final items = [...meal.items];
    items.add(PlanItem(
      id: genUuid(),
      refId: entry.refId,
      isDish: entry.isDish,
      name: entry.name,
      amount: entry.amount,
      unitName: entry.unitName,
    ));
    setState(() {
      _plan = _plan.copyWith(meals: [
        for (final m in _plan.meals)
          if (m.id == meal.id) PlanMeal(id: m.id, mealName: m.mealName, items: items) else m,
      ]);
    });
    await _save();
  }

  Future<void> _copyItem(PlanMeal meal, PlanItem item) async {
    setState(() {
      _plan = _plan.copyWith(meals: [
        for (final m in _plan.meals)
          if (m.id == meal.id)
            PlanMeal(
                id: m.id,
                mealName: m.mealName,
                items: [...m.items, item.copyWith(id: genUuid())])
          else
            m,
      ]);
    });
    await _save();
  }

  Future<void> _removeItem(PlanMeal meal, PlanItem item) async {
    setState(() {
      _plan = _plan.copyWith(meals: [
        for (final m in _plan.meals)
          if (m.id == meal.id)
            PlanMeal(
                id: m.id,
                mealName: m.mealName,
                items: m.items.where((i) => i.id != item.id).toList())
          else
            m,
      ]);
    });
    await _save();
  }

  Future<void> _removeMeal(PlanMeal meal) async {
    setState(() {
      _plan = _plan.copyWith(
          meals: _plan.meals.where((m) => m.id != meal.id).toList());
    });
    await _save();
  }

  /// 导入到某天（作为独立计划绑定，不填入当日饮食）
  Future<void> _importToDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked == null) return;
    await context.read<AppState>().importPlansToDate([_plan], picked);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '已导入到 ${DateFormat('M月d日').format(picked)}（独立计划，未占用当日饮食）')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('计划编辑'),
        actions: [
          TextButton.icon(
            onPressed: _importToDay,
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('导入到某天'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: '计划名称'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Text(
              _plan.date == null
                  ? '模板计划（可复制到任意日期）'
                  : '绑定日期：${DateFormat('yyyy年M月d日').format(_plan.date!)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.inkLight)),
          const SizedBox(height: 8),
          ..._plan.meals.map((m) => _mealCard(m)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: OutlinedButton.icon(
              onPressed: _addMeal,
              icon: const Icon(Icons.add),
              label: const Text('添加餐次'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealCard(PlanMeal meal) {
    return Card(
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(meal.mealName,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _removeMeal(meal),
            ),
          ),
          ...meal.items.map((item) => ListTile(
                dense: true,
                title: Text(item.name),
                subtitle: Text(
                    '${_fmt(item.amount)} ${item.unitName}${item.isDish ? '（菜肴）' : ''}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '复制',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => _copyItem(meal, item),
                    ),
                    IconButton(
                      tooltip: '删除',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removeItem(meal, item),
                    ),
                  ],
                ),
              )),
          ListTile(
            dense: true,
            leading: const Icon(Icons.add_circle_outline,
                color: AppTheme.primary, size: 20),
            title: Text('添加到${meal.mealName}',
                style: const TextStyle(color: AppTheme.primary, fontSize: 13)),
            onTap: () => _addItem(meal),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}
