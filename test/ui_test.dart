import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:haohaochifan/app.dart';
import 'package:haohaochifan/db/database.dart' as dbmod;
import 'package:haohaochifan/db/repository.dart';
import 'package:haohaochifan/models/log.dart';
import 'package:haohaochifan/models/profile.dart';
import 'package:haohaochifan/pages/day_detail_page.dart';
import 'package:haohaochifan/pages/onboarding_page.dart';
import 'package:haohaochifan/state/app_state.dart';
import 'package:haohaochifan/theme.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

/// 加载系统中文字体（让金样里的文字可读）
Future<void> loadChineseFont() async {
  for (final f in ['C:/Windows/Fonts/simhei.ttf', 'C:/Windows/Fonts/msyh.ttf']) {
    final fontFile = File(f);
    if (!fontFile.existsSync()) continue;
    try {
      final bytes = fontFile.readAsBytesSync();
      final loader = FontLoader('AppCN')
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      return;
    } catch (_) {}
  }
}

ThemeData testTheme() => AppTheme.light(fontFamily: 'AppCN');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
    await loadChineseFont();
  });

  testWidgets('金样：引导页', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: testTheme(),
      home: const OnboardingPage(),
    ));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(OnboardingPage), matchesGoldenFile('goldens/onboarding.png'));
  });

  testWidgets('金样：当日详情页（含记录/饮水/运动/结算）', (tester) async {
    late AppState state;
    final day = DateTime(2026, 8, 30);
    await tester.runAsync(() async {
      state = await makeState();
      await state.addEntry(day, '早餐', const LogEntry(
          id: 'e1', refId: 'f001', isDish: false, name: '米饭（蒸）',
          amount: 200, unitName: '克'));
      await state.addEntry(day, '早餐', const LogEntry(
          id: 'e2', refId: 'f001', isDish: false, name: '鸡蛋',
          amount: 100, unitName: '克'));
      await state.addEntry(day, '午餐', const LogEntry(
          id: 'e3', refId: 'f001', isDish: false, name: '鸡胸脯肉',
          amount: 150, unitName: '克'));
      await state.updateWater(day, 1000);
      await state.addExercise(day, ExerciseLog(
          id: 'x1', exerciseName: '慢跑（8km/h）', minutes: 30, met: 8.0));
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(theme: testTheme(), home: DayDetailPage(date: day)),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(DayDetailPage), matchesGoldenFile('goldens/day_detail.png'));
  });

  testWidgets('金样：月统计页', (tester) async {
    late AppState state;
    await tester.runAsync(() async {
      state = await makeState();
      // 预置 3 天记录，让图表有数据
      final now = DateTime.now();
      for (var i = 0; i < 3; i++) {
        final d = DateTime(now.year, now.month, 1 + i);
        await state.addEntry(d, '早餐', LogEntry(
            id: 'g$i', refId: 'f001', isDish: false, name: '米饭（蒸）',
            amount: 200, unitName: '克'));
        await state.addEntry(d, '午餐', LogEntry(
            id: 'h$i', refId: 'f001', isDish: false, name: '鸡胸脯肉',
            amount: 150, unitName: '克'));
      }
      await state.saveProfile(const UserProfile(
        gender: Gender.male, age: 28, heightCm: 172, weightKg: 66,
      ));
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(theme: testTheme(), home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    // 加高视口，让两个图表和食物榜同屏可见
    await tester.binding.setSurfaceSize(const Size(800, 1500));
    await tester.pumpAndSettle();
    // 切到统计页
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(AppShell), matchesGoldenFile('goldens/stats_page.png'));
  });
}
