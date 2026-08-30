/// 局域网同步服务端（运行在 Windows PC 上）
/// 手机端扫码后与 PC 双向合并：GET /export 拉取，POST /merge 合并回写
library;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../db/repository.dart';
import 'merge.dart';

class LanServer {
  final AppRepository repo;
  final String pairingCode; // 4 位配对码
  HttpServer? _server;
  int? _port;

  LanServer(this.repo, this.pairingCode);

  bool get isRunning => _server != null;
  int? get port => _port;

  Future<void> start() async {
    if (_server != null) return;
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_handle);
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 18623);
    _port = _server!.port;
  }

  Future<Response> _handle(Request req) async {
    if (req.url.path == 'ping') {
      return Response.ok(jsonEncode({'ok': true, 'name': '好好吃饭'}),
          headers: _jsonHeaders);
    }
    // 配对校验
    if (req.url.queryParameters['code'] != pairingCode) {
      return Response.forbidden(jsonEncode({'error': 'bad code'}),
          headers: _jsonHeaders);
    }
    try {
      if (req.url.path == 'export') {
        final data = await repo.exportAll();
        return Response.ok(jsonEncode(data), headers: _jsonHeaders);
      }
      if (req.url.path == 'merge') {
        final body = await req.readAsString();
        final remote = jsonDecode(body) as Map<String, Object?>;
        final local = await repo.exportAll();
        final merged = mergeExports(local, remote);
        await repo.importAll(merged);
        return Response.ok(jsonEncode(merged), headers: _jsonHeaders);
      }
      return Response.notFound(jsonEncode({'error': 'not found'}),
          headers: _jsonHeaders);
    } catch (e) {
      return Response(500,
          body: jsonEncode({'error': e.toString()}), headers: _jsonHeaders);
    }
  }

  static const _jsonHeaders = {
    'content-type': 'application/json; charset=utf-8',
  };

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }
}
