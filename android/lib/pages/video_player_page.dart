import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';

class VideoPlayerPage extends StatelessWidget {
  const VideoPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频播放')),
      body: Column(
        children: [
          _buildVideoArea(context),
          _buildProgressBar(context),
          _buildControls(context),
          const Divider(),
          _buildSubtitleSettings(context),
          const Divider(),
          const SectionHeader(title: '章节列表'),
          Expanded(child: _buildChapterList(context)),
        ],
      ),
    );
  }

  Widget _buildVideoArea(BuildContext context) {
    final r = context.responsive;
    return Container(
      height: r.clamped(220, 160, 280),
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(51),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 38),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success)),
                  const SizedBox(width: 6),
                  const Text('AI 智能字幕', style: TextStyle(fontSize: 11, color: Colors.white70)),
                  const SizedBox(width: 8),
                  const Text('这是演示用字幕文本示例', style: TextStyle(fontSize: 13, color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final r = context.responsive;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding, vertical: r.clamped(8, 4, 12)),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Theme.of(context).inputDecorationTheme.fillColor ?? AppColors.surfaceLight,
              thumbColor: AppColors.primary,
            ),
            child: const Slider(value: 0.35, onChanged: null),
          ),
          const Row(
            children: [
              Text('12:30', style: AppTextStyles.small),
              Spacer(),
              Text('35:20', style: AppTextStyles.small),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final r = context.responsive;
    final iconSize = r.clamped(28, 24, 32);
    final playSize = r.clamped(44, 38, 50);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding, vertical: r.clamped(8, 4, 12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon(Icons.replay_10, size: iconSize),
          Icon(Icons.skip_previous, size: iconSize),
          Container(
            width: playSize, height: playSize,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(playSize / 2),
            ),
            child: Icon(Icons.pause, color: Colors.white, size: playSize * 0.55),
          ),
          Icon(Icons.skip_next, size: iconSize),
          Icon(Icons.forward_10, size: iconSize),
        ],
      ),
    );
  }

  Widget _buildSubtitleSettings(BuildContext context) {
    final r = context.responsive;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding, vertical: r.clamped(8, 4, 12)),
      child: Row(
        children: [
          _buildSettingChip(context, '中文字幕'),
          const SizedBox(width: 8),
          _buildSettingChip(context, '字号 中'),
          const SizedBox(width: 8),
          _buildSettingChip(context, '显示字幕'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(26),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.success.withAlpha(77)),
            ),
            child: const Text('AI 已启用', style: TextStyle(fontSize: 10, color: AppColors.success)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor ?? AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: AppTextStyles.small),
    );
  }

  Widget _buildChapterList(BuildContext context) {
    final r = context.responsive;
    final iconSize = r.clamped(40, 34, 48);
    final chapters = [
      {'no': '1-1', 'title': '绪论 · 课程介绍', 'duration': '15:30', 'watched': true},
      {'no': '1-2', 'title': '半导体物理基础', 'duration': '22:15', 'watched': true},
      {'no': '2-1', 'title': 'PN结原理', 'duration': '18:40', 'watched': false},
      {'no': '2-2', 'title': '二极管特性分析', 'duration': '28:50', 'watched': false},
      {'no': '3-1', 'title': '三极管基本工作原理', 'duration': '35:10', 'watched': false},
      {'no': '3-2', 'title': '共射极放大电路', 'duration': '42:20', 'watched': false},
    ];

    return ListView.separated(
      padding: EdgeInsets.all(r.hPadding),
      itemCount: chapters.length,
      separatorBuilder: (_, _) => SizedBox(height: r.clamped(8, 6, 10)),
      itemBuilder: (context, index) {
        final ch = chapters[index];
        return GlassCard(
          padding: EdgeInsets.all(r.clamped(12, 8, 16)),
          child: Row(
            children: [
              Container(
                width: iconSize, height: iconSize,
                decoration: BoxDecoration(
                  color: (ch['watched'] as bool) ? AppColors.accent.withAlpha(26) : AppColors.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(r.clamped(8, 6, 10)),
                ),
                child: Text(ch['no'] as String, textAlign: TextAlign.center, style: TextStyle(fontSize: r.clamped(10, 9, 12), fontWeight: FontWeight.bold, color: (ch['watched'] as bool) ? AppColors.accent : AppColors.primary)),
              ),
              SizedBox(width: r.clamped(12, 8, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ch['title'] as String, style: AppTextStyles.bodyBold),
                    Text('时长 ${ch['duration'] as String}', style: AppTextStyles.small),
                  ],
                ),
              ),
              Icon(
                ch['watched'] as bool ? Icons.check_circle : Icons.play_circle_outline,
                color: (ch['watched'] as bool) ? AppColors.accent : Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        );
      },
    );
  }
}
