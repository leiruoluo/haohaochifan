/// 基础代谢与每日总消耗估算
library;

import '../models/profile.dart';

/// Mifflin-St Jeor 基础代谢公式（kcal/天）
double bmrMifflinStJeor({
  required Gender gender,
  required int age,
  required double heightCm,
  required double weightKg,
}) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return gender == Gender.male ? base + 5 : base - 161;
}

/// 日常活动消耗 = BMR × 活动系数（含基础代谢与日常活动）
double dailyActivityKcal(UserProfile p) =>
    bmrMifflinStJeor(
      gender: p.gender,
      age: p.age,
      heightCm: p.heightCm,
      weightKg: p.weightKg,
    ) *
    p.activity.factor;

/// 目标体重对应的每日理想摄入建议（仅供参考展示）
double suggestedIntake(UserProfile p) => dailyActivityKcal(p) + p.effectiveIdealDeficit;
