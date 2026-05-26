import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../services/report_service.dart';

class ReportHistoryPage extends StatefulWidget {
  const ReportHistoryPage({super.key});

  @override
  State<ReportHistoryPage> createState() => _ReportHistoryPageState();
}

class _ReportHistoryPageState extends State<ReportHistoryPage> {
  final _service = ReportService();
  List<SavedReport> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reports = await _service.loadAll();
    if (mounted) setState(() { _reports = reports; _loading = false; });
  }

  Future<void> _delete(String id) async {
    await _service.delete(id);
    _load();
  }

  Future<void> _deleteAll() async {
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: const Text('确认清空'),
        body: const Text('将删除所有历史报告，不可恢复。'),
        actions: [
          FButton(onPress: () => Navigator.pop(context, false), variant: FButtonVariant.ghost, child: const Text('取消')),
          FButton(onPress: () => Navigator.pop(context, true), variant: FButtonVariant.destructive, child: const Text('清空')),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteAll();
      _load();
    }
  }

  Future<void> _export(SavedReport report) async {
    try {
      final path = await _service.exportToFile(report);
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

  void _viewDetail(SavedReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailPage(report: report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;

    return Container(
      color: colors.background,
      child: SafeArea(
        child: Column(
          children: [
            FHeader.nested(
              title: const Text('报告历史'),
              prefixes: [
                FButton.icon(
                  onPress: () => Navigator.pop(context),
                  variant: FButtonVariant.ghost,
                  child: const Icon(FIcons.arrowLeft),
                ),
              ],
              suffixes: [
                if (_reports.isNotEmpty)
                  FButton.icon(
                    onPress: _deleteAll,
                    variant: FButtonVariant.ghost,
                    child: const Icon(FIcons.trash),
                  ),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: FCircularProgress())
                  : _reports.isEmpty
                      ? _buildEmpty(r, colors)
                      : _buildList(r, colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(Responsive r, AppColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FIcons.fileText, size: 48, color: colors.textMuted),
          SizedBox(height: r.clamped(12, 8, 16)),
          Text('暂无历史报告',
              style: AppTextStyles.scaled(AppTextStyles.body, r.scale)),
          SizedBox(height: r.clamped(4, 2, 6)),
          Text('生成学习报告或学情分析后会自动保存',
              style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
        ],
      ),
    );
  }

  Widget _buildList(Responsive r, AppColors colors) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: r.clamped(8, 4, 12)),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        final icon =
            report.type == 'student-analysis' ? FIcons.user : FIcons.trendingUp;
        final typeLabel =
            report.type == 'student-analysis' ? '学情分析' : '学习报告';

        return Dismissible(
          key: Key(report.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: r.hPadding),
            color: AppColors.danger,
            child: const Icon(FIcons.trash, color: Colors.white),
          ),
          onDismissed: (_) => _delete(report.id),
          child: FTile(
            onPress: () => _viewDetail(report),
            prefix: Icon(icon, color: AppColors.primary, size: r.clamped(22, 20, 26)),
            title: Text(report.title,
                style: AppTextStyles.scaled(AppTextStyles.body, r.scale)),
            subtitle: Text(
              '$typeLabel · ${_formatDate(report.createdAt)}',
              style: AppTextStyles.scaled(AppTextStyles.small, r.scale),
            ),
            suffix: FButton.icon(
              onPress: () => _export(report),
              variant: FButtonVariant.ghost,
              child: Icon(FIcons.download, size: r.clamped(18, 16, 20), color: colors.textMuted),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${_p(dt.month)}-${_p(dt.day)} ${_p(dt.hour)}:${_p(dt.minute)}';
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}

// -------------------------------------------------------
// Report Detail Page (view saved report)
// -------------------------------------------------------
class ReportDetailPage extends StatelessWidget {
  final SavedReport report;
  const ReportDetailPage({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;

    return Container(
      color: colors.background,
      child: SafeArea(
        child: Column(
          children: [
            FHeader.nested(
              title: Text(report.title),
              prefixes: [
                FButton.icon(
                  onPress: () => Navigator.pop(context),
                  variant: FButtonVariant.ghost,
                  child: const Icon(FIcons.arrowLeft),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
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
                      child: _renderMarkdown(report.content, r, colors),
                    ),
                    if (report.model.isNotEmpty) ...[
                      SizedBox(height: r.clamped(12, 8, 16)),
                      Text('模型: ${report.model}',
                          style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
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
          padding: EdgeInsets.only(top: r.clamped(16, 10, 20), bottom: r.clamped(6, 4, 8)),
          child: Text(title,
              style: TextStyle(
                  fontSize: r.clamped(16, 14, 18),
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
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
            style: const TextStyle(fontWeight: FontWeight.bold)));
        remaining = remaining.substring(end + 2);
      }
      if (remaining.isNotEmpty) {
        parts.add(TextSpan(text: remaining));
      }

      children.add(Padding(
        padding: EdgeInsets.only(bottom: r.clamped(4, 2, 6)),
        child: Text.rich(
          TextSpan(
            style: TextStyle(fontSize: bodySize, color: colors.text),
            children: parts.isEmpty ? [TextSpan(text: trimmed)] : parts,
          ),
        ),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
