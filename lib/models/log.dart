/// 每日饮食记录（日历板块的数据核心）
library;

import 'dart:convert';

import 'food.dart';

class LogEntry {
  final String id;
  final String refId; // foodId 或 dishId
  final bool isDish;
  final String name; // 冗余显示名
  final double amount; // 数量
  final String unitName; // 克/毫升/份/自定义单位

  const LogEntry({
    required this.id,
    required this.refId,
    required this.isDish,
    required this.name,
    required this.amount,
    required this.unitName,
  });

  LogEntry copyWith({
    String? id,
    String? refId,
    bool? isDish,
    String? name,
    double? amount,
    String? unitName,
  }) =>
      LogEntry(
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

  factory LogEntry.fromMap(Map<String, Object?> m) => LogEntry(
        id: m['id'] as String,
        refId: m['ref_id'] as String,
        isDish: (m['is_dish'] as num? ?? 0) != 0,
        name: (m['name'] as String?) ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        unitName: (m['unit'] as String?) ?? '克',
      );
}

class MealLog {
  final String id;
  final String mealName; // 早餐/午餐/晚餐/加餐/自定义
  final List<LogEntry> entries;

  const MealLog({
    required this.id,
    required this.mealName,
    this.entries = const [],
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'meal_name': mealName,
        'entries_json': jsonEncode(entries.map((e) => e.toMap()).toList()),
      };

  factory MealLog.fromMap(Map<String, Object?> m) {
    final entries = (m['entries_json'] as String?) ?? '[]';
    final entriesDecoded = jsonDecode(entries) as List;
    return MealLog(
      id: m['id'] as String,
      mealName: (m['meal_name'] as String?) ?? '加餐',
      entries: entriesDecoded
          .map((e) => LogEntry.fromMap((e as Map).cast<String, Object?>()))
          .toList(),
    );
  }
}

class ExerciseLog {
  final String id;
  final String exerciseName;
  final double minutes;
  final double? manualKcal; // 用户手动输入的消耗（可选，优先于 MET 估算）
  final double? met; // 记录时的 MET 值（快照）

  const ExerciseLog({
    required this.id,
    required this.exerciseName,
    required this.minutes,
    this.manualKcal,
    this.met,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': exerciseName,
        'minutes': minutes,
        'manual_kcal': manualKcal,
        'met': met,
      };

  factory ExerciseLog.fromMap(Map<String, Object?> m) => ExerciseLog(
        id: m['id'] as String,
        exerciseName: (m['name'] as String?) ?? '运动',
        minutes: (m['minutes'] as num?)?.toDouble() ?? 0,
        manualKcal: (m['manual_kcal'] as num?)?.toDouble(),
        met: (m['met'] as num?)?.toDouble(),
      );
}

/// 一天的完整记录（含多餐、饮水、运动）
class DayLog {
  final DateTime date; // 只取年月日
  final List<MealLog> meals;
  final double waterMl;
  final List<ExerciseLog> exercises;
  final String note; // 备注（可选）
  final DateTime? updatedAt;

  const DayLog({
    required this.date,
    this.meals = const [],
    this.waterMl = 0,
    this.exercises = const [],
    this.note = '',
    this.updatedAt,
  });

  DayLog copyWith({
    List<MealLog>? meals,
    double? waterMl,
    List<ExerciseLog>? exercises,
    String? note,
    DateTime? updatedAt,
  }) =>
      DayLog(
        date: date,
        meals: meals ?? this.meals,
        waterMl: waterMl ?? this.waterMl,
        exercises: exercises ?? this.exercises,
        note: note ?? this.note,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  int get entryCount =>
      meals.fold(0, (sum, m) => sum + m.entries.length);

  Map<String, Object?> toMap() => {
        'date': date.millisecondsSinceEpoch,
        'water_ml': waterMl,
        'note': note,
        'updated_at': updatedAt?.millisecondsSinceEpoch ?? 0,
        'meals_json': jsonEncode(meals.map((m) => m.toMap()).toList()),
        'exercises_json':
            jsonEncode(exercises.map((e) => e.toMap()).toList()),
      };

  factory DayLog.fromMap(Map<String, Object?> m) {
    final meals = (m['meals_json'] as String?) ?? '[]';
    final exs = (m['exercises_json'] as String?) ?? '[]';
    final mealsDecoded = jsonDecode(meals) as List;
    final exsDecoded = jsonDecode(exs) as List;
    return DayLog(
      date: DateTime.fromMillisecondsSinceEpoch(
          (m['date'] as num).toInt()),
      waterMl: (m['water_ml'] as num?)?.toDouble() ?? 0,
      note: (m['note'] as String?) ?? '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updated_at'] as num?)?.toInt() ?? 0),
      meals: mealsDecoded
          .map((x) => MealLog.fromMap((x as Map).cast<String, Object?>()))
          .toList(),
      exercises: exsDecoded
          .map((x) => ExerciseLog.fromMap((x as Map).cast<String, Object?>()))
          .toList(),
    );
  }
}

/// 把"食物引用 + 数量单位"解析成基础计量（克/毫升）与营养快照
class ResolvedEntry {
  final LogEntry entry;
  final Nutrition nutrition; // 该条目的总营养（已按数量换算）
  final double baseAmount; // 克/毫升

  const ResolvedEntry(this.entry, this.nutrition, this.baseAmount);
}
