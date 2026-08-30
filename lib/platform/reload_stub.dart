/// 非 Web 平台：重启页面退化为退出应用
library;

import 'package:flutter/services.dart' show SystemNavigator;

void reloadPage() {
  // Android：退出应用；桌面端无操作（错误页极少出现）
  SystemNavigator.pop();
}
