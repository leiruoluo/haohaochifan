/// 数据仓库：所有读写走这里。
/// - 软删除（deleted 标记）配合 updated_at 时间戳，为局域网/云端同步预留
/// - 未来接入云端只需替换本文件内部实现，业务层调用不变
library;

import 'package:sqflite_common/sqlite_api.dart';

import '../models/dish.dart';
import '../models/exercise.dart';
import '../models/food.dart';
import '../models/log.dart';
import '../models/plan.dart';
import '../models/profile.dart';
import 'database.dart' as dbmod;

class AppRepository {
  final Database db;
  AppRepository(this.db);

  // ---------- 档案 ----------
  Future<UserProfile?> loadProfile() async {
    final rows = await db.query('profile', limit: 1);
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  Future<void> saveProfile(UserProfile p) async {
    await db.insert('profile', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- 食物 ----------
  Future<List<Food>> getFoods({bool includeDeleted = false}) async {
    final rows = await db.query('foods',
        where: includeDeleted ? null : 'deleted = 0', orderBy: 'name');
    return rows.map(Food.fromMap).toList();
  }

  Future<Map<String, Food>> foodMap() async {
    final rows = await db.query('foods');
    return {for (final r in rows) r['id'] as String: Food.fromMap(r)};
  }

  Future<void> upsertFood(Food f) async {
    await db.insert('foods', f.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> softDeleteFood(String id) async {
    await db.update('foods', {'deleted': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAllFoods(List<Food> foods) async {
    await db.transaction((txn) async {
      await txn.delete('foods');
      for (final f in foods) {
        await txn.insert('foods', f.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ---------- 菜肴 ----------
  Future<List<Dish>> getDishes({bool includeDeleted = false}) async {
    final rows = await db.query('dishes',
        where: includeDeleted ? null : 'deleted = 0', orderBy: 'name');
    return rows.map(Dish.fromMap).toList();
  }

  Future<Map<String, Dish>> dishMap() async {
    final rows = await db.query('dishes');
    return {for (final r in rows) r['id'] as String: Dish.fromMap(r)};
  }

  Future<void> upsertDish(Dish d) async {
    await db.insert('dishes', d.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> softDeleteDish(String id) async {
    await db.update('dishes', {'deleted': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [id]);
  }

  // ---------- 计划 ----------
  Future<List<PlanDay>> getPlans({bool includeDeleted = false}) async {
    final rows = await db.query('plans',
        where: includeDeleted ? null : 'deleted = 0',
        orderBy: 'date IS NULL, date');
    return rows.map(PlanDay.fromMap).toList();
  }

  Future<PlanDay?> getPlanForDate(DateTime d) async {
    final rows = await db.query('plans',
        where: 'date = ? AND deleted = 0', whereArgs: [dbmod.dayKey(d)], limit: 1);
    if (rows.isEmpty) return null;
    return PlanDay.fromMap(rows.first);
  }

  Future<void> upsertPlan(PlanDay p) async {
    await db.insert('plans', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> softDeletePlan(String id) async {
    await db.update('plans', {'deleted': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [id]);
  }

  // ---------- 每日记录 ----------
  Future<DayLog?> getDayLog(DateTime d) async {
    final rows = await db.query('day_logs',
        where: 'date = ?', whereArgs: [dbmod.dayKey(d)], limit: 1);
    if (rows.isEmpty) return null;
    return DayLog.fromMap(rows.first);
  }

  Future<void> saveDayLog(DayLog log) async {
    await db.insert('day_logs', log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<DayLog>> getDayLogs(DateTime start, DateTime end) async {
    final rows = await db.query('day_logs',
        where: 'date >= ? AND date <= ?',
        whereArgs: [dbmod.dayKey(start), dbmod.dayKey(end)],
        orderBy: 'date');
    return rows.map(DayLog.fromMap).toList();
  }

  // ---------- 运动 ----------
  Future<List<ExerciseType>> getExerciseTypes({bool includeDeleted = false}) async {
    final rows = await db.query('exercises',
        where: includeDeleted ? null : 'deleted = 0', orderBy: 'name');
    return rows.map(ExerciseType.fromMap).toList();
  }

  Future<void> upsertExercise(ExerciseType e) async {
    await db.insert('exercises', e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> softDeleteExercise(String id) async {
    await db.update('exercises', {'deleted': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAllExercises(List<ExerciseType> list) async {
    await db.transaction((txn) async {
      await txn.delete('exercises');
      for (final e in list) {
        await txn.insert('exercises', e.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ---------- 体重 ----------
  Future<List<WeightRecord>> getWeights() async {
    final rows = await db.query('weights', orderBy: 'date');
    return rows.map(WeightRecord.fromMap).toList();
  }

  Future<WeightRecord?> getWeightForDate(DateTime d) async {
    final rows = await db.query('weights',
        where: 'date = ?', whereArgs: [dbmod.dayKey(d)], limit: 1);
    if (rows.isEmpty) return null;
    return WeightRecord.fromMap(rows.first);
  }

  Future<void> upsertWeight(WeightRecord w) async {
    await db.insert('weights', w.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteWeight(String id) async {
    await db.delete('weights', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- 全量导出 / 导入（备份与迁移） ----------

  /// 导出全部数据为 JSON（含档案、食物、菜肴、计划、记录、运动、体重）
  Future<Map<String, Object?>> exportAll() async {
    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'profile': await _queryAll('profile'),
      'foods': await _queryAll('foods'),
      'dishes': await _queryAll('dishes'),
      'plans': await _queryAll('plans'),
      'day_logs': await _queryAll('day_logs'),
      'exercises': await _queryAll('exercises'),
      'weights': await _queryAll('weights'),
    };
  }

  Future<List<Map<String, Object?>>> _queryAll(String table) =>
      db.query(table);

  /// 导入全量备份（replace 模式：覆盖本机数据）
  Future<void> importAll(Map<String, Object?> data) async {
    final tables = [
      'profile', 'foods', 'dishes', 'plans', 'day_logs', 'exercises', 'weights',
    ];
    await db.transaction((txn) async {
      for (final t in tables) {
        await txn.delete(t);
        final rows = (data[t] as List?) ?? const [];
        for (final r in rows) {
          await txn.insert(t, (r as Map).cast<String, Object?>(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
}
