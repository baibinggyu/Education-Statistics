import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_provider.dart';

class MyHomeworkPage extends StatefulWidget {
  final AuthProvider auth;
  const MyHomeworkPage({super.key, required this.auth});

  @override
  State<MyHomeworkPage> createState() => _MyHomeworkPageState();
}

class _MyHomeworkPageState extends State<MyHomeworkPage> {
  bool _loading = true;
  List<_AssignmentEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadAllAssignments();
  }

  Future<void> _loadAllAssignments() async {
    setState(() { _loading = true; _entries = []; });
    try {
      final courses = await widget.auth.api.listCourses();
      final entries = <_AssignmentEntry>[];

      for (final c in courses) {
        final courseUuid = c['uuid'] as String;
        final courseName = c['name'] as String? ?? '';
        try {
          final assignments =
              await widget.auth.api.listAssignments(courseUuid);
          for (final a in assignments) {
            final aUuid = a['uuid'] as String;
            Map<String, dynamic>? sub;
            try {
              final s = await widget.auth.api
                  .getMySubmission(courseUuid, aUuid);
              if (s is Map<String, dynamic>) sub = s;
            } catch (_) {}

            entries.add(_AssignmentEntry(
              courseUuid: courseUuid,
              courseName: courseName,
              assignment: Map<String, dynamic>.from(a),
              submission: sub,
            ));
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() { _entries = entries; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
              title: const Text('我的作业'),
              prefixes: [
                FButton.icon(
                  onPress: () => Navigator.pop(context),
                  variant: FButtonVariant.ghost,
                  child: const Icon(FIcons.arrowLeft),
                ),
              ],
              suffixes: [
                FButton.icon(
                  onPress: _loadAllAssignments,
                  variant: FButtonVariant.ghost,
                  child: const Icon(FIcons.refreshCw),
                ),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: FCircularProgress())
                  : _entries.isEmpty
                      ? Center(
                          child: Text('暂无作业',
                              style: AppTextStyles.scaled(
                                  AppTextStyles.caption, r.scale)),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.hPadding,
                              vertical: r.clamped(8, 4, 12)),
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final e = _entries[index];
                            final a = e.assignment;
                            final title = a['title'] as String? ?? '';
                            final dueDate = a['due_date'] as String?;
                            final sub = e.submission;
                            final bool isSubmitted =
                                sub != null && sub['submitted'] != false;
                            final bool isGraded =
                                isSubmitted && sub['status'] == 'graded';
                            final double? score =
                                isGraded ? (sub['score'] as num?)?.toDouble() : null;
                            final subLabel = isGraded
                                ? '${score?.toStringAsFixed(0) ?? "?"}分'
                                : (isSubmitted ? '已提交' : '待提交');
                            final subColor = isGraded
                                ? AppColors.success
                                : (isSubmitted
                                    ? AppColors.warning
                                    : AppColors.danger);

                            return Padding(
                              padding:
                                  EdgeInsets.only(bottom: r.clamped(8, 6, 10)),
                              child: GlassCard(
                                padding:
                                    EdgeInsets.all(r.clamped(12, 8, 16)),
                                onTap: () {
                                  Navigator.pushNamed(context,
                                      '/submit-homework', arguments: {
                                    'courseUuid': e.courseUuid,
                                    'assignmentUuid': a['uuid'] as String,
                                    'assignment': a,
                                  }).then((_) => _loadAllAssignments());
                                },
                                child: Row(
                                  children: [
                                    Container(
                                      width: r.clamped(42, 36, 48),
                                      height: r.clamped(42, 36, 48),
                                      decoration: BoxDecoration(
                                        color: subColor.withAlpha(26),
                                        borderRadius: BorderRadius.circular(
                                            r.clamped(10, 8, 12)),
                                      ),
                                      child: Icon(
                                        isGraded
                                            ? FIcons.check
                                            : (isSubmitted
                                                ? FIcons.clock
                                                : FIcons.triangleAlert),
                                        color: subColor,
                                        size: r.clamped(20, 16, 24),
                                      ),
                                    ),
                                    SizedBox(width: r.clamped(12, 8, 16)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(title,
                                              style: AppTextStyles.scaled(
                                                  AppTextStyles.bodyBold,
                                                  r.scale)),
                                          SizedBox(
                                              height: r.clamped(4, 2, 6)),
                                          Text(e.courseName,
                                              style: AppTextStyles.scaled(
                                                  AppTextStyles.small,
                                                  r.scale)),
                                          if (dueDate != null) ...[
                                            SizedBox(
                                                height: r.clamped(2, 1, 4)),
                                            Text('截止: $_formatDate(dueDate)',
                                                style: TextStyle(
                                                    fontSize: r.clamped(
                                                        10, 9, 11),
                                                    color: _isOverdue(
                                                            dueDate, a['status'] as String?)
                                                        ? AppColors.danger
                                                        : colors.textMuted)),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: subColor.withAlpha(26),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(subLabel,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: subColor)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isOverdue(String dueDate, String? status) {
    if (status == 'closed') return false;
    try {
      return DateTime.parse(dueDate).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _AssignmentEntry {
  final String courseUuid;
  final String courseName;
  final Map<String, dynamic> assignment;
  final Map<String, dynamic>? submission;

  _AssignmentEntry({
    required this.courseUuid,
    required this.courseName,
    required this.assignment,
    this.submission,
  });
}
