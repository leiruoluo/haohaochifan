import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dish.dart';
import '../models/food.dart';
import '../models/log.dart';
import '../pages/dish_edit_page.dart';
import '../pages/food_edit_page.dart';
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
  List<Map<String, Object?>> _recents = [];
  bool _multi = false;
  final Set<String> _selected = {};

  static const _categories = [
    '全部', '主食', '肉蛋', '蔬菜', '水果', '奶制品', '饮品', '零食', '健身', '调味', '菜肴', '其他'
  ];

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final r = await context.read<AppState>().recents();
    if (mounted) setState(() => _recents = r);
  }

  Future<void> _deleteRecent(String refId) async {
    await context.read<AppState>().deleteRecent(refId);
    setState(() => _selected.remove(refId));
    await _loadRecents();
  }

  Future<void> _moveRecent(int index, int delta) async {
    await context.read<AppState>().moveRecent(index, delta);
    await _loadRecents();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final recencyRank = <String, int>{
      for (var i = 0; i < _recents.length; i++)
        _recents[i]['ref_id'] as String: i,
    };

    final foods = state.foods.where((f) {
      if (f.deleted) return false;
      if (_category != '全部' && f.category != _category) return false;
      if (_query.isNotEmpty && !f.name.contains(_query)) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final ra = recencyRank[a.id], rb = recencyRank[b.id];
        if (ra != null && rb != null) return ra.compareTo(rb);
        if (ra != null) return -1;
        if (rb != null) return 1;
        return a.name.compareTo(b.name);
      });

    final dishes = state.dishes.where((d) {
      if (d.deleted) return false;
      if (_category != '全部' && _category != '菜肴') return false;
      if (_query.isNotEmpty && !d.name.contains(_query)) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final ra = recencyRank[a.id], rb = recencyRank[b.id];
        if (ra != null && rb != null) return ra.compareTo(rb);
        if (ra != null) return -1;
        if (rb != null) return 1;
        return a.name.compareTo(b.name);
      });

    final recentItems = <Widget>[];
    for (final r in _recents) {
      final refId = r['ref_id'] as String;
      final isDish = (r['is_dish'] as num? ?? 0) != 0;
      if (isDish) {
        final d = state.dishMap[refId];
        if (d == null || d.deleted) continue;
        recentItems.add(_recentTile(state, d, true, recencyRank[refId] ?? 0));
      } else {
        final f = state.foodMap[refId];
        if (f == null || f.deleted) continue;
        recentItems.add(_recentTile(state, f, false, recencyRank[refId] ?? 0));
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('添加食物 / 菜肴',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: const InputDecoration(
                  hintText: '搜索食物名称…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            if (_multi)
              _multiBar()
            else
              const SizedBox(height: 4),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧分类栏（外卖点单式）
                  Container(
                    width: 78,
                    color: const Color(0xFFF5EBDF),
                    child: ListView(
                      children: _categories.map((c) {
                        final sel = _category == c;
                        return InkWell(
                          onTap: () => setState(() => _category = c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 13, horizontal: 6),
                            color: sel ? Colors.white : Colors.transparent,
                            child: Text(c,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: sel
                                        ? FontWeight.w800
                                        : FontWeight.w400,
                                    color: sel
                                        ? AppTheme.primary
                                        : AppTheme.ink)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // 右侧内容
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
                        children: [
                          if (recentItems.isNotEmpty &&
                              _query.isEmpty &&
                              _category == '全部') ...[
                            const _GroupLabel('最近吃过'),
                            ...recentItems,
                            const Divider(),
                          ],
                          if (dishes.isNotEmpty) ...[
                            const _GroupLabel('菜肴'),
                            ...dishes.map((d) => _dishTile(state, d)),
                          ],
                          if (foods.isNotEmpty) ...[
                            const _GroupLabel('食物'),
                            ...foods.map((f) => _foodTile(state, f)),
                          ],
                          if (foods.isEmpty && dishes.isEmpty &&
                              recentItems.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                  child: Text('没有匹配的食物，去"菜谱"添加吧',
                                      style:
                                          TextStyle(color: AppTheme.inkLight))),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 多选操作栏（删除/上移/下移/取消）
  Widget _multiBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () async {
              for (final id in _selected.toList()) {
                await _deleteRecent(id);
              }
              setState(() => _multi = false);
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('删除'),
          ),
          IconButton(
            tooltip: '上移',
            onPressed: _selected.length == 1 ? () => _moveSelected(-1) : null,
            icon: const Icon(Icons.arrow_upward, size: 20),
          ),
          IconButton(
            tooltip: '下移',
            onPressed: _selected.length == 1 ? () => _moveSelected(1) : null,
            icon: const Icon(Icons.arrow_downward, size: 20),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() {
              _multi = false;
              _selected.clear();
            }),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _moveSelected(int delta) async {
    final idx =
        _recents.indexWhere((r) => r['ref_id'] == _selected.first);
    if (idx < 0) return;
    await _moveRecent(idx, delta);
    setState(() => _multi = false);
    _selected.clear();
  }

  /// 最近吃过条目（左滑删除、长按多选）
  Widget _recentTile(AppState state, Object item, bool isDish, int rank) {
    final refId = isDish ? (item as Dish).id : (item as Food).id;
    final name = isDish ? (item as Dish).name : (item as Food).name;
    final sel = _selected.contains(refId);
    return Dismissible(
      key: ValueKey('recent_$refId'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _deleteRecent(refId);
        return false;
      },
      background: Container(
        color: AppTheme.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 4, right: 8),
        leading: _multi
            ? Icon(sel ? Icons.check_circle : Icons.circle_outlined,
                color: sel ? AppTheme.primary : AppTheme.inkLight)
            : CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFFFE8D6),
                child: Text(isDish ? '🍲' : '🕘',
                    style: const TextStyle(fontSize: 14)),
              ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('最近吃过',
            style: TextStyle(fontSize: 11, color: AppTheme.inkLight)),
        onTap: () {
          if (_multi) {
            setState(() {
              if (sel) {
                _selected.remove(refId);
              } else {
                _selected.add(refId);
              }
            });
          } else {
            _pickItem(isDish, item);
          }
        },
        onLongPress: () {
          setState(() {
            _multi = true;
            _selected.add(refId);
          });
        },
      ),
    );
  }

  Widget _dishTile(AppState state, Dish d) {
    final nut = d.computeNutrition(state.foodMap);
    return Dismissible(
      key: ValueKey('dish_${d.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DishEditPage(dish: d)));
        return false;
      },
      background: Container(
        color: AppTheme.primary.withValues(alpha: 0.85),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      child: ListTile(
        leading: const CircleAvatar(
            backgroundColor: Color(0xFFFFE8D6),
            child: Text('🍲', style: TextStyle(fontSize: 18))),
        title: Text(d.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '每100g ${_per100(nut, d).energyKcal.round()} kcal · ${d.ingredients.length} 种食材'),
        onTap: () => _pickItem(true, d),
        onLongPress: () => _openDishEdit(d),
      ),
    );
  }

  Widget _foodTile(AppState state, Food f) {
    return Dismissible(
      key: ValueKey('food_${f.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => FoodEditPage(food: f)));
        return false;
      },
      background: Container(
        color: AppTheme.primary.withValues(alpha: 0.85),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            child: Text(f.category.characters.first,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.primary))),
        title: Text(f.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '每100${f.isLiquid ? 'ml' : 'g'} ${f.per100.energyKcal.round()} kcal · 蛋白质${f.per100.proteinG.toStringAsFixed(1)}g'),
        onTap: () => _pickItem(false, f),
        onLongPress: () => _openFoodEdit(f),
      ),
    );
  }

  Future<void> _openFoodEdit(Food f) async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FoodEditPage(food: f)));
  }

  Future<void> _openDishEdit(Dish d) async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DishEditPage(dish: d)));
  }

  /// 菜肴每 100g 营养
  Nutrition _per100(Nutrition total, Dish d) {
    final grams = d.ingredients.fold<double>(0, (s, i) => s + i.grams);
    if (grams <= 0) return total;
    return total * (100 / grams);
  }

  Future<void> _pickItem(bool isDish, Object item) async {
    final state = context.read<AppState>();
    final entry = await showModalBottomSheet<LogEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        if (isDish) {
          final d = item as Dish;
          final total = d.computeNutrition(state.foodMap);
          final grams = d.ingredients.fold<double>(0, (s, i) => s + i.grams);
          return _AmountSheet(
            name: d.name,
            isDish: true,
            refId: d.id,
            perUnit: _per100(total, d),
            unitOptions: const ['克', '份'],
            defaultUnit: '克',
            liquid: false,
            unitGrams: const {},
            servingTotalGrams: grams,
          );
        }
        final f = item as Food;
        final unit = f.isLiquid ? '毫升' : '克';
        return _AmountSheet(
          name: f.name,
          isDish: false,
          refId: f.id,
          perUnit: f.per100,
          unitOptions: [unit, ...f.units.map((u) => u.name)],
          defaultUnit: unit,
          liquid: f.isLiquid,
          unitGrams: {for (final u in f.units) u.name: u.grams},
        );
      },
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
  /// 菜肴一份的总克数（用于"份"换算）
  final double servingTotalGrams;

  const _AmountSheet({
    required this.name,
    required this.isDish,
    required this.refId,
    required this.perUnit,
    required this.unitOptions,
    required this.defaultUnit,
    required this.liquid,
    required this.unitGrams,
    this.servingTotalGrams = 0,
  });

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late String _unit;
  double _amount = 100;
  late final TextEditingController _ctrl = TextEditingController(text: '100');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _unit = widget.defaultUnit;
    _amount = widget.isDish && _unit == '份' ? 1 : 100;
    _ctrl.text = _fmt(_amount);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// 换算为基础计量（克/毫升）
  double get _baseAmount {
    if (_unit == '克' || _unit == '毫升') return _amount;
    final g = widget.unitGrams[_unit];
    if (g != null) return _amount * g;
    return _amount;
  }

  double get _kcal {
    if (widget.isDish && _unit == '份') {
      // 每份 = servingTotalGrams 克
      final perServing = widget.perUnit.energyKcal * widget.servingTotalGrams / 100;
      return perServing * _amount;
    }
    return widget.perUnit.energyKcal * _baseAmount / 100;
  }

  void _setAmount(double v) {
    setState(() => _amount = v.clamp(0, 99999).toDouble());
    _ctrl.text = _fmt(_amount);
    _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length));
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
                  onPressed: () => _setAmount(_amount - _step),
                  icon: const Icon(Icons.remove_circle_outline, size: 28)),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (s) {
                    // 光标保持在末尾，允许小数
                    _ctrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: _ctrl.text.length));
                    setState(() => _amount = double.tryParse(s) ?? 0);
                  },
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
              IconButton(
                  onPressed: () => _setAmount(_amount + _step),
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
                      onSelected: (_) => setState(() {
                        _unit = u;
                        if (u == '份') {
                          _amount = 1;
                          _ctrl.text = '1';
                        } else {
                          _amount = 100;
                          _ctrl.text = '100';
                        }
                        _ctrl.selection = TextSelection.fromPosition(
                            TextPosition(offset: _ctrl.text.length));
                      }),
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

  double get _step => (widget.isDish && _unit == '份') ? 1 : 10;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}
