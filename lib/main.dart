import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'pages/onboarding_page.dart';
import 'services/reminders.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');
  await ReminderService.init();
  // Android 13+ 需要运行时通知权限，提醒功能才会生效
  await ReminderService.requestPermissions();
  final state = await createAppState();
  runApp(AppRoot(state: state));
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
