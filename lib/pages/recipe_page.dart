import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dish.dart';
import '../models/food.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'dish_edit_page.dart';
import 'food_edit_page.dart';

/// 菜谱库：系统内置 + 用户自定义食物/菜肴
class RecipePage extends StatefulWidget {
  const RecipePage({super.key});

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> {
  bool _dishesTab = false;
  String _query = '';
  String _category = '全部';
  static const _categories = [
    '全部', '主食', '肉蛋', '蔬菜', '水果', '奶制品', '饮品', '零食', '健身', '调味', '其他'
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
      if (_query.isNotEmpty && !d.name.contains(_query)) return false;
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('食物')),
                  ButtonSegment(value: true, label: Text('菜肴')),
                ],
                selected: {_dishesTab},
                onSelectionChanged: (s) => setState(() => _dishesTab = s.first),
                showSelectedIcon: false,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _add(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(_dishesTab ? '菜肴' : '食物'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: const InputDecoration(
              hintText: '搜索…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        if (!_dishesTab)
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
          child: _dishesTab ? _dishList(state, dishes) : _foodList(state, foods),
        ),
      ],
    );
  }

  void _add(BuildContext context) {
    if (_dishesTab) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const DishEditPage()));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const FoodEditPage()));
    }
  }

  Widget _foodList(AppState state, List<Food> list) {
    if (list.isEmpty) {
      return const Center(
          child: Text('暂无食物，点右上角添加',
              style: TextStyle(color: AppTheme.inkLight)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final f = list[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              child: Text(f.category.characters.first,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.primary)),
            ),
            title: Row(
              children: [
                Flexible(
                    child: Text(f.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                if (f.builtin)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Text('内置',
                        style: TextStyle(
                            fontSize: 10, color: AppTheme.inkLight)),
                  ),
              ],
            ),
            subtitle: Text(
                '每100${f.isLiquid ? 'ml' : 'g'}：${f.per100.energyKcal.round()} kcal'
                ' · 蛋白${f.per100.proteinG.toStringAsFixed(1)}g'
                ' · 脂肪${f.per100.fatG.toStringAsFixed(1)}g'
                ' · 碳水${f.per100.carbsG.toStringAsFixed(1)}g'
                ' · 钠${f.per100.sodiumMg.round()}mg'
                ' · 钙${f.per100.calciumMg.round()}mg'),
            onTap: () => _editFood(f),
          ),
        );
      },
    );
  }

  Widget _dishList(AppState state, List<Dish> list) {
    if (list.isEmpty) {
      return const Center(
          child: Text('暂无菜肴，点右上角添加',
              style: TextStyle(color: AppTheme.inkLight)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final d = list[i];
        final nut = d.computeNutrition(state.foodMap);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFE8D6),
                child: Text('🍲', style: TextStyle(fontSize: 16))),
            title: Row(
              children: [
                Flexible(
                    child: Text(d.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                if (d.builtin)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Text('内置',
                        style: TextStyle(
                            fontSize: 10, color: AppTheme.inkLight)),
                  ),
              ],
            ),
            subtitle: Text(
                '每份 ${nut.energyKcal.round()} kcal · ${d.ingredients.length} 种食材'
                ' · 蛋白${nut.proteinG.toStringAsFixed(1)}g'
                ' · 脂肪${nut.fatG.toStringAsFixed(1)}g'
                ' · 碳水${nut.carbsG.toStringAsFixed(1)}g'),
            onTap: () => _editDish(d),
          ),
        );
      },
    );
  }

  Future<void> _editFood(Food f) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FoodEditPage(food: f)));
  }

  Future<void> _editDish(Dish d) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DishEditPage(dish: d)));
  }
}
