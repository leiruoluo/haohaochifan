import 'package:flutter_test/flutter_test.dart';
import 'package:haohaochifan/db/database.dart' as dbmod;
import 'package:haohaochifan/db/repository.dart';
import 'package:haohaochifan/models/log.dart';
import 'package:haohaochifan/models/profile.dart';
import 'package:haohaochifan/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DB 插入档案应完成', () async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
          version: 1, onCreate: (db, _) => dbmod.createSchema(db)),
    );
    final repo = AppRepository(db);
    final state = AppState(repo);
    await state.init();
    expect(state.profile, isNull);

    final p = const UserProfile(
      gender: Gender.male,
      age: 28,
      heightCm: 172,
      weightKg: 66,
    );
    await state.saveProfile(p);
    expect(state.profile, isNotNull);

    // 重新从库中读取
    final loaded = await repo.loadProfile();
    expect(loaded, isNotNull);
    expect(loaded!.age, 28);
    expect(loaded.gender, Gender.male);
  });

  test('每日记录写入与读取', () async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
          version: 1, onCreate: (db, _) => dbmod.createSchema(db)),
    );
    final repo = AppRepository(db);
    final state = AppState(repo);
    await state.init();

    final day = DateTime(2026, 8, 30);
    final log = await state.dayLog(day);
    expect(log.meals, isEmpty);

    await state.addEntry(day, '早餐', const LogEntry(
      id: 'e1',
      refId: 'f001',
      isDish: false,
      name: '米饭',
      amount: 200,
      unitName: '克',
    ));
    final after = await state.dayLog(day);
    expect(after.meals.length, 1);
    expect(after.meals.first.mealName, '早餐');

    // 重新打开新实例读取（sqflite 内存库在同进程内共享，数据应仍可见）
    final db2 = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
          version: 1, onCreate: (db, _) => dbmod.createSchema(db)),
    );
    final state2 = AppState(AppRepository(db2));
    await state2.init();
    final log2 = await state2.dayLog(day);
    expect(log2.meals.length, 1);
    expect(log2.meals.first.mealName, '早餐');
  });

  test('体重记录：同一天覆盖，不同天独立', () async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
          version: 1, onCreate: (db, _) => dbmod.createSchema(db)),
    );
    final repo = AppRepository(db);
    final state = AppState(repo);
    await state.init();

    final d1 = DateTime(2026, 9, 5);
    await state.saveWeightForDate(d1, 65.5);
    await state.saveWeightForDate(d1, 65.2); // 覆盖
    await state.saveWeightForDate(DateTime(2026, 9, 7), 65.0);

    final w1 = await state.weightForDate(d1);
    expect(w1, isNotNull);
    expect(w1!.weightKg, 65.2);

    final all = await state.weights();
    expect(all.length, 2);

    await state.removeWeight(w1.id);
    expect((await state.weights()).length, 1);
  });
}
