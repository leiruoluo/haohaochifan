/// 跨平台数据库工厂选择（条件导入）
library;

import 'package:sqflite_common/sqlite_api.dart';

/// 由平台实现文件提供（io/web）；此处仅作不可能命中的兜底
DatabaseFactory getPlatformDatabaseFactory() =>
    throw UnimplementedError('no platform database factory');
