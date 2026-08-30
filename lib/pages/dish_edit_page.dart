import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dish.dart';
import '../models/food.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/uuid.dart';

/// 菜肴编辑页：名称 + 食材列表（每种食材用量）
class DishEditPage extends StatefulWidget {
  final Dish? dish;
  const DishEditPage({super.key, this.dish});

  @override
  State<DishEditPage> createState() => _DishEditPageState();
}

class _DishEditPageState extends State<DishEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _note;
  late final List<_IngRow> _ings;

  bool get _isEdit => widget.dish != null;

  @override
  void initState() {
    super.initState();
    final d = widget.dish;
    _name = TextEditingController(text: d?.name ?? '');
    _note = TextEditingController(text: d?.note ?? '');
    _ings = [
      for (final i in (d?.ingredients ?? const <DishIngredient>[]))
        _IngRow(i.foodId, i.grams),
    ];
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final foodMap = state.foodMap;
    var kcal = 0.0;
    for (final r in _ings) {
      final f = foodMap[r.foodId];
      if (f != null) kcal += f.per100.energyKcal * r.grams / 100;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑菜肴' : '添加菜肴'),
        actions: [
          if (_isEdit)
            TextButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.red),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '菜肴名称 *')),
          const SizedBox(height: 8),
          TextField(
              controller: _note,
              decoration:
                  const InputDecoration(labelText: '做法备注（可选）', isDense: true)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('食材（一份的用量）',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('每份约 ${kcal.round()} kcal',
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.inkLight)),
            ],
          ),
          ..._ings.asMap().entries.map((e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(foodMap[e.value.foodId]?.name ?? '未知食材'),
                subtitle: Text('${_fmt(e.value.grams)} 克'),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _ings.removeAt(e.key)),
                ),
                onTap: () => _editGrams(e.key),
              )),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_circle_outline,
                color: AppTheme.primary),
            title: const Text('添加食材',
                style: TextStyle(color: AppTheme.primary, fontSize: 13)),
            onTap: _addIngredient,
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }

  Future<void> _addIngredient() async {
    final food = await showDialog<Food>(
      context: context,
      builder: (_) => const _IngredientPickerDialog(),
    );
    if (food == null) return;
    final grams = await _promptGrams(food, 100);
    if (grams == null) return;
    setState(() => _ings.add(_IngRow(food.id, grams)));
  }

  Future<void> _editGrams(int index) async {
    final food = context.read<AppState>().foodMap[_ings[index].foodId];
    if (food == null) return;
    final grams = await _promptGrams(food, _ings[index].grams);
    if (grams == null) return;
    setState(() => _ings[index] = _IngRow(food.id, grams));
  }

  Future<double?> _promptGrams(Food food, double initial) async {
    final ctrl = TextEditingController(text: _fmt(initial));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${food.name} 用量'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(suffixText: '克'),
          onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)),
              child: const Text('确定')),
        ],
      ),
    );
    return result;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写菜肴名称')));
      return;
    }
    if (_ings.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请至少添加一种食材')));
      return;
    }
    await context.read<AppState>().upsertDish(Dish(
      id: widget.dish?.id ?? genUuid(),
      name: name,
      note: _note.text.trim(),
      builtin: widget.dish?.builtin ?? false,
      ingredients: [for (final r in _ings) DishIngredient(r.foodId, r.grams)],
      updatedAt: DateTime.now(),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个菜肴？'),
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
      await context.read<AppState>().deleteDish(widget.dish!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

class _IngRow {
  final String foodId;
  double grams;
  _IngRow(this.foodId, this.grams);
}

/// 食材选择对话框（只选食物，不选菜肴）
class _IngredientPickerDialog extends StatefulWidget {
  const _IngredientPickerDialog();
  @override
  State<_IngredientPickerDialog> createState() =>
      _IngredientPickerDialogState();
}

class _IngredientPickerDialogState extends State<_IngredientPickerDialog> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.foods.where((f) {
      if (f.deleted) return false;
      if (_query.isNotEmpty && !f.name.contains(_query)) return false;
      return true;
    }).toList();
    return AlertDialog(
      title: const Text('选择食材'),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                  hintText: '搜索…', isDense: true, prefixIcon: Icon(Icons.search)),
            ),
            Expanded(
              child: ListView(
                children: list
                    .map((f) => ListTile(
                          dense: true,
                          title: Text(f.name),
                          subtitle: Text(
                              '每100g ${f.per100.energyKcal.round()} kcal'),
                          onTap: () => Navigator.pop(context, f),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
      ],
    );
  }
}
