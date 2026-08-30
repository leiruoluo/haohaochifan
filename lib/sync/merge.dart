/// 按 updated_at 合并数据集合（同步核心算法）
/// 行级 last-write-wins；软删除行（deleted=1）作为墓碑参与合并
library;

/// 合并两个同构行集合，返回合并结果
/// [localRows]/[remoteRows] 为 Map 列表，[keyCol] 为主键列名
/// 每行取 updated_at 更大者；无时间戳按 0 处理
List<Map<String, Object?>> mergeRows(
  List<Map<String, Object?>> localRows,
  List<Map<String, Object?>> remoteRows, {
  required String keyCol,
}) {
  final byKey = <String, Map<String, Object?>>{};

  void addAll(List<Map<String, Object?>> rows) {
    for (final r in rows) {
      final k = r[keyCol];
      if (k == null) continue;
      final key = k.toString();
      final existing = byKey[key];
      final rts = (r['updated_at'] as num?)?.toInt() ?? 0;
      final ets = (existing?['updated_at'] as num?)?.toInt() ?? 0;
      if (existing == null || rts > ets) byKey[key] = r;
    }
  }

  addAll(localRows);
  addAll(remoteRows);
  return byKey.values.toList();
}

List<Map<String, Object?>> _rowsOf(Map<String, Object?> data, String key) =>
    ((data[key] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => m.cast<String, Object?>())
        .toList();

/// 合并两份完整导出（全表合并），返回新的全量数据集
Map<String, Object?> mergeExports(
  Map<String, Object?> local,
  Map<String, Object?> remote,
) {
  return {
    'version': 1,
    'exported_at': DateTime.now().toIso8601String(),
    'profile': mergeRows(_rowsOf(local, 'profile'), _rowsOf(remote, 'profile'),
        keyCol: 'id'),
    'foods': mergeRows(_rowsOf(local, 'foods'), _rowsOf(remote, 'foods'),
        keyCol: 'id'),
    'dishes': mergeRows(_rowsOf(local, 'dishes'), _rowsOf(remote, 'dishes'),
        keyCol: 'id'),
    'plans': mergeRows(_rowsOf(local, 'plans'), _rowsOf(remote, 'plans'),
        keyCol: 'id'),
    'day_logs':
        mergeRows(_rowsOf(local, 'day_logs'), _rowsOf(remote, 'day_logs'),
            keyCol: 'date'),
    'exercises':
        mergeRows(_rowsOf(local, 'exercises'), _rowsOf(remote, 'exercises'),
            keyCol: 'id'),
    'weights': mergeRows(_rowsOf(local, 'weights'), _rowsOf(remote, 'weights'),
        keyCol: 'id'),
  };
}
