import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haohaochifan/db/database.dart' as dbmod;
import 'package:haohaochifan/db/repository.dart';
import 'package:haohaochifan/models/log.dart';
import 'package:haohaochifan/sync/lan_client.dart';
import 'package:haohaochifan/sync/lan_server.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 局域网同步端到端测试：真实 shelf 服务端 + http 客户端 + 双向合并
Future<AppRepository> makeRepo() async {
  final dir = await Directory.systemTemp.createTemp('hcf_test_');
  final dbPath = '${dir.path}/test.db';
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
        version: 1, onCreate: (db, _) => dbmod.createSchema(db)),
  );
  return AppRepository(db);
}

DayLog makeDay(int day, String entryName) => DayLog(
      date: DateTime(2026, 9, day),
      meals: [
        MealLog(id: 'm$day', mealName: '早餐', entries: [
          LogEntry(
              id: 'e$day',
              refId: 'f001',
              isDish: false,
              name: entryName,
              amount: 100,
              unitName: '克'),
        ]),
      ],
      updatedAt: DateTime(2026, 9, day, 12),
    );

void main() {
  test('双向同步：PC 与手机各自的数据合并且两端一致', () async {
    final pcRepo = await makeRepo();
    final phoneRepo = await makeRepo();

    // PC 有 9月1日，手机有 9月2日
    await pcRepo.saveDayLog(makeDay(1, 'PC的记录'));
    await phoneRepo.saveDayLog(makeDay(2, '手机的记录'));

    final server = LanServer(pcRepo, '1234');
    await server.start();
    final port = server.port!;

    // 手机执行一次完整同步
    final phoneExport = await phoneRepo.exportAll();
    final merged = await LanClient.sync(
        host: '127.0.0.1', code: '1234', localExport: phoneExport);
    await phoneRepo.importAll(merged);
    await server.stop();

    // 两端都应包含两天的记录
    final pcLogs =
        await pcRepo.getDayLogs(DateTime(2026, 9, 1), DateTime(2026, 9, 30));
    final phoneLogs =
        await phoneRepo.getDayLogs(DateTime(2026, 9, 1), DateTime(2026, 9, 30));
    expect(pcLogs.length, 2, reason: 'PC 应有两天记录');
    expect(phoneLogs.length, 2, reason: '手机应有两天记录');

    final names = pcLogs
        .expand((l) => l.meals)
        .expand((m) => m.entries)
        .map((e) => e.name)
        .toSet();
    expect(names, contains('PC的记录'));
    expect(names, contains('手机的记录'));
  });

  test('同步时本机较新的记录优先保留（last-write-wins）', () async {
    final pcRepo = await makeRepo();
    final phoneRepo = await makeRepo();

    // 同一天（9月3日），PC 的 updatedAt 较新，内容不同
    await pcRepo.saveDayLog(DayLog(
      date: DateTime(2026, 9, 3),
      meals: [
        MealLog(id: 'm3', mealName: '早餐', entries: [
          LogEntry(
              id: 'e3', refId: 'f001', isDish: false, name: 'PC新版',
              amount: 150, unitName: '克'),
        ]),
      ],
      updatedAt: DateTime(2026, 9, 3, 20),
    ));
    await phoneRepo.saveDayLog(DayLog(
      date: DateTime(2026, 9, 3),
      meals: [
        MealLog(id: 'm3', mealName: '早餐', entries: [
          LogEntry(
              id: 'e3', refId: 'f001', isDish: false, name: '手机旧版',
              amount: 100, unitName: '克'),
        ]),
      ],
      updatedAt: DateTime(2026, 9, 3, 8),
    ));

    final server = LanServer(pcRepo, '1234');
    await server.start();
    final merged = await LanClient.sync(
        host: '127.0.0.1',
        code: '1234',
        localExport: await phoneRepo.exportAll());
    await phoneRepo.importAll(merged);
    await server.stop();

    final phoneLogs =
        await phoneRepo.getDayLogs(DateTime(2026, 9, 3), DateTime(2026, 9, 3));
    final name = phoneLogs.single.meals.single.entries.single.name;
    expect(name, 'PC新版', reason: 'updatedAt 较新的 PC 版应胜出');
  });

  test('配对码错误应被拒绝', () async {
    final pcRepo = await makeRepo();
    final server = LanServer(pcRepo, '1234');
    await server.start();
    try {
      await expectLater(
        LanClient.sync(
            host: '127.0.0.1',
            code: '9999',
            localExport: await pcRepo.exportAll()),
        throwsA(isA<LanSyncException>()),
      );
    } finally {
      await server.stop();
    }
  });

  test('服务未开启时客户端应给出友好错误', () async {
    final phoneRepo = await makeRepo();
    await expectLater(
      LanClient.sync(
          host: '127.0.0.1',
          code: '1234',
          localExport: await phoneRepo.exportAll()),
      throwsA(isA<LanSyncException>()),
    );
  });
}
