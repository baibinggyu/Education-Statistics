import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../services/api_client.dart';
import '../services/report_service.dart';

class LearningReportPage extends StatefulWidget {
  const LearningReportPage({super.key});

  @override
  State<LearningReportPage> createState() => _LearningReportPageState();
}

class _LearningReportPageState extends State<LearningReportPage> {
  final _api = ApiClient();
  final _reportService = ReportService();
  bool _loading = true;
  String? _report;
  String? _error;
  String _model = '';

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    setState(() { _loading = true; _error = null; _report = null; });

    try {
      // Gather learning data
      final buf = StringBuffer();
      final courses = await _api.listCourses();
      buf.writeln('用户已注册课程总数: ${courses.length} 门');
      buf.writeln();

      var totalVideosAll = 0;
      var totalCompletedAll = 0;
      var totalMessagesAll = 0;
      var totalUnreadAll = 0;

      for (final c in courses) {
        final name = c['name'] as String? ?? '';
        final uuid = c['uuid'] as String;
        buf.writeln('--- 课程: $name ---');

        // Video progress
        try {
          final records = await _api.getMyCoursePlayRecords(uuid);
          final total = records.length;
          final completed =
              records.where((r) => (r['completed'] as bool? ?? false)).length;
          totalVideosAll += total;
          totalCompletedAll += completed;
          final pct = total > 0 ? (completed * 100 ~/ total) : 0;
          buf.writeln('视频总数: $total 个');
          buf.writeln('已完成: $completed 个');
          buf.writeln('完成率: $pct%');
          if (total > 0 && completed < total) {
            buf.writeln('未完成视频: ${total - completed} 个，需继续学习');
          }
        } catch (_) {
          buf.writeln('视频数据: 暂无记录');
        }

        // Scores
        try {
          final scores = await _api.getMyScores(uuid);
          final units = (scores['units'] as List?) ?? [];
          final myScores = (scores['my_scores'] as List?) ?? [];
          final weightedTotal = scores['weighted_total'];
          final rank = scores['rank'];
          if (units.isNotEmpty && myScores.isNotEmpty) {
            buf.writeln('考核成绩:');
            for (var si = 0; si < myScores.length && si < units.length; si++) {
              final unit = units[si] as Map<String, dynamic>;
              final unitName = unit['name'] ?? '单元${si + 1}';
              final fullScore = unit['full_score'] ?? 100;
              final score = (myScores[si] as Map<String, dynamic>?)?['score'];
              if (score != null) {
                final scorePct =
                    (score as double) / (fullScore as double) * 100;
                buf.writeln(
                    '  $unitName: ${score.toStringAsFixed(1)}/${fullScore} (${scorePct.toStringAsFixed(0)}%)');
              } else {
                buf.writeln('  $unitName: 未录入');
              }
            }
            if (weightedTotal != null) {
              buf.writeln('加权总分: ${weightedTotal.toStringAsFixed(1)}');
            }
            if (rank != null) {
              buf.writeln('班级排名: 第 $rank 名');
            }
          }
        } catch (_) {
          buf.writeln('成绩数据: 暂无');
        }

        // Messages
        try {
          final msgs = await _api.listMessages(uuid);
          final unread = msgs.where((m) =>
              (m['is_read'] as bool? ?? true) == false).length;
          totalMessagesAll += msgs.length;
          totalUnreadAll += unread;
          buf.writeln('课程消息: ${msgs.length} 条, 其中未读 $unread 条');
        } catch (_) {}

        // Attendance summary
        try {
          final atts = await _api.listAttendances(uuid);
          if (atts.isNotEmpty) {
            var present = 0;
            var total = 0;
            for (final a in atts) {
              total++;
              if ((a['status'] as String? ?? '') == 'closed') {
                try {
                  final detail = await _api.getAttendanceDetail(uuid, a['uuid'] as String);
                  final records = (detail['records'] as List?) ?? [];
                  for (final r in records) {
                    if (r['status'] == 'present') present++;
                  }
                } catch (_) {}
              }
            }
            buf.writeln('签到次数: $total 次, 已出席: $present 次');
          }
        } catch (_) {}

        buf.writeln();
      }

      // Overall stats
      buf.writeln('=== 汇总数据 ===');
      buf.writeln('课程总数: ${courses.length}');
      buf.writeln('视频总数: $totalVideosAll 个, 已完成: $totalCompletedAll 个');
      final overallPct = totalVideosAll > 0
          ? (totalCompletedAll * 100 ~/ totalVideosAll)
          : 0;
      buf.writeln('整体视频完成率: $overallPct%');
      buf.writeln('消息总数: $totalMessagesAll 条, 未读: $totalUnreadAll 条');

      // Send to server, which forwards to DeepSeek
      final result = await _api.generateLearningReport(buf.toString());
      _report = result['content'] as String? ?? '';
      _model = result['model'] as String? ?? '';

      // Auto-save to history
      if (_report!.isNotEmpty) {
        try {
          await _reportService.save(
            type: 'learning-report',
            title: '学习报告',
            content: _report!,
            model: _model,
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _loading = false);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = e.message; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = '网络错误: $e'; });
      }
    }
  }

  Future<void> _exportReport() async {
    if (_report == null || _report!.isEmpty) return;
    try {
      final path = await _reportService.exportToFileFromContent(
        title: '学习报告',
        content: _report!,
        model: _model,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('已导出到: $path'),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('导出失败: $e'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;
    final hasReport = _report != null && _report!.isNotEmpty;

    return Container(
      color: colors.background,
      child: SafeArea(
        child: Column(
          children: [
            FHeader.nested(
              title: const Text('学习报告'),
              prefixes: [
                FButton.icon(
                  onPress: () => Navigator.pop(context),
                  variant: FButtonVariant.ghost,
                  child: const Icon(FIcons.arrowLeft),
                ),
              ],
              suffixes: [
                if (hasReport)
                  FButton.icon(
                    onPress: _exportReport,
                    variant: FButtonVariant.ghost,
                    child: const Icon(FIcons.download),
                  ),
                FButton.icon(
                  onPress: _generateReport,
                  variant: FButtonVariant.ghost,
                  child: const Icon(FIcons.refreshCw),
                ),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: FCircularProgress())
                  : _error != null
                      ? _buildError(r, colors)
                      : _buildReport(r, colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Responsive r, AppColors colors) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.hPadding * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FIcons.triangleAlert, size: 48, color: colors.textMuted),
            const SizedBox(height: 16),
            Text(_error!,
                style: AppTextStyles.scaled(AppTextStyles.body, r.scale),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FButton(
              onPress: _generateReport,
              variant: FButtonVariant.primary,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(Responsive r, AppColors colors) {
    if (_report == null || _report!.isEmpty) {
      return Center(
        child: Text('暂无报告',
            style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.hPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(r.clamped(20, 14, 28)),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(r.radius),
              border: Border.all(color: colors.border),
            ),
            child: _renderMarkdown(_report!, r, colors),
          ),
          if (_model.isNotEmpty) ...[
            SizedBox(height: r.clamped(12, 8, 16)),
            Text('模型: $_model',
                style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
          ],
        ],
      ),
    );
  }

  Widget _renderMarkdown(String text, Responsive r, AppColors colors) {
    final lines = text.split('\n');
    final children = <Widget>[];
    final bodySize = r.clamped(14, 12, 16);

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        children.add(SizedBox(height: r.clamped(10, 6, 14)));
        continue;
      }

      // Heading: **文本** on a line by itself
      if (trimmed.startsWith('**') && trimmed.endsWith('**')) {
        final title = trimmed.substring(2, trimmed.length - 2);
        children.add(Padding(
          padding: EdgeInsets.only(
              top: r.clamped(16, 10, 20), bottom: r.clamped(6, 4, 8)),
          child: Text(
            title,
            style: TextStyle(
              fontSize: r.clamped(16, 14, 18),
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ));
        continue;
      }

      // Inline bold parsing
      final parts = <TextSpan>[];
      var remaining = trimmed;
      while (remaining.contains('**')) {
        final start = remaining.indexOf('**');
        final end = remaining.indexOf('**', start + 2);
        if (end == -1) break;
        if (start > 0) {
          parts.add(TextSpan(text: remaining.substring(0, start)));
        }
        parts.add(TextSpan(
          text: remaining.substring(start + 2, end),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
        remaining = remaining.substring(end + 2);
      }
      if (remaining.isNotEmpty) {
        parts.add(TextSpan(text: remaining));
      }

      children.add(Padding(
        padding: EdgeInsets.only(bottom: r.clamped(4, 2, 6)),
        child: Text.rich(
          TextSpan(
            style: TextStyle(
                fontSize: bodySize, color: colors.text),
            children: parts.isEmpty ? [TextSpan(text: trimmed)] : parts,
          ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
