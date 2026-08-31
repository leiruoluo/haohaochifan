import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../engine/bmr.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// 首次启动引导：设置档案与目标（每页单屏，无需滚动）
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
  bool _customBmr = false;
  final TextEditingController _bmrCtrl = TextEditingController();
  int _step = 0;

  double get _recommendedBmr => bmrMifflinStJeor(
      gender: _gender, age: _age, heightCm: _height, weightKg: _weight);

  @override
  void dispose() {
    _bmrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  const Icon(Icons.restaurant,
                      size: 36, color: AppTheme.primary),
                  const SizedBox(height: 4),
                  const Text('好好吃饭',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink)),
                  Text('为身材管理而生的饮食记录工具',
                      style: TextStyle(fontSize: 12, color: AppTheme.inkLight)),
                  const SizedBox(height: 10),
                  Expanded(child: SingleChildScrollView(child: _stepView())),
                  const SizedBox(height: 8),
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
          const Divider(height: 16),
          Row(
            children: [
              const Text('基础代谢（BMR）',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Text('推荐 ${_recommendedBmr.round()} kcal',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.inkLight)),
            ],
          ),
          Row(
            children: [
              const Expanded(
                child: Text('自定义基础代谢',
                    style: TextStyle(fontSize: 13)),
              ),
              Switch(
                value: _customBmr,
                onChanged: (v) => setState(() => _customBmr = v),
              ),
            ],
          ),
          if (_customBmr)
            TextField(
              controller: _bmrCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: '基础代谢（kcal/天）',
                  hintText: '可填写体测/设备测得的数值',
                  suffixText: 'kcal',
                  isDense: true),
            ),
        ]);
      case 2:
        return _wrap('理想热量缺口/盈余', [
          Row(
            children: [
              const Expanded(
                  child: Text('自定义理想缺口',
                      style: TextStyle(fontSize: 13))),
              Switch(
                value: _customDeficit,
                onChanged: (v) => setState(() => _customDeficit = v),
              ),
            ],
          ),
          if (_customDeficit)
            _deficitSlider()
          else
            Text('按目标自动建议：${_suggestedFor(_goal)} kcal/天',
                style: const TextStyle(color: AppTheme.inkLight)),
          const SizedBox(height: 4),
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
                fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primary)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _seg<T>(String label, T value, List<T> options,
      ValueChanged<T> onChanged, String Function(T) labelOf) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 3),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: options
                .map((o) => ChoiceChip(
                      label: Text(labelOf(o)),
                      selected: o == value,
                      visualDensity: VisualDensity.compact,
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13))),
          SizedBox(
            width: 130,
            child: TextField(
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: value.toString()),
              onChanged: (s) {
                final v = int.tryParse(s);
                if (v != null && v >= min && v <= max) onChanged(v);
              },
              decoration: InputDecoration(
                  isDense: true, suffixText: unit),
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
      customBmrKcal: _customBmr ? double.tryParse(_bmrCtrl.text) : null,
      useCustomBmr: _customBmr,
      updatedAt: DateTime.now(),
    ));
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppShell()));
    }
  }
}
