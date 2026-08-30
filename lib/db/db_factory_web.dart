/// Web 平台数据库工厂（sqlite3 WASM + IndexedDB）
library;

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

DatabaseFactory getPlatformDatabaseFactory() => databaseFactoryFfiWeb;
