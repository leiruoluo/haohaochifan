/// 饮食计划：按天规划餐次与条目，条目可复制进当天记录
library;

import 'dart:convert';

class PlanItem {
  final String id;
  final String refId; // foodId 或 dishId
  final bool isDish;
  final String name; // 冗余显示名（防引用删除后不可读）
  final double amount; // 数量
  final String unitName; // 克/毫升/份/自定义单位

  const PlanItem({
    required this.id,
    required this.refId,
    required this.isDish,
    required this.name,
    required this.amount,
    required this.unitName,
  });

  PlanItem copyWith({
    String? id,
    String? refId,
    bool? isDish,
    String? name,
    double? amount,
    String? unitName,
  }) =>
      PlanItem(
        id: id ?? this.id,
        refId: refId ?? this.refId,
        isDish: isDish ?? this.isDish,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        unitName: unitName ?? this.unitName,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'ref_id': refId,
        'is_dish': isDish ? 1 : 0,
        'name': name,
        'amount': amount,
        'unit': unitName,
      };

  factory PlanItem.fromMap(Map<String, Object?> m) => PlanItem(
        id: m['id'] as String,
        refId: m['ref_id'] as String,
        isDish: (m['is_dish'] as num? ?? 0) != 0,
        name: (m['name'] as String?) ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        unitName: (m['unit'] as String?) ?? '克',
      );
}

class PlanMeal {
  final String id;
  final String mealName; // 早餐/午餐/晚餐/加餐/自定义
  final List<PlanItem> items;

  const PlanMeal({
    required this.id,
    required this.mealName,
    this.items = const [],
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'meal_name': mealName,
        'items_json': jsonEncode(items.map((i) => i.toMap()).toList()),
      };

  factory PlanMeal.fromMap(Map<String, Object?> m) {
    final items = (m['items_json'] as String?) ?? '[]';
    final itemsDecoded = jsonDecode(items) as List;
    return PlanMeal(
      id: m['id'] as String,
      mealName: (m['meal_name'] as String?) ?? '加餐',
      items: itemsDecoded
          .map((i) => PlanItem.fromMap((i as Map).cast<String, Object?>()))
          .toList(),
    );
  }
}

/// 计划日：可绑定到具体日期，或作为模板
class PlanDay {
  final String id;
  final String name; // 计划名，如"工作日减脂模板"
  final DateTime? date; // null 表示模板，可复制使用
  final List<PlanMeal> meals;
  final DateTime? updatedAt;
  final bool deleted;

  const PlanDay({
    required this.id,
    required this.name,
    this.date,
    this.meals = const [],
    this.updatedAt,
    this.deleted = false,
  });

  PlanDay copyWith({
    String? name,
    DateTime? date,
    List<PlanMeal>? meals,
    bool? deleted,
    DateTime? updatedAt,
  }) =>
      PlanDay(
        id: id,
        name: name ?? this.name,
        date: date ?? this.date,
        meals: meals ?? this.meals,
        deleted: deleted ?? this.deleted,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'date': date?.millisecondsSinceEpoch,
        'deleted': deleted ? 1 : 0,
        'updated_at': updatedAt?.millisecondsSinceEpoch ?? 0,
        'meals_json': jsonEncode(meals.map((m) => m.toMap()).toList()),
      };

  factory PlanDay.fromMap(Map<String, Object?> m) {
    final meals = (m['meals_json'] as String?) ?? '[]';
    final mealsDecoded = jsonDecode(meals) as List;
    final dateMs = m['date'] as num?;
    return PlanDay(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? '',
      date: dateMs != null ? DateTime.fromMillisecondsSinceEpoch(dateMs.toInt()) : null,
      deleted: (m['deleted'] as num? ?? 0) != 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updated_at'] as num?)?.toInt() ?? 0),
      meals: mealsDecoded
          .map((x) => PlanMeal.fromMap((x as Map).cast<String, Object?>()))
          .toList(),
    );
  }
}
