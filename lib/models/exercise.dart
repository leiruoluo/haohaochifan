/// 运动类型（MET 估算库）与体重记录
library;

/// 内置 + 用户自定义运动
class ExerciseType {
  final String id;
  final String name;
  final double met; // 代谢当量
  final bool builtin;
  final bool deleted;
  final DateTime? updatedAt;

  const ExerciseType({
    required this.id,
    required this.name,
    required this.met,
    this.builtin = false,
    this.deleted = false,
    this.updatedAt,
  });

  ExerciseType copyWith({
    String? name,
    double? met,
    bool? deleted,
    DateTime? updatedAt,
  }) =>
      ExerciseType(
        id: id,
        name: name ?? this.name,
        met: met ?? this.met,
        builtin: builtin,
        deleted: deleted ?? this.deleted,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  /// 估算消耗：MET × 3.5 × 体重kg / 200 × 分钟
  double estimateKcal(double weightKg, double minutes) =>
      met * 3.5 * weightKg / 200 * minutes;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'met': met,
        'builtin': builtin ? 1 : 0,
        'deleted': deleted ? 1 : 0,
        'updated_at': updatedAt?.millisecondsSinceEpoch ?? 0,
      };

  factory ExerciseType.fromMap(Map<String, Object?> m) => ExerciseType(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '运动',
        met: (m['met'] as num?)?.toDouble() ?? 5,
        builtin: (m['builtin'] as num? ?? 0) != 0,
        deleted: (m['deleted'] as num? ?? 0) != 0,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (m['updated_at'] as num?)?.toInt() ?? 0),
      );
}

/// 内置运动库（MET 参考：美国运动医学会/常见公开数据，近似值）
const List<Map<String, Object>> kBuiltinExercises = [
  {'name': '慢走（散步）', 'met': 3.0},
  {'name': '快走', 'met': 4.3},
  {'name': '慢跑（8km/h）', 'met': 8.0},
  {'name': '跑步（10km/h）', 'met': 9.8},
  {'name': '骑行（轻松）', 'met': 4.0},
  {'name': '骑行（较快）', 'met': 8.0},
  {'name': '游泳（休闲）', 'met': 6.0},
  {'name': '游泳（较快）', 'met': 9.8},
  {'name': '力量训练（器械）', 'met': 5.0},
  {'name': '高强度间歇（HIIT）', 'met': 8.0},
  {'name': '瑜伽', 'met': 3.0},
  {'name': '普拉提', 'met': 3.5},
  {'name': '跳绳', 'met': 11.0},
  {'name': '篮球', 'met': 6.5},
  {'name': '足球', 'met': 7.0},
  {'name': '羽毛球', 'met': 5.5},
  {'name': '乒乓球', 'met': 4.0},
  {'name': '网球', 'met': 7.3},
  {'name': '爬楼梯', 'met': 8.8},
  {'name': '跳舞（有氧）', 'met': 5.0},
  {'name': '登山/徒步', 'met': 6.0},
  {'name': '滑雪', 'met': 7.0},
  {'name': '溜冰', 'met': 7.0},
  {'name': '拳击/搏击操', 'met': 7.8},
];

class WeightRecord {
  final String id;
  final DateTime date; // 年月日
  final double weightKg;
  final DateTime? updatedAt;

  const WeightRecord({
    required this.id,
    required this.date,
    required this.weightKg,
    this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date.millisecondsSinceEpoch,
        'weight_kg': weightKg,
        'updated_at': updatedAt?.millisecondsSinceEpoch ?? 0,
      };

  factory WeightRecord.fromMap(Map<String, Object?> m) => WeightRecord(
        id: m['id'] as String,
        date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num).toInt()),
        weightKg: (m['weight_kg'] as num).toDouble(),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (m['updated_at'] as num?)?.toInt() ?? 0),
      );
}
