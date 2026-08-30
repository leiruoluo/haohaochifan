import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;

import 'app.dart';
import 'pages/onboarding_page.dart';
import 'services/reminders.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('zh_CN');
    await ReminderService.init();
    // Android 13+ 需要运行时通知权限，提醒功能才会生效
    await ReminderService.requestPermissions();
    final state = await createAppState();
    runApp(AppRoot(state: state));
  } catch (e, st) {
    // 启动失败时显示错误信息（而不是白屏），便于定位问题
    runApp(BootErrorApp(error: '$e\n\n$st'));
  }
}

/// 启动失败兜底页：把异常信息显示出来
class BootErrorApp extends StatelessWidget {
  final String error;
  const BootErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '好好吃饭',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        appBar: AppBar(title: const Text('好好吃饭 · 启动遇到问题')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('应用启动失败，请把下面的错误信息发给开发者：',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    error,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontFamily: 'monospace'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  // 重新加载页面重试
                  if (kIsWeb) {
                    // ignore: avoid_dynamic_calls
                    web.window.location.reload();
                  } else {
                    SystemNavigator.pop();
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppRoot extends StatelessWidget {
  final AppState state;
  const AppRoot({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: '好好吃饭',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: state.profile == null ? const OnboardingPage() : const AppShell(),
      ),
    );
  }
}
