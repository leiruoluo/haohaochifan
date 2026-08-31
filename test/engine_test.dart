import 'package:flutter_test/flutter_test.dart';
import 'package:haohaochifan/engine/bmr.dart';
import 'package:haohaochifan/engine/settlement.dart';
import 'package:haohaochifan/models/dish.dart';
import 'package:haohaochifan/models/food.dart';
import 'package:haohaochifan/models/log.dart';
import 'package:haohaochifan/models/plan.dart';
import 'package:haohaochifan/models/profile.dart';
import 'package:haohaochifan/sync/merge.dart';

void main() {
  group('BMR/TDEE', () {
    test('男性 Mifflin-St Jeor', () {
      // 男 30岁 175cm 70kg: 10*70 + 6.25*175 - 5*30 + 5 = 700+1093.75-150+5 = 1648.75
      final bmr = bmrMifflinStJeor(
          gender: Gender.male, age: 30, heightCm: 175, weightKg: 70);
      expect(bmr, closeTo(1648.75, 0.01));
    });
    test('女性 Mifflin-St Jeor', () {
      final bmr = bmrMifflinStJeor(
          gender: Gender.female, age: 30, heightCm: 165, weightKg: 55);
      // 550 + 1031.25 - 150 - 161 = 1270.25
      expect(bmr, closeTo(1270.25, 0.01));
    });
  });

  group('结算引擎', () {
    const rice = Food(
      id: 'r1',
      name: '米饭',
      category: '主食',
      per100: Nutrition(energyKcal: 116, proteinG: 2.6, fatG: 0.3, carbsG: 25.9),
      builtin: true,
    );
    const chicken = Food(
      id: 'c1',
      name: '鸡胸肉',
      category: '肉蛋',
      per100: Nutrition(energyKcal: 118, proteinG: 24.6, fatG: 1.9),
      builtin: true,
    );

    test('摄入聚合与缺口计算', () {
      final log = DayLog(
        date: DateTime(2026, 8, 30),
        meals: [
          MealLog(id: 'm1', mealName: '早餐', entries: [
            LogEntry(
                id: 'e1',
                refId: 'r1',
                isDish: false,
                name: '米饭',
                amount: 200,
                unitName: '克'),
            LogEntry(
                id: 'e2',
                refId: 'c1',
                isDish: false,
                name: '鸡胸肉',
                amount: 150,
                unitName: '克'),
          ]),
        ],
        waterMl: 500,
        exercises: [
          ExerciseLog(id: 'x1', exerciseName: '慢跑', minutes: 30, met: 8.0),
        ],
        updatedAt: DateTime(2026, 8, 30, 20),
      );
      final s = settleDay(
        log: log,
        foods: {'r1': rice, 'c1': chicken},
        dishes: const {},
        profile: const UserProfile(
          gender: Gender.male,
          age: 30,
          heightCm: 175,
          weightKg: 70,
          activity: ActivityLevel.light,
          idealDeficitKcal: -300,
        ),
      );
      // 摄入：米饭 2*116=232 + 鸡胸 1.5*118=177 → 409
      expect(s.intakeKcal, closeTo(409, 0.01));
      expect(s.intake.proteinG, closeTo(2.6 * 2 + 24.6 * 1.5, 0.01));
      // 运动：MET 8 * 3.5 * 70 / 200 * 30 = 294
      expect(s.exerciseKcal, closeTo(294, 0.01));
      // 日常活动：BMR 1648.75 * 1.375 ≈ 2267.03
      expect(s.dailyActivityKcal, closeTo(1648.75 * 1.375, 0.01));
      // 缺口 = 409 - (2267.03 + 294) ≈ -2152
      expect(s.deficit, closeTo(409 - (2267.03 + 294), 0.5));
      // 距离理想 -300 很远，不达标
      expect(s.achieved, isFalse);
      expect(s.waterAchieved, isFalse);
      expect(s.entryCount, 2);
    });

    test('自定义单位换算（碗）', () {
      const riceBowl = Food(
        id: 'r2',
        name: '米饭',
        category: '主食',
        per100: Nutrition(energyKcal: 116),
        units: [UnitDef('碗', 200)],
        builtin: true,
      );
      final log = DayLog(
        date: DateTime(2026, 8, 30),
        meals: [
          MealLog(id: 'm1', mealName: '午餐', entries: [
            LogEntry(
                id: 'e1',
                refId: 'r2',
                isDish: false,
                name: '米饭',
                amount: 1,
                unitName: '碗'),
          ]),
        ],
      );
      final s = settleDay(
        log: log,
        foods: {'r2': riceBowl},
        dishes: const {},
        profile: const UserProfile(),
      );
      // 1 碗 = 200g → 232 kcal
      expect(s.intakeKcal, closeTo(232, 0.01));
    });

    test('组合菜肴营养汇总', () {
      final dish = Dish(
        id: 'd1',
        name: '番茄炒蛋',
        ingredients: const [
          DishIngredient('r1', 150), // 米饭作占位：116*1.5
          DishIngredient('c1', 100), // 118
        ],
      );
      final nut = dish.computeNutrition({'r1': rice, 'c1': chicken});
      expect(nut.energyKcal, closeTo(116 * 1.5 + 118, 0.01));
    });

    test('菜肴做法步骤序列化', () {
      final dish = Dish(
        id: 'd2',
        name: '番茄炒蛋',
        steps: const ['番茄切块', '热锅倒油', '翻炒出锅'],
        ingredients: const [DishIngredient('r1', 150)],
      );
      final restored = Dish.fromMap(dish.toMap());
      expect(restored.steps, ['番茄切块', '热锅倒油', '翻炒出锅']);
      expect(restored.name, '番茄炒蛋');
    });

    test('计划摄入营养（食谱对比基准）', () {
      final plan = PlanDay(
        id: 'p1',
        name: '减脂日',
        meals: [
          PlanMeal(id: 'pm1', mealName: '晚餐', items: const [
            PlanItem(
                id: 'pi1',
                refId: 'c1',
                isDish: false,
                name: '鸡胸肉',
                amount: 150,
                unitName: '克'),
          ]),
        ],
      );
      final nut = planNutrition(plan, {'c1': chicken}, const {});
      // 鸡胸肉 118 kcal/100g × 1.5 = 177
      expect(nut.energyKcal, closeTo(177, 0.01));
      expect(nut.proteinG, closeTo(24.6 * 1.5, 0.01));
    });
  });

  group('同步合并', () {
    test('last-write-wins 按 updated_at', () {
      final local = [
        {
          'id': 'a',
          'name': '旧',
          'updated_at': 100,
        },
      ];
      final remote = [
        {
          'id': 'a',
          'name': '新',
          'updated_at': 200,
        },
        {
          'id': 'b',
          'name': '仅远端',
          'updated_at': 150,
        },
      ];
      final merged = mergeRows(local, remote, keyCol: 'id');
      expect(merged.length, 2);
      expect(merged.firstWhere((r) => r['id'] == 'a')['name'], '新');
    });

    test('本机较新时保留本机', () {
      final local = [
        {'id': 'a', 'name': '本机新', 'updated_at': 300},
      ];
      final remote = [
        {'id': 'a', 'name': '远端旧', 'updated_at': 100},
      ];
      final merged = mergeRows(local, remote, keyCol: 'id');
      expect(merged.single['name'], '本机新');
    });

    test('全量导出合并', () {
      final local = {
        'foods': [
          {'id': 'f1', 'name': '旧', 'updated_at': 1},
        ],
      };
      final remote = {
        'foods': [
          {'id': 'f1', 'name': '新', 'updated_at': 2},
          {'id': 'f2', 'name': '远端', 'updated_at': 2},
        ],
      };
      final merged = mergeExports(local, remote);
      expect((merged['foods'] as List).length, 2);
    });
  });
}
