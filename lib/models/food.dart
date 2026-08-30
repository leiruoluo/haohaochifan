/// 营养结构与食物模型（热量数据库核心）
library;

import 'dart:convert';

/// 每 100g / 100ml 的营养成分
class Nutrition {
  final double energyKcal;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final double sodiumMg;
  final double calciumMg;
  final double fiberG;
  final double sugarG;

  const Nutrition({
    this.energyKcal = 0,
    this.proteinG = 0,
    this.fatG = 0,
    this.carbsG = 0,
    this.sodiumMg = 0,
    this.calciumMg = 0,
    this.fiberG = 0,
    this.sugarG = 0,
  });

  Nutrition operator *(double factor) => Nutrition(
        energyKcal: energyKcal * factor,
        proteinG: proteinG * factor,
        fatG: fatG * factor,
        carbsG: carbsG * factor,
        sodiumMg: sodiumMg * factor,
        calciumMg: calciumMg * factor,
        fiberG: fiberG * factor,
        sugarG: sugarG * factor,
      );

  Nutrition operator +(Nutrition o) => Nutrition(
        energyKcal: energyKcal + o.energyKcal,
        proteinG: proteinG + o.proteinG,
        fatG: fatG + o.fatG,
        carbsG: carbsG + o.carbsG,
        sodiumMg: sodiumMg + o.sodiumMg,
        calciumMg: calciumMg + o.calciumMg,
        fiberG: fiberG + o.fiberG,
        sugarG: sugarG + o.sugarG,
      );

  Map<String, Object?> toMap() => {
        'energy': energyKcal,
        'protein': proteinG,
        'fat': fatG,
        'carbs': carbsG,
        'sodium': sodiumMg,
        'calcium': calciumMg,
        'fiber': fiberG,
        'sugar': sugarG,
      };

  factory Nutrition.fromMap(Map<String, Object?> m) => Nutrition(
        energyKcal: (m['energy'] as num?)?.toDouble() ?? 0,
        proteinG: (m['protein'] as num?)?.toDouble() ?? 0,
        fatG: (m['fat'] as num?)?.toDouble() ?? 0,
        carbsG: (m['carbs'] as num?)?.toDouble() ?? 0,
        sodiumMg: (m['sodium'] as num?)?.toDouble() ?? 0,
        calciumMg: (m['calcium'] as num?)?.toDouble() ?? 0,
        fiberG: (m['fiber'] as num?)?.toDouble() ?? 0,
        sugarG: (m['sugar'] as num?)?.toDouble() ?? 0,
      );

  /// 三大营养素供能占比（%）
  List<double> macroRatio() {
    final p = proteinG * 4, f = fatG * 9, c = carbsG * 4;
    final total = p + f + c;
    if (total <= 0) return [0, 0, 0];
    return [p / total * 100, f / total * 100, c / total * 100];
  }

  @override
  String toString() =>
      'Nutrition(${energyKcal.toStringAsFixed(0)}kcal P${proteinG.toStringAsFixed(1)} F${fatG.toStringAsFixed(1)} C${carbsG.toStringAsFixed(1)})';
}

/// 常用单位换算：如 1 碗 ≈ 200 克
class UnitDef {
  final String name;
  final double grams;
  const UnitDef(this.name, this.grams);
}

/// 食物（单一食材或商品）
class Food {
  final String id;
  final String name;
  final String category; // 主食/肉蛋/蔬菜/水果/奶制品/饮品/零食/健身/调味/其他
  final Nutrition per100;
  final bool isLiquid; // 毫升计量的饮品等
  final bool builtin;
  final bool deleted;
  final List<UnitDef> units;
  final DateTime? updatedAt;

  const Food({
    required this.id,
    required this.name,
    this.category = '其他',
    this.per100 = const Nutrition(),
    this.isLiquid = false,
    this.builtin = false,
    this.deleted = false,
    this.units = const [],
    this.updatedAt,
  });

  Food copyWith({
    String? name,
    String? category,
    Nutrition? per100,
    bool? isLiquid,
    bool? deleted,
    List<UnitDef>? units,
    DateTime? updatedAt,
  }) {
    return Food(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      per100: per100 ?? this.per100,
      isLiquid: isLiquid ?? this.isLiquid,
      builtin: builtin,
      deleted: deleted ?? this.deleted,
      units: units ?? this.units,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'is_liquid': isLiquid ? 1 : 0,
        'builtin': builtin ? 1 : 0,
        'deleted': deleted ? 1 : 0,
        'updated_at': updatedAt?.millisecondsSinceEpoch ?? 0,
        ...per100.toMap().map((k, v) => MapEntry('per_$k', v)),
        'units_json': jsonEncode(
            units.map((u) => {'name': u.name, 'grams': u.grams}).toList()),
      };

  factory Food.fromMap(Map<String, Object?> m) {
    final nut = Nutrition.fromMap({
      'energy': m['per_energy'],
      'protein': m['per_protein'],
      'fat': m['per_fat'],
      'carbs': m['per_carbs'],
      'sodium': m['per_sodium'],
      'calcium': m['per_calcium'],
      'fiber': m['per_fiber'],
      'sugar': m['per_sugar'],
    });
    final unitsJson = (m['units_json'] as String?) ?? '[]';
    final unitsDecoded = jsonDecode(unitsJson) as List;
    return Food(
      id: m['id'] as String,
      name: m['name'] as String,
      category: (m['category'] as String?) ?? '其他',
      per100: nut,
      isLiquid: (m['is_liquid'] as num? ?? 0) != 0,
      builtin: (m['builtin'] as num? ?? 0) != 0,
      deleted: (m['deleted'] as num? ?? 0) != 0,
      units: unitsDecoded
          .map((u) => UnitDef(
              (u as Map)['name'] as String, (u['grams'] as num).toDouble()))
          .toList(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updated_at'] as num?)?.toInt() ?? 0),
    );
  }

  /// 将"数量+单位"换算为克/毫升
  double amountToBase(double amount, String unitName) {
    if (unitName == '克' || unitName == '毫升') return amount;
    for (final u in units) {
      if (u.name == unitName) return amount * u.grams;
    }
    return amount; // 未知单位按克计
  }
}
