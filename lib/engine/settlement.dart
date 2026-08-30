/// 每日结算引擎：摄入聚合 + 消耗拆分 + 缺口/达标判定
/// 结算不落库，每次由最新数据实时计算（数据一变即重算，天然一致）
library;

import '../models/dish.dart';
import '../models/food.dart';
import '../models/log.dart';
import '../models/profile.dart';
import 'bmr.dart';

/// 一条已解析的摄入条目（含营养快照与基础计量）
class ResolvedIntake {
  final LogEntry entry;
  final Nutrition nutrition; // 该条目总营养
  final double baseAmount; // 克/毫升
  const ResolvedIntake(this.entry, this.nutrition, this.baseAmount);
}

/// 当日结算结果（全部字段由输入数据实时推导）
class DaySettlement {
  final DateTime date;
  final Nutrition intake; // 总摄入营养
  final double waterMl;
  final double dailyActivityKcal; // 日常活动消耗（含基础代谢）
  final double exerciseKcal; // 运动消耗
  final double totalExpenditure; // 总消耗
  final double deficit; // 缺口/盈余（负=缺口，正=盈余）
  final double idealDeficit; // 理想缺口
  final bool achieved; // 是否达标（±100 kcal 内）
  final double intakeKcal;
  final double waterTargetMl;
  final bool waterAchieved;
  final int entryCount;
  final int mealCount;
  final List<ResolvedIntake> resolvedEntries;
  final List<ExerciseLog> exercises;

  DaySettlement({
    required this.date,
    required this.intake,
    required this.waterMl,
    required this.dailyActivityKcal,
    required this.exerciseKcal,
    required this.deficit,
    required this.idealDeficit,
    required this.achieved,
    required this.waterTargetMl,
    required this.waterAchieved,
    required this.entryCount,
    required this.mealCount,
    required this.resolvedEntries,
    required this.exercises,
  })  : intakeKcal = intake.energyKcal,
        totalExpenditure = dailyActivityKcal + exerciseKcal;

  /// 距离目标的偏差（实际缺口 - 理想缺口，正=缺口不足，负=缺口过大）
  double get gapFromIdeal => deficit - idealDeficit;

  /// 达标容差（±100 kcal）
  static const tolerance = 100.0;

  bool get hasData => entryCount > 0 || exercises.isNotEmpty || waterMl > 0;
}

/// 计算某天的结算结果
DaySettlement settleDay({
  required DayLog log,
  required Map<String, Food> foods,
  required Map<String, Dish> dishes,
  required UserProfile profile,
}) {
  var total = const Nutrition();
  final resolved = <ResolvedIntake>[];
  var entryCount = 0;

  for (final meal in log.meals) {
    for (final e in meal.entries) {
      Nutrition nut = const Nutrition();
      double base = e.amount;
      if (e.isDish) {
        final d = dishes[e.refId];
        if (d != null) {
          // 菜肴按"份"计：一份=配料定义的总量
          nut = d.computeNutrition(foods) * e.amount;
          base = e.amount; // 份数
        }
      } else {
        final f = foods[e.refId];
        if (f != null) {
          base = f.amountToBase(e.amount, e.unitName);
          nut = f.per100 * (base / 100);
        }
      }
      if (nut.energyKcal > 0 || nut.proteinG > 0 || base > 0) {
        resolved.add(ResolvedIntake(e, nut, base));
        total = total + nut;
        entryCount++;
      }
    }
  }

  double exerciseKcal = 0;
  for (final ex in log.exercises) {
    exerciseKcal += ex.manualKcal ?? (ex.met ?? 5) * 3.5 * profile.weightKg / 200 * ex.minutes;
  }

  final activity = dailyActivityKcal(profile);
  final deficit = total.energyKcal - (activity + exerciseKcal);
  final ideal = profile.effectiveIdealDeficit;
  final achieved = (deficit - ideal).abs() <= DaySettlement.tolerance;

  return DaySettlement(
    date: log.date,
    intake: total,
    waterMl: log.waterMl,
    dailyActivityKcal: activity,
    exerciseKcal: exerciseKcal,
    deficit: deficit,
    idealDeficit: ideal,
    achieved: achieved,
    waterTargetMl: profile.waterTargetMl,
    waterAchieved: log.waterMl >= profile.waterTargetMl,
    entryCount: entryCount,
    mealCount: log.meals.length,
    resolvedEntries: resolved,
    exercises: log.exercises,
  );
}
