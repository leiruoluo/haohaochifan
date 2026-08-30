/// 组合菜肴：多食材按份量合成，营养自动汇总
library;

import 'dart:convert';

import 'food.dart';

class DishIngredient {
  final String foodId;
  final double grams; // 一份中该食材的用量（克/毫升）
  const DishIngredient(this.foodId, this.grams);

  Map<String, Object?> toMap() => {'food_id': foodId, 'grams': grams};

  factory DishIngredient.fromMap(Map<String, Object?> m) => DishIngredient(
        m['food_id'] as String,
        (m['grams'] as num).toDouble(),
      );
}

class Dish {
  final String id;
  final String name;
  final List<DishIngredient> ingredients;
  final String note; // 做法/备注（可选）
  final bool builtin;
  final bool deleted;
  final DateTime? updatedAt;

  const Dish({
    required this.id,
    required this.name,
    this.ingredients = const [],
    this.note = '',
    this.builtin = false,
    this.deleted = false,
    this.updatedAt,
  });

  Dish copyWith({
    String? name,
    List<DishIngredient>? ingredients,
    String? note,
    bool? deleted,
    DateTime? updatedAt,
  }) {
    return Dish(
      id: id,
      name: name ?? this.name,
      ingredients: ingredients ?? this.ingredients,
      note: note ?? this.note,
      builtin: builtin,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 依据食材库实时计算一份的营养（食材缺失时按 0 计）
  Nutrition computeNutrition(Map<String, Food> foodById) {
    var total = const Nutrition();
    for (final ing in ingredients) {
      final f = foodById[ing.foodId];
      if (f == null) continue;
      total = total + f.per100 * (ing.grams / 100);
    }
    return total;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'note': note,
        'builtin': builtin ? 1 : 0,
        'deleted': deleted ? 1 : 0,
        'updated_at': updatedAt?.millisecondsSinceEpoch ?? 0,
        'ingredients_json':
            jsonEncode(ingredients.map((i) => i.toMap()).toList()),
      };

  factory Dish.fromMap(Map<String, Object?> m) {
    final ings = (m['ingredients_json'] as String?) ?? '[]';
    final ingsDecoded = jsonDecode(ings) as List;
    return Dish(
      id: m['id'] as String,
      name: m['name'] as String,
      note: (m['note'] as String?) ?? '',
      builtin: (m['builtin'] as num? ?? 0) != 0,
      deleted: (m['deleted'] as num? ?? 0) != 0,
      ingredients: ingsDecoded
          .map((i) => DishIngredient.fromMap((i as Map).cast<String, Object?>()))
          .toList(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updated_at'] as num?)?.toInt() ?? 0),
    );
  }
}
