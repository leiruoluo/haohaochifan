import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/food.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/uuid.dart';

/// 食物编辑页：新增或编辑食物（每100g/ml 营养 + 常用单位换算）
class FoodEditPage extends StatefulWidget {
  final Food? food;
  const FoodEditPage({super.key, this.food});

  @override
  State<FoodEditPage> createState() => _FoodEditPageState();
}

class _FoodEditPageState extends State<FoodEditPage> {
  late final TextEditingController _name;
  late String _category;
  late bool _liquid;
  late final _nut = _NutCtrl();
  late final List<_UnitRow> _units;

  bool get _isEdit => widget.food != null;

  @override
  void initState() {
    super.initState();
    final f = widget.food;
    _name = TextEditingController(text: f?.name ?? '');
    _category = f?.category ?? '主食';
    _liquid = f?.isLiquid ?? false;
    _nut.set(f?.per100 ?? const Nutrition());
    _units = [
      for (final u in (f?.units ?? const <UnitDef>[]))
        _UnitRow(u.name, u.grams),
    ];
  }

  @override
  void dispose() {
    _name.dispose();
    _nut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑食物' : '添加食物'),
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
            decoration: const InputDecoration(labelText: '食物名称 *'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final c in _categories)
                ChoiceChip(
                  label: Text(c),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('按毫升计量（饮品等）'),
            value: _liquid,
            onChanged: (v) => setState(() => _liquid = v),
          ),
          const SizedBox(height: 8),
          const Text('每 100 克/毫升营养成分',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _nutField('能量（kcal）', _nut.energy),
          _nutField('蛋白质（g）', _nut.protein),
          _nutField('脂肪（g）', _nut.fat),
          _nutField('碳水化合物（g）', _nut.carbs),
          _nutField('钠（mg）', _nut.sodium),
          _nutField('钙（mg）', _nut.calcium),
          _nutField('膳食纤维（g，可选）', _nut.fiber),
          _nutField('糖（g，可选）', _nut.sugar),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('常用单位换算',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _units.add(_UnitRow('个', 100))),
                icon: const Icon(Icons.add_circle_outline),
                tooltip: '添加单位',
              ),
            ],
          ),
          ..._units.asMap().entries.map((e) => Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: e.value.nameCtrl,
                      decoration: const InputDecoration(
                          hintText: '单位名（个/碗/杯…）', isDense: true),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('≈'),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: e.value.gramsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          hintText: '克数', isDense: true, suffixText: 'g'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _units.removeAt(e.key)),
                  ),
                ],
              )),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  static const _categories = [
    '主食', '肉蛋', '蔬菜', '水果', '奶制品', '饮品', '零食', '健身', '调味', '其他'
  ];

  Widget _nutField(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, isDense: true),
        ),
      );

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写食物名称')));
      return;
    }
    final food = Food(
      id: widget.food?.id ?? genUuid(),
      name: name,
      category: _category,
      isLiquid: _liquid,
      builtin: widget.food?.builtin ?? false,
      per100: _nut.build(),
      units: [
        for (final u in _units)
          if (u.nameCtrl.text.trim().isNotEmpty &&
              (double.tryParse(u.gramsCtrl.text) ?? 0) > 0)
            UnitDef(u.nameCtrl.text.trim(),
                double.tryParse(u.gramsCtrl.text) ?? 0),
      ],
      updatedAt: DateTime.now(),
    );
    await context.read<AppState>().upsertFood(food);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个食物？'),
        content: const Text('历史记录中已录入的条目不受影响。'),
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
      await context.read<AppState>().deleteFood(widget.food!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}

class _NutCtrl {
  final energy = TextEditingController();
  final protein = TextEditingController();
  final fat = TextEditingController();
  final carbs = TextEditingController();
  final sodium = TextEditingController();
  final calcium = TextEditingController();
  final fiber = TextEditingController();
  final sugar = TextEditingController();

  void set(Nutrition n) {
    energy.text = _f(n.energyKcal);
    protein.text = _f(n.proteinG);
    fat.text = _f(n.fatG);
    carbs.text = _f(n.carbsG);
    sodium.text = _f(n.sodiumMg);
    calcium.text = _f(n.calciumMg);
    fiber.text = _f(n.fiberG);
    sugar.text = _f(n.sugarG);
  }

  Nutrition build() => Nutrition(
        energyKcal: _p(energy),
        proteinG: _p(protein),
        fatG: _p(fat),
        carbsG: _p(carbs),
        sodiumMg: _p(sodium),
        calciumMg: _p(calcium),
        fiberG: _p(fiber),
        sugarG: _p(sugar),
      );

  double _p(TextEditingController c) => double.tryParse(c.text) ?? 0;
  String _f(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  void dispose() {
    for (final c in [energy, protein, fat, carbs, sodium, calcium, fiber, sugar]) {
      c.dispose();
    }
  }
}

class _UnitRow {
  final nameCtrl = TextEditingController();
  final gramsCtrl = TextEditingController();
  _UnitRow(String name, double grams) {
    nameCtrl.text = name;
    gramsCtrl.text = grams.toString();
  }
}
