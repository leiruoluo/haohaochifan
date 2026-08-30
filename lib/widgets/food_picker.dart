import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dish.dart';
import '../models/food.dart';
import '../models/log.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/uuid.dart';

/// 弹出选择食物/菜肴并填写份量，返回 LogEntry（取消返回 null）
Future<LogEntry?> showFoodPicker(BuildContext context) async {
  final result = await showModalBottomSheet<LogEntry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.cream,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _FoodPickerSheet(),
  );
  return result;
}

class _FoodPickerSheet extends StatefulWidget {
  const _FoodPickerSheet();
  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {
  String _query = '';
  String _category = '全部';
  static const _categories = [
    '全部', '主食', '肉蛋', '蔬菜', '水果', '奶制品', '饮品', '零食', '健身', '调味', '菜肴', '其他'
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final foods = state.foods.where((f) {
      if (f.deleted) return false;
      if (_category != '全部' && f.category != _category) return false;
      if (_query.isNotEmpty && !f.name.contains(_query)) return false;
      return true;
    }).toList();
    final dishes = state.dishes.where((d) {
      if (d.deleted) return false;
      if (_category != '全部' && _category != '菜肴') return false;
      if (_query.isNotEmpty && !d.name.contains(_query)) return false;
      return true;
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('添加食物 / 菜肴',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: const InputDecoration(
                  hintText: '搜索食物名称…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: _categories
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(c),
                            selected: _category == c,
                            onSelected: (_) => setState(() => _category = c),
                          ),
                        ))
                    .toList(),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                children: [
                  if (dishes.isNotEmpty) ...[
                    const _GroupLabel('菜肴'),
                    ...dishes.map((d) => _dishTile(state, d)),
                  ],
                  if (foods.isNotEmpty) ...[
                    const _GroupLabel('食物'),
                    ...foods.map((f) => _foodTile(state, f)),
                  ],
                  if (foods.isEmpty && dishes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                          child: Text('没有匹配的食物，去"菜谱"添加吧',
                              style: TextStyle(color: AppTheme.inkLight))),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dishTile(AppState state, Dish d) {
    final nut = d.computeNutrition(state.foodMap);
    return ListTile(
      leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFE8D6), child: Text('🍲', style: TextStyle(fontSize: 18))),
      title: Text(d.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('每份 ${nut.energyKcal.round()} kcal · ${d.ingredients.length} 种食材'),
      onTap: () => _pickAmount(
        name: d.name,
        isDish: true,
        refId: d.id,
        perUnit: nut,
        unitOptions: const ['份'],
        defaultUnit: '份',
        unitGrams: const {},
      ),
    );
  }

  Widget _foodTile(AppState state, Food f) {
    final unit = f.isLiquid ? '毫升' : '克';
    return ListTile(
      leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
          child: Text(f.category.characters.first,
              style: const TextStyle(fontSize: 13, color: AppTheme.primary))),
      title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('每100${f.isLiquid ? 'ml' : 'g'} ${f.per100.energyKcal.round()} kcal · 蛋白质${f.per100.proteinG.toStringAsFixed(1)}g'),
      onTap: () => _pickAmount(
        name: f.name,
        isDish: false,
        refId: f.id,
        perUnit: f.per100,
        unitOptions: [unit, ...f.units.map((u) => u.name)],
        defaultUnit: unit,
        liquid: f.isLiquid,
        unitGrams: {for (final u in f.units) u.name: u.grams},
      ),
    );
  }

  Future<void> _pickAmount({
    required String name,
    required bool isDish,
    required String refId,
    required Nutrition perUnit,
    required List<String> unitOptions,
    required String defaultUnit,
    bool liquid = false,
    Map<String, double> unitGrams = const {},
  }) async {
    final entry = await showModalBottomSheet<LogEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AmountSheet(
        name: name,
        isDish: isDish,
        refId: refId,
        perUnit: perUnit,
        unitOptions: unitOptions,
        defaultUnit: defaultUnit,
        liquid: liquid,
        unitGrams: unitGrams,
      ),
    );
    if (entry != null && mounted) Navigator.of(context).pop(entry);
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.inkLight)),
      );
}

class _AmountSheet extends StatefulWidget {
  final String name;
  final bool isDish;
  final String refId;
  final Nutrition perUnit;
  final List<String> unitOptions;
  final String defaultUnit;
  final bool liquid;
  final Map<String, double> unitGrams;

  const _AmountSheet({
    required this.name,
    required this.isDish,
    required this.refId,
    required this.perUnit,
    required this.unitOptions,
    required this.defaultUnit,
    required this.liquid,
    required this.unitGrams,
  });

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late String _unit;
  double _amount = 100;

  @override
  void initState() {
    super.initState();
    _unit = widget.defaultUnit;
    _amount = widget.isDish ? 1 : 100;
  }

  /// 换算为基础计量（克/毫升），菜肴按份数
  double get _baseAmount {
    if (widget.isDish) return _amount;
    if (_unit == '克' || _unit == '毫升') return _amount;
    final g = widget.unitGrams[_unit];
    if (g != null) return _amount * g;
    return _amount; // 未知单位按克兜底
  }

  double get _kcal {
    if (widget.isDish) return widget.perUnit.energyKcal * _amount;
    return widget.perUnit.energyKcal * _baseAmount / 100;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              '每100${widget.liquid ? 'ml' : 'g'} ${widget.perUnit.energyKcal.round()} kcal'
              ' · 蛋白${widget.perUnit.proteinG.toStringAsFixed(1)}g'
              ' · 碳水${widget.perUnit.carbsG.toStringAsFixed(1)}g'
              ' · 脂肪${widget.perUnit.fatG.toStringAsFixed(1)}g',
              style: const TextStyle(fontSize: 12, color: AppTheme.inkLight)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: () => setState(() =>
                      _amount = (_amount - _step).clamp(0, 9999)),
                  icon: const Icon(Icons.remove_circle_outline, size: 28)),
              SizedBox(
                width: 120,
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  controller: TextEditingController(text: _fmt(_amount)),
                  onChanged: (s) =>
                      setState(() => _amount = double.tryParse(s) ?? 0),
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
              IconButton(
                  onPressed: () => setState(() =>
                      _amount = (_amount + _step).clamp(0, 9999)),
                  icon: const Icon(Icons.add_circle_outline, size: 28)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.unitOptions
                .map((u) => ChoiceChip(
                      label: Text(u),
                      selected: _unit == u,
                      onSelected: (_) => setState(() => _unit = u),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Text('≈ ${_kcal.round()} kcal',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(LogEntry(
                  id: genUuid(),
                  refId: widget.refId,
                  isDish: widget.isDish,
                  name: widget.name,
                  amount: _amount,
                  unitName: _unit,
                )),
                child: const Text('确认添加'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _step => widget.isDish ? 1 : 10;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}
