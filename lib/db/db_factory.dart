/// 条件导入入口：db_factory_stub 作为 fallback，
/// io 平台用 db_factory_io，web 平台用 db_factory_web
library;

export 'db_factory_stub.dart'
    if (dart.library.io) 'db_factory_io.dart'
    if (dart.library.js_interop) 'db_factory_web.dart';
