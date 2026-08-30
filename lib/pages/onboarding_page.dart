import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../app.dart';

/// 首次启动引导：设置档案与目标
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  Gender _gender = Gender.male;
  int _age = 25;
  double _height = 170;
  double _weight = 65;
  ActivityLevel _activity = ActivityLevel.light;
  GoalType _goal = GoalType.cut;
  bool _customDeficit = true;
  double _deficit = -300;
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  const Icon(Icons.restaurant,
                      size: 64, color: AppTheme.primary),
                  const SizedBox(height: 12),
                  const Text('好好吃饭',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink)),
                  const SizedBox(height: 6),
                  Text('为身材管理而生的饮食记录工具',
                      style: TextStyle(color: AppTheme.inkLight)),
                  const SizedBox(height: 32),
                  Expanded(child: _stepView()),
                  const SizedBox(height: 16),
                  _bottomBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepView() {
    switch (_step) {
      case 0:
        return _wrap('基本信息', [
          _seg<Gender>('性别', _gender, Gender.values,
              (v) => setState(() => _gender = v), (g) => g == Gender.male ? '男' : '女'),
          _num('年龄', _age, 10, 100, (v) => setState(() => _age = v), '岁'),
          _num('身高', _height.toInt(), 120, 220, (v) => setState(() => _height = v.toDouble()), 'cm'),
          _num('体重', _weight.toInt(), 30, 250, (v) => setState(() => _weight = v.toDouble()), 'kg'),
        ]);
      case 1:
        return _wrap('活动水平与目标', [
          _seg<ActivityLevel>('日常活动', _activity, ActivityLevel.values,
              (v) => setState(() => _activity = v), (a) => a.label),
          _seg<GoalType>('身材目标', _goal, GoalType.values,
              (v) => setState(() => _goal = v), (g) => g.label),
        ]);
      case 2:
        return _wrap('理想热量缺口/盈余', [
          SwitchListTile(
            title: const Text('自定义理想缺口'),
            value: _customDeficit,
            onChanged: (v) => setState(() => _customDeficit = v),
          ),
          if (_customDeficit)
            _deficitSlider()
          else
            Text('按目标自动建议：${_suggestedFor(_goal)} kcal/天',
                style: const TextStyle(color: AppTheme.inkLight)),
          const SizedBox(height: 8),
          const Text('缺口 = 摄入 −（日常活动消耗 + 运动消耗）。\n负数为缺口（减脂），正数为盈余（增肌）。',
              style: TextStyle(fontSize: 12, color: AppTheme.inkLight)),
        ]);
      default:
        return const SizedBox();
    }
  }

  String _suggestedFor(GoalType g) =>
      g == GoalType.cut ? '-400' : (g == GoalType.bulk ? '+250' : '0');

  Widget _deficitSlider() {
    return Column(
      children: [
        Text('${_deficit >= 0 ? '+' : ''}${_deficit.toInt()} kcal/天',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary)),
        Slider(
          min: -800,
          max: 500,
          divisions: 26,
          label: _deficit.toString(),
          value: _deficit.clamp(-800, 500),
          onChanged: (v) => setState(() => _deficit = v),
        ),
      ],
    );
  }

  Widget _wrap(String title, List<Widget> children) {
    return ListView(
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _seg<T>(String label, T value, List<T> options,
      ValueChanged<T> onChanged, String Function(T) labelOf) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: options
                .map((o) => ChoiceChip(
                      label: Text(labelOf(o)),
                      selected: o == value,
                      onSelected: (_) => onChanged(o),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _num(String label, int value, int min, int max,
      ValueChanged<int> onChanged, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          SizedBox(
            width: 150,
            child: TextField(
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: value.toString()),
              onChanged: (s) {
                final v = int.tryParse(s);
                if (v != null && v >= min && v <= max) onChanged(v);
              },
              decoration: InputDecoration(suffixText: unit),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Row(
      children: [
        if (_step > 0)
          OutlinedButton(
              onPressed: () => setState(() => _step--), child: const Text('上一步')),
        const Spacer(),
        if (_step < 2)
          FilledButton(
              onPressed: () => setState(() => _step++), child: const Text('下一步'))
        else
          FilledButton(onPressed: _finish, child: const Text('开始使用')),
      ],
    );
  }

  Future<void> _finish() async {
    final state = context.read<AppState>();
    await state.saveProfile(UserProfile(
      gender: _gender,
      age: _age,
      heightCm: _height,
      weightKg: _weight,
      activity: _activity,
      goal: _goal,
      useCustomDeficit: _customDeficit,
      idealDeficitKcal: _deficit,
      updatedAt: DateTime.now(),
    ));
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppShell()));
    }
  }
}
