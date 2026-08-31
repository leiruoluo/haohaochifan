/// 数据库打开与建表
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'db_factory.dart';

Database? _db;

Future<Database> get database async => _db ??= await _open();

Future<Database> _open() async {
  final factory = getPlatformDatabaseFactory();
  String path;
  if (kIsWeb) {
    path = 'haohaochifan.db'; // web 走 IndexedDB
  } else {
    final dir = await getApplicationSupportDirectory();
    path = p.join(dir.path, 'haohaochifan.db');
  }
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await createSchema(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          // v1.1：档案增加自定义基础代谢
          await db.execute('ALTER TABLE profile ADD COLUMN custom_bmr REAL');
          await db.execute(
              'ALTER TABLE profile ADD COLUMN use_custom_bmr INTEGER DEFAULT 0');
        }
        if (oldV < 3) {
          // v1.1：最近吃过记录
          await db.execute('''
            CREATE TABLE food_recent (
              ref_id TEXT PRIMARY KEY,
              is_dish INTEGER,
              last_used INTEGER
            )
          ''');
        }
        if (oldV < 4) {
          // v1.1：菜肴增加做法步骤
          await db.execute(
              'ALTER TABLE dishes ADD COLUMN steps_json TEXT');
        }
      },
    ),
  );
}

/// 建表（公开，供测试复用）
Future<void> createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE profile (
      id TEXT PRIMARY KEY,
      gender TEXT, age INTEGER, height_cm REAL, weight_kg REAL,
      activity TEXT, goal TEXT, ideal_deficit REAL, use_custom_deficit INTEGER,
      custom_bmr REAL, use_custom_bmr INTEGER DEFAULT 0,
      water_target REAL, slogan TEXT,
      settle_hour INTEGER, settle_minute INTEGER,
      remind_breakfast INTEGER, remind_lunch INTEGER, remind_dinner INTEGER,
      remind_water INTEGER, remind_settle INTEGER,
      updated_at INTEGER
    )
  ''');
  await db.execute('''
    CREATE TABLE foods (
      id TEXT PRIMARY KEY,
      name TEXT, category TEXT, is_liquid INTEGER,
      builtin INTEGER, deleted INTEGER, updated_at INTEGER,
      per_energy REAL, per_protein REAL, per_fat REAL, per_carbs REAL,
      per_sodium REAL, per_calcium REAL, per_fiber REAL, per_sugar REAL,
      units_json TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE dishes (
      id TEXT PRIMARY KEY,
      name TEXT, note TEXT, steps_json TEXT,
      builtin INTEGER, deleted INTEGER, updated_at INTEGER,
      ingredients_json TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE plans (
      id TEXT PRIMARY KEY,
      name TEXT, date INTEGER, deleted INTEGER, updated_at INTEGER,
      meals_json TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE day_logs (
      date INTEGER PRIMARY KEY,
      water_ml REAL, note TEXT, updated_at INTEGER,
      meals_json TEXT, exercises_json TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE exercises (
      id TEXT PRIMARY KEY,
      name TEXT, met REAL, builtin INTEGER, deleted INTEGER, updated_at INTEGER
    )
  ''');
  await db.execute('''
    CREATE TABLE weights (
      id TEXT PRIMARY KEY,
      date INTEGER, weight_kg REAL, updated_at INTEGER
    )
  ''');
  await db.execute('''
    CREATE TABLE food_recent (
      ref_id TEXT PRIMARY KEY,
      is_dish INTEGER,
      last_used INTEGER
    )
  ''');
  await db.execute('CREATE INDEX idx_foods_name ON foods(name)');
  await db.execute('CREATE INDEX idx_plans_date ON plans(date)');
  await db.execute('CREATE INDEX idx_weights_date ON weights(date)');
}

/// 日期标准化（只取年月日）
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 日期键（day_logs 主键）
int dayKey(DateTime d) => dayOnly(d).millisecondsSinceEpoch;
