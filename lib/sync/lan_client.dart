/// 局域网同步客户端（运行在手机端）
/// 流程：拉取 PC 全量导出 → 与本机合并 → 回传合并结果 → 本机导入
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'merge.dart';

class LanSyncException implements Exception {
  final String message;
  LanSyncException(this.message);
  @override
  String toString() => message;
}

class LanClient {
  static const _timeout = Duration(seconds: 20);

  static String urlFor(String host, String code) =>
      'http://$host:18623/export?code=$code';

  /// 执行一次完整双向同步，返回合并后的全量数据
  static Future<Map<String, Object?>> sync({
    required String host,
    required String code,
    required Map<String, Object?> localExport,
  }) async {
    final base = 'http://$host:18623';
    try {
      // 1. 拉取远端
      final pullResp = await http
          .get(Uri.parse('$base/export?code=$code'))
          .timeout(_timeout);
      if (pullResp.statusCode != 200) {
        throw LanSyncException('拉取失败：HTTP ${pullResp.statusCode}'
            '${pullResp.body.length > 80 ? '（可能是配对码错误）' : ''}');
      }
      final remote =
          jsonDecode(utf8.decode(pullResp.bodyBytes)) as Map<String, Object?>;
      // 2. 合并
      final merged = mergeExports(localExport, remote);
      // 3. 回传合并结果
      final pushResp = await http
          .post(
            Uri.parse('$base/merge?code=$code'),
            headers: {'content-type': 'application/json; charset=utf-8'},
            body: jsonEncode(merged),
          )
          .timeout(_timeout);
      if (pushResp.statusCode != 200) {
        throw LanSyncException('回传失败：HTTP ${pushResp.statusCode}');
      }
      final mergedBack =
          jsonDecode(utf8.decode(pushResp.bodyBytes)) as Map<String, Object?>;
      return mergedBack;
    } on LanSyncException {
      rethrow;
    } catch (e) {
      throw LanSyncException('无法连接 PC（请确认同一 WiFi、PC 端已开启同步）：$e');
    }
  }

  /// 仅拉取（只读预览远端数据量）
  static Future<int> ping(String host, String code) async {
    final resp = await http
        .get(Uri.parse('http://$host:18623/export?code=$code'))
        .timeout(_timeout);
    if (resp.statusCode != 200) throw LanSyncException('HTTP ${resp.statusCode}');
    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, Object?>;
    return ((data['day_logs'] as List?) ?? const []).length;
  }
}
