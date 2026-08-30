/// 平台能力接口（web 端空实现）
library;

/// 检测局域网 IP（web 端无法获取，返回 null）
Future<String?> detectLanIp() async => null;

/// 保存备份文件到本机；web 端返回 false（由调用方降级为剪贴板）
Future<bool> saveBackupFile(String content, String fileName) async => false;
