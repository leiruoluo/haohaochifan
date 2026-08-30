// CI 工作流 YAML 语法校验
import 'dart:io';
import 'package:yaml/yaml.dart';

void main(List<String> args) {
  final f = File(args.isNotEmpty
      ? args.first
      : '.github/workflows/build-deploy.yml');
  final content = f.readAsStringSync();
  try {
    final doc = loadYaml(content) as Map;
    final jobs = (doc['jobs'] as Map).keys.toList();
    print('YAML 解析成功 ✅');
    print('jobs: $jobs');
    // 关键字段抽查
    for (final j in jobs) {
      final jm = doc['jobs'][j] as Map;
      print('  $j: runs-on=${jm['runs-on']}, steps=${(jm['steps'] as List).length}');
    }
    final needs = (doc['jobs']['deploy-pages'] as Map)['needs'];
    print('deploy-pages needs: $needs');
  } catch (e) {
    print('YAML 解析失败 ❌: $e');
    exit(1);
  }
}
