/// io 平台（Windows/Linux/Android/iOS）数据库工厂
library;

import 'dart:io';

import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_common/sqlite_api.dart';

DatabaseFactory getPlatformDatabaseFactory() {
  if (Platform.isAndroid || Platform.isIOS) {
    return sqflite.databaseFactory;
  }
  ffi.sqfliteFfiInit();
  return ffi.databaseFactoryFfi;
}
