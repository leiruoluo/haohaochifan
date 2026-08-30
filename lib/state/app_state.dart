/// 全局应用状态：数据缓存 + 业务操作入口
/// 页面通过 Provider 访问；数据变更即 notifyListeners
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../db/database.dart' as dbmod;
import '../db/repository.dart';
import '../engine/settlement.dart';
import '../models/dish.dart';
import '../models/exercise.dart';
import '../models/food.dart';
import '../models/log.dart';
import '../models/plan.dart';
import '../models/profile.dart';
import '../services/reminders.dart';
import '../sync/lan_client.dart';
import '../sync/lan_server.dart';
import '../util/uuid.dart';

class AppState extends ChangeNotifier {
  final AppRepository repo;

  UserProfile? profile;
  List<Food> foods = [];
  List<Dish> dishes = [];
  List<ExerciseType> exerciseTypes = [];
  List<PlanDay> plans = [];

  // 日历状态
  DateTime monthAnchor = DateTime.now(); // 当前查看的月份
  DateTime? selectedDay; // 详情页选中的日期

  LanServer? lanServer;
  String pairingCode = '';
  bool syncing = false;
  String? syncMessage;

  // 当日记录缓存（避免频繁读库）
  DayLog? _dayCache;
  DateTime? _dayCacheDate;

  AppState(this.repo);

  Map<String, Food> get foodMap =>
      {for (final f in foods) f.id: f};
  Map<String, Dish> get dishMap =>
      {for (final d in dishes) d.id: d};

  UserProfile get profileOrNull => profile!;

  // ---------------- 初始化 ----------------
  Future<void> init() async {
    profile = await repo.loadProfile();
    foods = await repo.getFoods();
    dishes = await repo.getDishes();
    exerciseTypes = await repo.getExerciseTypes();
    plans = await repo.getPlans();
    if (foods.isEmpty) {
      await seedBuiltin();
      foods = await repo.getFoods();
      dishes = await repo.getDishes();
      exerciseTypes = await repo.getExerciseTypes();
    }
    if (exerciseTypes.isEmpty) {
      await seedExercises();
      exerciseTypes = await repo.getExerciseTypes();
    }
    notifyListeners();
  }

  // ---------------- 内置数据 ----------------
  Future<void> seedBuiltin() async {
    final raw = await rootBundle.loadString('assets/data/foods_v6.json');
    final data = jsonDecode(raw) as Map<String, Object?>;
    final foodsJson = (data['foods'] as List).cast<Map<String, Object?>>();
    final now = DateTime.now().millisecondsSinceEpoch;
    final foods = foodsJson.map((m) {
      final per = (m['per100'] as Map).cast<String, Object?>();
      final units = ((m['units'] as List?) ?? const [])
          .map((u) => UnitDef((u as Map)['name'] as String,
              (u['grams'] as num).toDouble()))
          .toList();
      return Food(
        id: m['id'] as String,
        name: m['name'] as String,
        category: (m['category'] as String?) ?? '其他',
        isLiquid: (m['is_liquid'] as num? ?? 0) != 0,
        builtin: true,
        per100: Nutrition.fromMap(per),
        units: units,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    }).toList();
    await repo.replaceAllFoods(foods);

    // 内置示例菜肴（按食物名解析引用）
    final byName = {for (final f in foods) f.name: f};
    final dishesJson = (data['dishes'] as List?) ?? const [];
    for (final m in dishesJson.cast<Map<String, Object?>>()) {
      final ings = ((m['ingredients'] as List?) ?? const [])
          .map((i) {
            final im = i as Map;
            final f = byName[im['food'] as String];
            if (f == null) return null;
            return DishIngredient(f.id, (im['grams'] as num).toDouble());
          })
          .whereType<DishIngredient>()
          .toList();
      if (ings.isEmpty) continue;
      await repo.upsertDish(Dish(
        id: genUuid(),
        name: m['name'] as String,
        ingredients: ings,
        builtin: true,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      ));
    }
  }

  Future<void> seedExercises() async {
    final now = DateTime.now();
    final list = kBuiltinExercises
        .map((e) => ExerciseType(
              id: 'ex_${e['name']}',
              name: e['name'] as String,
              met: (e['met'] as num).toDouble(),
              builtin: true,
              updatedAt: now,
            ))
        .toList();
    await repo.replaceAllExercises(list);
  }

  // ---------------- 档案 ----------------
  Future<void> saveProfile(UserProfile p) async {
    profile = p;
    await repo.saveProfile(p);
    await ReminderService.scheduleAll(p); // 更新提醒
    notifyListeners();
  }

  // ---------------- 食物 / 菜肴 ----------------
  Future<void> upsertFood(Food f) async {
    await repo.upsertFood(f);
    foods = await repo.getFoods();
    notifyListeners();
  }

  Future<void> deleteFood(String id) async {
    await repo.softDeleteFood(id);
    foods = await repo.getFoods();
    notifyListeners();
  }

  Future<void> upsertDish(Dish d) async {
    await repo.upsertDish(d);
    dishes = await repo.getDishes();
    notifyListeners();
  }

  Future<void> deleteDish(String id) async {
    await repo.softDeleteDish(id);
    dishes = await repo.getDishes();
    notifyListeners();
  }

  // ---------------- 每日记录 ----------------
  Future<DayLog> dayLog(DateTime d) async {
    final key = dbmod.dayKey(d);
    if (_dayCache != null && _dayCacheDate != null &&
        dbmod.dayKey(_dayCacheDate!) == key) {
      return _dayCache!;
    }
    final log = await repo.getDayLog(d) ??
        DayLog(date: dbmod.dayOnly(d), updatedAt: DateTime.now());
    _dayCache = log;
    _dayCacheDate = log.date;
    return log;
  }

  Future<void> saveDayLog(DayLog log) async {
    await repo.saveDayLog(log);
    _dayCache = log;
    _dayCacheDate = log.date;
    notifyListeners();
  }

  /// 为某天增加一条饮食记录（食物或菜肴），[mealName] 为餐次名
  Future<void> addEntry(DateTime d, String mealName, LogEntry entry) async {
    final log = await dayLog(d);
    final meals = [...log.meals];
    // 追加到同名餐次；没有则新建该餐次
    final idx = meals.indexWhere((m) => m.mealName == mealName);
    if (idx >= 0) {
      meals[idx] = MealLog(
        id: meals[idx].id,
        mealName: meals[idx].mealName,
        entries: [...meals[idx].entries, entry],
      );
    } else {
      meals.add(MealLog(
        id: genUuid(),
        mealName: mealName,
        entries: [entry],
      ));
    }
    await saveDayLog(log.copyWith(meals: meals));
  }

  Future<void> updateWater(DateTime d, double ml) async {
    final log = await dayLog(d);
    await saveDayLog(log.copyWith(waterMl: ml));
  }

  Future<void> addExercise(DateTime d, ExerciseLog ex) async {
    final log = await dayLog(d);
    await saveDayLog(log.copyWith(exercises: [...log.exercises, ex]));
  }

  Future<void> removeMeal(DateTime d, String mealId) async {
    final log = await dayLog(d);
    await saveDayLog(
        log.copyWith(meals: log.meals.where((m) => m.id != mealId).toList()));
  }

  Future<void> removeExercise(DateTime d, String exId) async {
    final log = await dayLog(d);
    await saveDayLog(log.copyWith(
        exercises: log.exercises.where((e) => e.id != exId).toList()));
  }

  /// 实时结算（不落库，每次由最新数据计算）
  Future<DaySettlement> settlement(DateTime d) async {
    final log = await dayLog(d);
    return settleDay(
      log: log,
      foods: foodMap,
      dishes: dishMap,
      profile: profile ?? const UserProfile(),
    );
  }

  // ---------------- 计划 ----------------
  Future<void> reloadPlans() async {
    plans = await repo.getPlans();
    notifyListeners();
  }

  Future<PlanDay?> planForDate(DateTime d) => repo.getPlanForDate(d);

  Future<void> upsertPlan(PlanDay p) async {
    await repo.upsertPlan(p);
    await reloadPlans();
  }

  Future<void> deletePlan(String id) async {
    await repo.softDeletePlan(id);
    await reloadPlans();
  }

  /// 把计划日的所有条目复制进某天的记录（同名餐次合并追加）
  Future<void> copyPlanToDay(PlanDay plan, DateTime d) async {
    final log = await dayLog(d);
    final meals = [...log.meals];
    for (final pm in plan.meals) {
      final entries = pm.items
          .map((i) => LogEntry(
                id: genUuid(),
                refId: i.refId,
                isDish: i.isDish,
                name: i.name,
                amount: i.amount,
                unitName: i.unitName,
              ))
          .toList();
      final idx = meals.indexWhere((m) => m.mealName == pm.mealName);
      if (idx >= 0) {
        meals[idx] = MealLog(
          id: meals[idx].id,
          mealName: meals[idx].mealName,
          entries: [...meals[idx].entries, ...entries],
        );
      } else {
        meals.add(MealLog(id: genUuid(), mealName: pm.mealName, entries: entries));
      }
    }
    await saveDayLog(log.copyWith(meals: meals));
  }

  // ---------------- 统计 ----------------
  Future<List<DayLog>> logsInRange(DateTime start, DateTime end) =>
      repo.getDayLogs(start, end);

  Future<List<WeightRecord>> weights() => repo.getWeights();

  Future<WeightRecord?> weightForDate(DateTime d) => repo.getWeightForDate(d);

  /// 记录某天体重（同一天重复记录会覆盖）
  Future<void> saveWeightForDate(DateTime d, double kg) async {
    final existing = await repo.getWeightForDate(d);
    final w = WeightRecord(
      id: existing?.id ?? genUuid(),
      date: dbmod.dayOnly(d),
      weightKg: kg,
      updatedAt: DateTime.now(),
    );
    await repo.upsertWeight(w);
    notifyListeners();
  }

  Future<void> removeWeight(String id) async {
    await repo.deleteWeight(id);
    notifyListeners();
  }

  // ---------------- 局域网同步 ----------------
  Future<void> startLanServer() async {
    try {
      pairingCode = _genCode();
      lanServer = LanServer(repo, pairingCode);
      await lanServer!.start();
    } catch (e) {
      // Web 端等无本地服务器能力的平台：静默提示
      syncMessage = '当前平台不支持局域网同步服务';
    }
    notifyListeners();
  }

  Future<void> stopLanServer() async {
    await lanServer?.stop();
    lanServer = null;
    notifyListeners();
  }

  String _genCode() {
    var code = '';
    for (var i = 0; i < 4; i++) {
      code += (DateTime.now().microsecondsSinceEpoch % 10).toString();
    }
    return code;
  }

  Future<Map<String, Object?>> exportJson() => repo.exportAll();

  Future<void> importJson(Map<String, Object?> data) async {
    await repo.importAll(data);
    await init();
  }

  /// 手机端执行与 PC 的双向合并同步
  Future<void> syncWithPc(String host, String code) async {
    syncing = true;
    syncMessage = null;
    notifyListeners();
    try {
      final local = await repo.exportAll();
      final merged = await LanClient.sync(
          host: host, code: code, localExport: local);
      await repo.importAll(merged);
      await init();
      syncMessage = '同步完成 ✅';
    } catch (e) {
      syncMessage = '同步失败：$e';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}
