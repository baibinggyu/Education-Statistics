import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';

class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> with SingleTickerProviderStateMixin {
  int _remainingSeconds = 300;
  int _totalSeconds = 300;
  bool _running = false;
  int _presetIndex = 3;
  Timer? _timer;

  final List<Map<String, dynamic>> _presets = [
    {'label': '1分钟', 'seconds': 60},
    {'label': '3分钟', 'seconds': 180},
    {'label': '5分钟', 'seconds': 300},
    {'label': '10分钟', 'seconds': 600},
    {'label': '15分钟', 'seconds': 900},
    {'label': '30分钟', 'seconds': 1800},
  ];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _timer?.cancel();
            _running = false;
          }
        });
      });
      setState(() => _running = true);
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _remainingSeconds = _totalSeconds;
    });
  }

  void _selectPreset(int index) {
    _timer?.cancel();
    setState(() {
      _running = false;
      _presetIndex = index;
      _totalSeconds = _presets[index]['seconds'] as int;
      _remainingSeconds = _totalSeconds;
    });
  }

  String get _timeText {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Scaffold(
      appBar: AppBar(title: const Text('倒计时')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(r.hPadding),
        child: Column(
          children: [
            _buildTimerCircle(context),
            SizedBox(height: r.clamped(24, 16, 32)),
            _buildPresets(context),
            SizedBox(height: r.clamped(20, 12, 28)),
            _buildControlButtons(context),
            SizedBox(height: r.clamped(24, 16, 32)),
            const SectionHeader(title: '使用场景'),
            SizedBox(height: r.clamped(8, 4, 12)),
            _buildScenarios(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCircle(BuildContext context) {
    final r = context.responsive;
    final theme = Theme.of(context);
    final progress = _totalSeconds > 0 ? _remainingSeconds / _totalSeconds : 1.0;
    final size = r.clamped(240, 180, 300);
    final isUrgent = _remainingSeconds <= 30 && _running;

    return Center(
      child: SizedBox(
        width: size, height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size, height: size,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                backgroundColor: theme.inputDecorationTheme.fillColor ?? AppColors.surfaceLight,
                valueColor: AlwaysStoppedAnimation(isUrgent ? AppColors.danger : AppColors.primary),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeText,
                  style: TextStyle(
                    fontSize: r.clamped(52, 40, 64),
                    fontWeight: FontWeight.bold,
                    color: isUrgent ? AppColors.danger : theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: r.clamped(4, 2, 6)),
                Text(
                  _running ? '运行中' : '已暂停',
                  style: TextStyle(
                    fontSize: r.clamped(13, 11, 15),
                    color: _running ? AppColors.accent : theme.textTheme.bodySmall?.color ?? AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresets(BuildContext context) {
    final r = context.responsive;
    return Wrap(
      spacing: r.clamped(10, 6, 14),
      runSpacing: r.clamped(10, 6, 14),
      alignment: WrapAlignment.center,
      children: _presets.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        final selected = _presetIndex == i;
        return GestureDetector(
          onTap: () => _selectPreset(i),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: r.clamped(16, 12, 20), vertical: r.clamped(10, 8, 12)),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withAlpha(51) : Theme.of(context).inputDecorationTheme.fillColor ?? AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(r.clamped(10, 8, 12)),
              border: Border.all(color: selected ? AppColors.primary : Theme.of(context).dividerColor),
            ),
            child: Text(
              p['label'] as String,
              style: TextStyle(
                fontSize: r.clamped(14, 12, 16),
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildControlButtons(BuildContext context) {
    final r = context.responsive;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: r.clamped(120, 100, 150),
          child: ElevatedButton(
            onPressed: _toggleTimer,
            style: ElevatedButton.styleFrom(
              backgroundColor: _running ? AppColors.warning : AppColors.primary,
            ),
            child: Text(_running ? '暂停' : '开始'),
          ),
        ),
        SizedBox(width: r.clamped(16, 12, 20)),
        SizedBox(
          width: r.clamped(120, 100, 150),
          child: ElevatedButton(
            onPressed: _reset,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).inputDecorationTheme.fillColor ?? AppColors.surfaceLight,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: const Text('重置'),
          ),
        ),
      ],
    );
  }

  Widget _buildScenarios(BuildContext context) {
    final r = context.responsive;
    final iconSize = r.clamped(44, 36, 52);
    final scenarios = [
      {'icon': Icons.menu_book, 'label': '阅读', 'color': AppColors.primary},
      {'icon': Icons.fitness_center, 'label': '练习', 'color': AppColors.accent},
      {'icon': Icons.forum, 'label': '讨论', 'color': AppColors.purple},
      {'icon': Icons.science, 'label': '实验', 'color': AppColors.warning},
      {'icon': Icons.quiz, 'label': '测验', 'color': AppColors.danger},
      {'icon': Icons.coffee, 'label': '休息', 'color': const Color(0xFF8B5CF6)},
    ];

    return Row(
      children: scenarios.map((s) {
        return Expanded(
          child: GestureDetector(
            onTap: () {},
            child: Column(
              children: [
                Container(
                  width: iconSize, height: iconSize,
                  decoration: BoxDecoration(
                    color: (s['color'] as Color).withAlpha(26),
                    borderRadius: BorderRadius.circular(r.clamped(12, 10, 14)),
                  ),
                  child: Icon(s['icon'] as IconData, color: s['color'] as Color, size: iconSize * 0.5),
                ),
                SizedBox(height: r.clamped(6, 4, 8)),
                Text(s['label'] as String, style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
