/// 用户档案（用于 BMR/TDEE 计算与目标设定）
library;

enum Gender { male, female }

enum ActivityLevel {
  sedentary(1.2, '久坐（很少运动）'),
  light(1.375, '轻度（每周1-3次运动）'),
  moderate(1.55, '中度（每周3-5次运动）'),
  high(1.725, '高度（每周6-7次运动）'),
  athlete(1.9, '极高（体力劳动/每天两次训练）');

  final double factor;
  final String label;
  const ActivityLevel(this.factor, this.label);
}

enum GoalType {
  cut('减脂'),
  maintain('维持体重'),
  bulk('增肌');

  final String label;
  const GoalType(this.label);
}

class UserProfile {
  final String id;
  final Gender gender;
  final int age;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activity;
  final GoalType goal;
  /// 用户自定义的理想每日热量缺口/盈余（kcal，负数为缺口）
  final double idealDeficitKcal;
  /// 是否使用自定义理想缺口（否则按目标自动建议）
  final bool useCustomDeficit;
  /// 自定义基础代谢（kcal/天）；为空表示使用公式计算值
  final double? customBmrKcal;
  /// 是否启用自定义基础代谢
  final bool useCustomBmr;
  final double waterTargetMl;
  final String slogan;
  /// 每日自动结算提醒时间（24小时制）
  final int settleHour;
  final int settleMinute;
  final bool remindBreakfast;
  final bool remindLunch;
  final bool remindDinner;
  final bool remindWater;
  final bool remindSettle;
  final DateTime? updatedAt;

  const UserProfile({
    this.id = 'profile',
    this.gender = Gender.male,
    this.age = 25,
    this.heightCm = 170,
    this.weightKg = 65,
    this.activity = ActivityLevel.light,
    this.goal = GoalType.cut,
    this.idealDeficitKcal = -300,
    this.useCustomDeficit = true,
    this.customBmrKcal,
    this.useCustomBmr = false,
    this.waterTargetMl = 1500,
    this.slogan = '',
    this.settleHour = 23,
    this.settleMinute = 30,
    this.remindBreakfast = false,
    this.remindLunch = false,
    this.remindDinner = false,
    this.remindWater = false,
    this.remindSettle = true,
    this.updatedAt,
  });

  /// 兜底时间戳（同步合并用）
  DateTime get updatedAtOrEpoch =>
      updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// 建议的理想缺口（kcal）：减脂 -400，维持 0，增肌 +250
  double get suggestedDeficit {
    switch (goal) {
      case GoalType.cut:
        return -400;
      case GoalType.maintain:
        return 0;
      case GoalType.bulk:
        return 250;
    }
  }

  /// 生效的理想缺口：用户自定义优先，否则用建议值
  double get effectiveIdealDeficit => useCustomDeficit ? idealDeficitKcal : suggestedDeficit;

  UserProfile copyWith({
    Gender? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activity,
    GoalType? goal,
    double? idealDeficitKcal,
    bool? useCustomDeficit,
    double? customBmrKcal,
    bool? useCustomBmr,
    double? waterTargetMl,
    String? slogan,
    int? settleHour,
    int? settleMinute,
    bool? remindBreakfast,
    bool? remindLunch,
    bool? remindDinner,
    bool? remindWater,
    bool? remindSettle,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      gender: gender ?? this.gender,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      activity: activity ?? this.activity,
      goal: goal ?? this.goal,
      idealDeficitKcal: idealDeficitKcal ?? this.idealDeficitKcal,
      useCustomDeficit: useCustomDeficit ?? this.useCustomDeficit,
      customBmrKcal: customBmrKcal ?? this.customBmrKcal,
      useCustomBmr: useCustomBmr ?? this.useCustomBmr,
      waterTargetMl: waterTargetMl ?? this.waterTargetMl,
      slogan: slogan ?? this.slogan,
      settleHour: settleHour ?? this.settleHour,
      settleMinute: settleMinute ?? this.settleMinute,
      remindBreakfast: remindBreakfast ?? this.remindBreakfast,
      remindLunch: remindLunch ?? this.remindLunch,
      remindDinner: remindDinner ?? this.remindDinner,
      remindWater: remindWater ?? this.remindWater,
      remindSettle: remindSettle ?? this.remindSettle,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'gender': gender.name,
        'age': age,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'activity': activity.name,
        'goal': goal.name,
        'ideal_deficit': idealDeficitKcal,
        'use_custom_deficit': useCustomDeficit ? 1 : 0,
        'custom_bmr': customBmrKcal,
        'use_custom_bmr': useCustomBmr ? 1 : 0,
        'water_target': waterTargetMl,
        'slogan': slogan,
        'settle_hour': settleHour,
        'settle_minute': settleMinute,
        'remind_breakfast': remindBreakfast ? 1 : 0,
        'remind_lunch': remindLunch ? 1 : 0,
        'remind_dinner': remindDinner ? 1 : 0,
        'remind_water': remindWater ? 1 : 0,
        'remind_settle': remindSettle ? 1 : 0,
        'updated_at': updatedAtOrEpoch.millisecondsSinceEpoch,
      };

  factory UserProfile.fromMap(Map<String, Object?> m) => UserProfile(
        gender: Gender.values.firstWhere((e) => e.name == m['gender'],
            orElse: () => Gender.male),
        age: (m['age'] as num?)?.toInt() ?? 25,
        heightCm: (m['height_cm'] as num?)?.toDouble() ?? 170,
        weightKg: (m['weight_kg'] as num?)?.toDouble() ?? 65,
        activity: ActivityLevel.values.firstWhere((e) => e.name == m['activity'],
            orElse: () => ActivityLevel.light),
        goal: GoalType.values.firstWhere((e) => e.name == m['goal'],
            orElse: () => GoalType.cut),
        idealDeficitKcal: (m['ideal_deficit'] as num?)?.toDouble() ?? -300,
        useCustomDeficit: (m['use_custom_deficit'] as num? ?? 1) != 0,
        customBmrKcal: (m['custom_bmr'] as num?)?.toDouble(),
        useCustomBmr: (m['use_custom_bmr'] as num? ?? 0) != 0,
        waterTargetMl: (m['water_target'] as num?)?.toDouble() ?? 1500,
        slogan: (m['slogan'] as String?) ?? '',
        settleHour: (m['settle_hour'] as num?)?.toInt() ?? 23,
        settleMinute: (m['settle_minute'] as num?)?.toInt() ?? 30,
        remindBreakfast: (m['remind_breakfast'] as num? ?? 0) != 0,
        remindLunch: (m['remind_lunch'] as num? ?? 0) != 0,
        remindDinner: (m['remind_dinner'] as num? ?? 0) != 0,
        remindWater: (m['remind_water'] as num? ?? 0) != 0,
        remindSettle: (m['remind_settle'] as num? ?? 1) != 0,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (m['updated_at'] as num?)?.toInt() ?? 0),
      );
}
