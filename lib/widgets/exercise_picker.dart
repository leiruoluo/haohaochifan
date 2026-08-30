import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exercise.dart';
import '../models/log.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/uuid.dart';

/// 弹出选择运动并填写时长，返回 ExerciseLog（取消返回 null）
Future<ExerciseLog?> showExercisePicker(BuildContext context) async {
  final result = await showModalBottomSheet<ExerciseLog>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.cream,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _ExerciseSheet(),
  );
  return result;
}

class _ExerciseSheet extends StatefulWidget {
  const _ExerciseSheet();
  @override
  State<_ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends State<_ExerciseSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.exerciseTypes.where((e) {
      if (e.deleted) return false;
      if (_query.isNotEmpty && !e.name.contains(_query)) return false;
      return true;
    }).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('添加运动',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                hintText: '搜索运动…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                ...list.map((e) => ListTile(
                      leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFE8D6),
                          child: Icon(Icons.directions_run,
                              color: AppTheme.amber)),
                      title: Text(e.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('MET ${e.met}'),
                      onTap: () => _pickMinutes(e),
                    )),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: Text('没有匹配的运动',
                            style: TextStyle(color: AppTheme.inkLight))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMinutes(ExerciseType type) async {
    final weight = context.read<AppState>().profile?.weightKg ?? 65;
    final minutesCtrl = TextEditingController(text: '30');
    var manual = false;
    var manualKcal = 0.0;

    double calc() {
      final min = double.tryParse(minutesCtrl.text) ?? 0;
      return type.estimateKcal(weight, min);
    }

    final entry = await showDialog<ExerciseLog>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(type.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minutesCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDlg(() {}),
                      decoration: const InputDecoration(
                          labelText: '时长', suffixText: '分钟', isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('手动输入消耗'),
                value: manual,
                onChanged: (v) => setDlg(() => manual = v),
              ),
              if (manual)
                TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setDlg(() => manualKcal = double.tryParse(v) ?? 0),
                  decoration: const InputDecoration(
                      labelText: '消耗（kcal）', isDense: true),
                )
              else
                Text('估算消耗 ≈ ${calc().round()} kcal',
                    style: const TextStyle(color: AppTheme.inkLight)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                ExerciseLog(
                  id: genUuid(),
                  exerciseName: type.name,
                  minutes: double.tryParse(minutesCtrl.text) ?? 0,
                  met: type.met,
                  manualKcal: manual ? manualKcal : null,
                ),
              ),
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    if (entry != null && mounted) Navigator.of(context).pop(entry);
  }
}
