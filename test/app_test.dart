import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haohaochifan/app.dart';
import 'package:haohaochifan/db/database.dart' as dbmod;
import 'package:haohaochifan/db/repository.dart';
import 'package:haohaochifan/main.dart';
import 'package:haohaochifan/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 说明：
/// - 首次启动引导页渲染测试在此处（不依赖数据库写入）
/// - 引导→主界面的完整流程、菜谱库导入等涉及真实数据库的流程，
///   见 db_test.dart（数据层）与 ui_test.dart（金样渲染）——两者在真实
///   异步下执行；FakeAsync 中 FFI 数据库 Future 不会完成，无法在
///   tap 驱动的流程里验证。
Future<AppState> makeState() async {
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
        version: 1, onCreate: (db, _) => dbmod.createSchema(db)),
  );
  final state = AppState(AppRepository(db));
  await state.init();
  return state;
}

void main() {
  testWidgets('首次启动显示引导页', (tester) async {
    await tester.runAsync(() async {
      final state = await makeState();
      await tester.pumpWidget(AppRoot(state: state));
      await tester.pumpAndSettle();

      expect(find.text('好好吃饭'), findsWidgets);
      expect(find.text('为身材管理而生的饮食记录工具'), findsOneWidget);
      expect(find.text('下一步'), findsOneWidget);
      expect(find.text('开始使用'), findsNothing);
    });
  });

  testWidgets('引导页三步流程可推进', (tester) async {
    await tester.runAsync(() async {
      final state = await makeState();
      await tester.pumpWidget(AppRoot(state: state));
      await tester.pumpAndSettle();

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('活动水平与目标'), findsOneWidget);

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('理想热量缺口/盈余'), findsOneWidget);
      expect(find.text('开始使用'), findsOneWidget);

      await tester.tap(find.text('上一步'));
      await tester.pumpAndSettle();
      expect(find.text('活动水平与目标'), findsOneWidget);
    });
  });
}
