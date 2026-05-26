import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../services/api_client.dart';
import '../services/report_service.dart';

class StudentAnalysisPage extends StatefulWidget {
  final String courseUuid;
  final String studentUuid;
  final String studentName;
  const StudentAnalysisPage({
    super.key,
    required this.courseUuid,
    required this.studentUuid,
    required this.studentName,
  });

  @override
  State<StudentAnalysisPage> createState() => _StudentAnalysisPageState();
}

class _StudentAnalysisPageState extends State<StudentAnalysisPage> {
  final _api = ApiClient();
  final _reportService = ReportService();
  bool _loading = true;
  String? _report;
  String? _error;
  String _model = '';

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });

    try {
      final buf = StringBuffer();
      buf.writeln('姓名: ${widget.studentName}');

      // Course info + scores
      try {
        final summary =
            await _api.getScoreSummary(widget.courseUuid);
        buf.writeln('课程: ${summary['course_name'] ?? ''}');
        final unitNames = (summary['unit_names'] as List?)?.cast<String>() ?? [];
        buf.writeln('考核单元: ${unitNames.join(', ')}');

        final students = (summary['students'] as List?) ?? [];
        Map<String, dynamic>? target;
        for (final s in students) {
          if (s['student_uuid'] == widget.studentUuid) {
            target = s as Map<String, dynamic>;
            break;
          }
        }
        if (target != null) {
          final scores = (target['scores'] as List?) ?? [];
          buf.writeln('各单元成绩:');
          for (var i = 0; i < unitNames.length; i++) {
            final score =
                i < scores.length ? scores[i] : null;
            buf.writeln(
                '  ${unitNames[i]}: ${score != null ? score.toStringAsFixed(1) : "未录入"}');
          }
          final total = target['weighted_total'];
          final rank = target['rank'];
          if (total != null) buf.writeln('加权总分: ${total.toStringAsFixed(1)}');
          if (rank != null) buf.writeln('班级排名: 第 $rank 名');
        }
      } catch (_) {}

      // Attendance
      try {
        final attendances =
            await _api.listAttendances(widget.courseUuid);
        if (attendances.isNotEmpty) {
          var presentCount = 0;
          var absentCount = 0;
          var lateCount = 0;
          final total = attendances.length;
          for (final a in attendances) {
            try {
              final detail = await _api.getAttendanceDetail(
                  widget.courseUuid, a['uuid'] as String);
              final records =
                  (detail['records'] as List?) ?? [];
              for (final r in records) {
                if (r['student_uuid'] == widget.studentUuid) {
                  final st = r['status'] as String? ?? '';
                  if (st == 'present') presentCount++;
                  if (st == 'absent') absentCount++;
                  if (st == 'late') lateCount++;
                }
              }
            } catch (_) {}
          }
          buf.writeln();
          buf.writeln(
              '出勤: 共 $total 次, 出席 $presentCount, 缺勤 $absentCount, 迟到 $lateCount');
        }
      } catch (_) {}

      // Video count for the course
      try {
        final videos =
            await _api.listVideos(widget.courseUuid);
        buf.writeln('课程视频总数: ${videos.length}');
      } catch (_) {}

      final result =
          await _api.analyzeStudent(buf.toString());
      _report = result['content'] as String? ?? '';
      _model = result['model'] as String? ?? '';

      // Auto-save to history
      if (_report!.isNotEmpty) {
        try {
          await _reportService.save(
            type: 'student-analysis',
            title: '${widget.studentName} 学情分析',
            content: _report!,
            model: _model,
            studentName: widget.studentName,
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _loading = false);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '网络错误: $e';
        });
      }
    }
  }

  Future<void> _exportReport() async {
    if (_report == null || _report!.isEmpty) return;
    try {
      final path = await _reportService.exportToFileFromContent(
        title: '${widget.studentName} 学情分析',
        content: _report!,
        model: _model,
        studentName: widget.studentName,
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
              title: Text(widget.studentName),
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
                  onPress: _analyze,
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
              onPress: _analyze,
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
        child: Text('暂无分析报告',
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
                style:
                    AppTextStyles.scaled(AppTextStyles.small, r.scale)),
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
            style:
                TextStyle(fontSize: bodySize, color: colors.text),
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
