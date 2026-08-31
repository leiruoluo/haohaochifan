import 'dart:convert';

import 'package:file_picker/file_picker.dart' show FileType;
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart'
    show FilePickerPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../engine/bmr.dart' show effectiveBmr;
import '../models/profile.dart';
import '../platform/platform_utils.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// 设置页：档案 / 目标 / 提醒 / slogan / 同步 / 数据备份
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _lanIp = '';

  @override
  void initState() {
    super.initState();
    detectLanIp().then((ip) {
      if (mounted && ip != null) setState(() => _lanIp = ip);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.profile ?? const UserProfile();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      children: [
        _section('我的档案', [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('基本信息'),
            subtitle: Text(
                '${p.gender == Gender.male ? '男' : '女'} · ${p.age}岁 · '
                '${p.heightCm.round()}cm · ${p.weightKg.round()}kg'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editProfile(context),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('身材目标'),
            subtitle: Text('${p.goal.label} · 理想缺口 ${p.effectiveIdealDeficit.round()} kcal/天'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editGoals(context),
          ),
          ListTile(
            leading: const Icon(Icons.monitor_weight_outlined),
            title: const Text('基础代谢（BMR）'),
            subtitle: Text(
                p.useCustomBmr && p.customBmrKcal != null
                    ? '自定义 ${p.customBmrKcal!.round()} kcal/天'
                    : '自动计算 ${effectiveBmr(p).round()} kcal/天（点按可改）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editBmr(context),
          ),
          ListTile(
            leading: const Icon(Icons.water_drop_outlined),
            title: const Text('每日饮水目标'),
            subtitle: Text('${p.waterTargetMl.round()} ml'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editWater(context),
          ),
        ]),
        _section('提醒', [
          SwitchListTile(
            secondary: const Icon(Icons.free_breakfast_outlined),
            title: const Text('早餐提醒 08:00'),
            value: p.remindBreakfast,
            onChanged: (v) => _saveProfile(p.copyWith(remindBreakfast: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lunch_dining_outlined),
            title: const Text('午餐提醒 12:00'),
            value: p.remindLunch,
            onChanged: (v) => _saveProfile(p.copyWith(remindLunch: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dinner_dining_outlined),
            title: const Text('晚餐提醒 18:00'),
            value: p.remindDinner,
            onChanged: (v) => _saveProfile(p.copyWith(remindDinner: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.local_drink_outlined),
            title: const Text('喝水提醒（每日3次）'),
            value: p.remindWater,
            onChanged: (v) => _saveProfile(p.copyWith(remindWater: v)),
          ),
          ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: const Text('结算提醒'),
            subtitle: Text('每日 ${p.settleHour}:${p.settleMinute.toString().padLeft(2, '0')}（点击修改时间）'),
            trailing: Switch(
              value: p.remindSettle,
              onChanged: (v) => _saveProfile(p.copyWith(remindSettle: v)),
            ),
            onTap: () => _editSettleTime(context),
          ),
        ]),
        _section('激励 slogan', [
          ListTile(
            leading: const Icon(Icons.format_quote),
            title: const Text('自定义 slogan'),
            subtitle: Text(p.slogan.isEmpty ? '未设置，使用内置轮换' : p.slogan),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editSlogan(context),
          ),
        ]),
        _section('局域网同步（手机 ↔ PC）', [
          if (state.lanServer != null) ...[
            ListTile(
              leading: const Icon(Icons.wifi, color: AppTheme.green),
              title: const Text('同步服务已开启'),
              subtitle: Text('端口 18623 · 配对码 ${state.pairingCode}'),
              trailing: OutlinedButton(
                onPressed: () => state.stopLanServer(),
                child: const Text('关闭'),
              ),
            ),
            if (_lanIp.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    QrImageView(
                      data: 'http://$_lanIp:18623/export?code=${state.pairingCode}',
                      size: 160,
                    ),
                    const SizedBox(height: 6),
                    Text('手机端打开"设置→同步"，输入地址 $_lanIp 与配对码 ${state.pairingCode}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.inkLight)),
                    const SizedBox(height: 6),
                    Text('请确保手机与电脑在同一 WiFi；首次使用需在 Windows 防火墙放行 18623 端口',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.inkLight)),
                  ],
                ),
              ),
          ] else
            ListTile(
              leading: const Icon(Icons.wifi),
              title: const Text('开启同步服务（PC 端）'),
              subtitle: const Text('生成二维码供手机扫码同步'),
              trailing: FilledButton(
                onPressed: () => state.startLanServer(),
                child: const Text('开启'),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('手机端：与电脑同步'),
            subtitle: const Text('输入电脑 IP 与配对码'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _phoneSync(context),
          ),
        ]),
        _section('数据备份', [
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('导出数据（JSON）'),
            subtitle: const Text('含全部记录、食物库、计划'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _export(context),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('导入数据（JSON）'),
            subtitle: const Text('覆盖当前数据，用于恢复备份'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _import(context),
          ),
        ]),
        _section('关于', [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('好好吃饭 v1.0.0'),
            subtitle: Text('作者：星燃 · 为身材管理而生的饮食记录工具'),
          ),
          const ListTile(
            leading: Icon(Icons.health_and_safety_outlined),
            title: Text('数据说明'),
            subtitle: Text('营养数据为公开来源估算值，消耗基于公式估算，不构成医疗建议。'),
          ),
        ]),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.inkLight)),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(children: children),
          ),
        ],
      );

  Future<void> _saveProfile(UserProfile p) =>
      context.read<AppState>().saveProfile(p);

  // ---------------- 编辑对话框 ----------------
  Future<void> _editProfile(BuildContext context) async {
    final p = context.read<AppState>().profile ?? const UserProfile();
    var gender = p.gender;
    var age = p.age;
    var height = p.heightCm;
    var weight = p.weightKg;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('基本信息'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                        label: const Text('男'),
                        selected: gender == Gender.male,
                        onSelected: (_) => setDlg(() => gender = Gender.male)),
                    ChoiceChip(
                        label: const Text('女'),
                        selected: gender == Gender.female,
                        onSelected: (_) => setDlg(() => gender = Gender.female)),
                  ],
                ),
                _numField('年龄', age, (v) => setDlg(() => age = v)),
                _numField('身高 cm', height.toInt(), (v) => setDlg(() => height = v.toDouble())),
                _numField('体重 kg', weight.toInt(), (v) => setDlg(() => weight = v.toDouble())),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _saveProfile(p.copyWith(
                    gender: gender,
                    age: age,
                    heightCm: height,
                    weightKg: weight,
                    updatedAt: DateTime.now()));
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(String label, int value, ValueChanged<int> onChanged) {
    final ctrl = TextEditingController(text: value.toString());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (s) {
          final v = int.tryParse(s);
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Future<void> _editGoals(BuildContext context) async {
    final p = context.read<AppState>().profile ?? const UserProfile();
    var goal = p.goal;
    var custom = p.useCustomDeficit;
    var deficit = p.idealDeficitKcal;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('目标设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                children: GoalType.values
                    .map((g) => ChoiceChip(
                          label: Text(g.label),
                          selected: goal == g,
                          onSelected: (_) => setDlg(() => goal = g),
                        ))
                    .toList(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('自定义理想缺口'),
                value: custom,
                onChanged: (v) => setDlg(() => custom = v),
              ),
              if (custom)
                Text('${deficit.round()} kcal/天',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary)),
              if (custom)
                Slider(
                  min: -800,
                  max: 500,
                  divisions: 26,
                  value: deficit.clamp(-800, 500),
                  onChanged: (v) => setDlg(() => deficit = v),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _saveProfile(p.copyWith(
                    goal: goal,
                    useCustomDeficit: custom,
                    idealDeficitKcal: deficit,
                    updatedAt: DateTime.now()));
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBmr(BuildContext context) async {
    final p = context.read<AppState>().profile ?? const UserProfile();
    var useCustom = p.useCustomBmr;
    final ctrl = TextEditingController(
        text: (p.customBmrKcal ?? effectiveBmr(p)).round().toString());
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('基础代谢（BMR）'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('按公式自动计算：${effectiveBmr(p).round()} kcal/天',
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.inkLight)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('使用自定义值'),
                value: useCustom,
                onChanged: (v) => setDlg(() => useCustom = v),
              ),
              if (useCustom)
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: '基础代谢（kcal/天）',
                      hintText: '可填体测/设备测得数值',
                      suffixText: 'kcal',
                      isDense: true),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _saveProfile(p.copyWith(
                  useCustomBmr: useCustom,
                  customBmrKcal:
                      useCustom ? double.tryParse(ctrl.text) : null,
                  updatedAt: DateTime.now(),
                ));
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSettleTime(BuildContext context) async {
    final p = context.read<AppState>().profile ?? const UserProfile();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: p.settleHour, minute: p.settleMinute),
      helpText: '选择每日结算提醒时间',
    );
    if (picked != null) {
      await _saveProfile(p.copyWith(
        settleHour: picked.hour,
        settleMinute: picked.minute,
        updatedAt: DateTime.now(),
      ));
    }
  }

  Future<void> _editWater(BuildContext context) async {
    final p = context.read<AppState>().profile ?? const UserProfile();
    final ctrl =
        TextEditingController(text: p.waterTargetMl.round().toString());
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('每日饮水目标（ml）'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, double.tryParse(ctrl.text)),
              child: const Text('保存')),
        ],
      ),
    );
    if (v != null && v > 0) {
      await _saveProfile(p.copyWith(waterTargetMl: v, updatedAt: DateTime.now()));
    }
  }

  Future<void> _editSlogan(BuildContext context) async {
    final p = context.read<AppState>().profile ?? const UserProfile();
    final ctrl = TextEditingController(text: p.slogan);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义 slogan'),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: '写一句激励自己的话（留空则用内置轮换）'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('保存')),
        ],
      ),
    );
    if (v != null) {
      await _saveProfile(p.copyWith(slogan: v, updatedAt: DateTime.now()));
    }
  }

  // ---------------- 同步 ----------------
  Future<void> _phoneSync(BuildContext context) async {
    final hostCtrl = TextEditingController(text: _lanIp);
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('与电脑同步'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hostCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                  labelText: '电脑 IP（同一 WiFi）', isDense: true),
            ),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: '配对码（4位，PC端显示）', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('开始同步')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final state = context.read<AppState>();
    // 进度对话框（等待同步完成）
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('正在与电脑同步…\n请确认电脑端已开启同步服务')),
            ],
          ),
        ),
      ),
    );
    await state.syncWithPc(hostCtrl.text.trim(), codeCtrl.text.trim());
    if (context.mounted) Navigator.of(context).pop(); // 关闭进度框
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.syncMessage ?? '同步完成 ✅')));
    }
  }

  // ---------------- 导出 / 导入 ----------------
  Future<void> _export(BuildContext context) async {
    final state = context.read<AppState>();
    final data = await state.exportJson();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final fileName =
        'haohaochifan_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final saved = await saveBackupFile(json, fileName);
    if (saved) {
      _toast('备份已导出 ✅');
    } else {
      _showJsonDialog(context, json);
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.isEmpty) return;
      final bytes = await result.first.readAsBytes();
      if (bytes.isEmpty) {
        _toast('读取文件失败');
        return;
      }
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入数据？'),
          content: const Text('导入将覆盖当前全部数据（记录、食物库、计划）。建议先导出一份备份。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('确认导入')),
          ],
        ),
      );
      if (ok == true) {
        await context.read<AppState>().importJson(data);
        _toast('导入完成 ✅');
      }
    } catch (e) {
      _toast('导入失败：$e');
    }
  }

  void _showJsonDialog(BuildContext context, String json) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出内容（请复制保存）'),
        content: SizedBox(
          width: 480,
          height: 320,
          child: SingleChildScrollView(
            child: SelectableText(json, style: const TextStyle(fontSize: 11)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              Navigator.pop(ctx);
              _toast('已复制到剪贴板');
            },
            child: const Text('复制'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
