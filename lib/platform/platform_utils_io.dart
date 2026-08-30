/// 平台能力实现（Windows/Linux/Android/iOS）
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart'
    as fp;
import 'package:path_provider/path_provider.dart';

Future<String?> detectLanIp() async {
  try {
    final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    for (final i in interfaces) {
      for (final a in i.addresses) {
        if (a.isLoopback) continue;
        if (a.address.startsWith('192.168.') ||
            a.address.startsWith('10.') ||
            a.address.startsWith('172.')) {
          return a.address;
        }
      }
    }
  } catch (_) {}
  return null;
}

Future<bool> saveBackupFile(String content, String fileName) async {
  try {
    if (Platform.isAndroid) {
      final dir = await getDownloadsDirectory();
      if (dir == null) return false;
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content);
      return true;
    }
    // Windows/Linux/Web：调用系统保存对话框（Web 触发浏览器下载）
    final uri = await fp.FilePickerPlatform.instance.saveFile(
      dialogTitle: '导出备份',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(content)),
      mimeType: 'application/json',
    );
    return uri != null;
  } catch (_) {
    return false;
  }
}
