import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_provider.dart';

class SubmitHomeworkPage extends StatefulWidget {
  final AuthProvider auth;
  final String courseUuid;
  final String assignmentUuid;
  final Map<String, dynamic> assignment;

  const SubmitHomeworkPage({
    super.key,
    required this.auth,
    required this.courseUuid,
    required this.assignmentUuid,
    required this.assignment,
  });

  @override
  State<SubmitHomeworkPage> createState() => _SubmitHomeworkPageState();
}

class _SubmitHomeworkPageState extends State<SubmitHomeworkPage> {
  final TextEditingController _contentCtrl = TextEditingController();
  String? _filePath;
  String? _fileName;
  bool _loading = true;
  bool _submitting = false;
  Map<String, dynamic>? _mySubmission;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final sub = await widget.auth.api.getMySubmission(
          widget.courseUuid, widget.assignmentUuid);
      if (mounted) {
        setState(() {
          _mySubmission =
              (sub is Map && sub['submitted'] != false)
                  ? Map<String, dynamic>.from(sub)
                  : null;
          _loading = false;
          if (_mySubmission != null && _mySubmission!['content'] != null) {
            _contentCtrl.text = _mySubmission!['content'] as String;
          }
          if (_mySubmission != null && _mySubmission!['file_name'] != null) {
            _fileName = _mySubmission!['file_name'] as String;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty && _filePath == null) return;

    setState(() => _submitting = true);
    try {
      final result = await widget.auth.api.submitHomework(
        widget.courseUuid,
        widget.assignmentUuid,
        content: content,
        filePath: _filePath,
        fileName: _fileName,
      );
      if (mounted) {
        setState(() {
          _submitting = false;
          _mySubmission = result;
          _contentCtrl.text = content;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _pickFile() {
    final pathCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加附件'),
        content: TextField(
          controller: pathCtrl,
          decoration: const InputDecoration(
            hintText: '/path/to/file.pdf',
            labelText: '文件路径',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FButton(
            onPress: () {
              final fp = pathCtrl.text.trim();
              if (fp.isNotEmpty) {
                setState(() {
                  _filePath = fp;
                  _fileName = fp.split('/').last;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;
    final title = widget.assignment['title'] as String? ?? '作业';
    final description =
        widget.assignment['description'] as String? ?? '';
    final dueDate = widget.assignment['due_date'] as String?;
    final totalPoints = widget.assignment['total_points'];
    final status = widget.assignment['status'] as String? ?? 'open';
    final bool isClosed = status == 'closed';
    final bool alreadySubmitted =
        _mySubmission != null;
    final bool isGraded =
        alreadySubmitted && _mySubmission!['status'] == 'graded';
    final double? score = alreadySubmitted
        ? (_mySubmission!['score'] as num?)?.toDouble()
        : null;
    final String? feedback =
        alreadySubmitted ? _mySubmission!['feedback'] as String? : null;
    final bool canSubmit = !isClosed && !isGraded;

    return Container(
      color: colors.background,
      child: SafeArea(
        child: _loading
            ? const Center(child: FCircularProgress())
            : Column(
                children: [
                  FHeader.nested(
                    title: Text(title),
                    prefixes: [
                      FButton.icon(
                        onPress: () => Navigator.pop(context),
                        variant: FButtonVariant.ghost,
                        child: const Icon(FIcons.arrowLeft),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.all(r.hPadding),
                      children: [
                        // Assignment info
                        GlassCard(
                          padding: EdgeInsets.all(r.clamped(16, 12, 20)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (description.isNotEmpty) ...[
                                Text(description,
                                    style: AppTextStyles.scaled(
                                        AppTextStyles.body, r.scale)),
                                SizedBox(height: r.clamped(12, 8, 16)),
                              ],
                              Row(
                                children: [
                                  if (dueDate != null) ...[
                                    Icon(FIcons.calendar,
                                        size: r.clamped(14, 12, 16),
                                        color: colors.textSecondary),
                                    SizedBox(
                                        width: r.clamped(4, 2, 6)),
                                    Text(
                                      '截止: ${_formatDate(dueDate)}',
                                      style: AppTextStyles.scaled(
                                          AppTextStyles.caption, r.scale),
                                    ),
                                    SizedBox(
                                        width: r.clamped(16, 10, 24)),
                                  ],
                                  if (totalPoints != null) ...[
                                    Icon(FIcons.target,
                                        size: r.clamped(14, 12, 16),
                                        color: colors.textSecondary),
                                    SizedBox(
                                        width: r.clamped(4, 2, 6)),
                                    Text(
                                      '满分: ${totalPoints is int ? totalPoints : (totalPoints as num).toStringAsFixed(0)}',
                                      style: AppTextStyles.scaled(
                                          AppTextStyles.caption, r.scale),
                                    ),
                                  ],
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isClosed
                                          ? AppColors.danger.withAlpha(26)
                                          : AppColors.success.withAlpha(26),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isClosed ? '已截止' : '进行中',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isClosed
                                            ? AppColors.danger
                                            : AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: r.clamped(16, 10, 24)),

                        // Graded result
                        if (isGraded) ...[
                          GlassCard(
                            padding:
                                EdgeInsets.all(r.clamped(16, 12, 20)),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('成绩',
                                        style: AppTextStyles.scaled(
                                            AppTextStyles.subheading,
                                            r.scale)),
                                    const Spacer(),
                                    Text(
                                      score != null
                                          ? '${score.toStringAsFixed(1)} 分'
                                          : '已批改',
                                      style: TextStyle(
                                        fontSize: r.clamped(20, 16, 24),
                                        fontWeight: FontWeight.bold,
                                        color: (score != null &&
                                                score >= 60)
                                            ? AppColors.success
                                            : AppColors.danger,
                                      ),
                                    ),
                                  ],
                                ),
                                if (feedback != null &&
                                    feedback.isNotEmpty) ...[
                                  SizedBox(
                                      height: r.clamped(8, 6, 12)),
                                  Text('教师反馈:',
                                      style: AppTextStyles.scaled(
                                          AppTextStyles.caption,
                                          r.scale)),
                                  SizedBox(
                                      height: r.clamped(4, 2, 6)),
                                  Text(feedback,
                                      style: AppTextStyles.scaled(
                                          AppTextStyles.body, r.scale)),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: r.clamped(16, 10, 24)),
                        ],

                        // Already submitted info
                        if (alreadySubmitted && !isGraded) ...[
                          GlassCard(
                            padding:
                                EdgeInsets.all(r.clamped(16, 12, 20)),
                            child: Row(
                              children: [
                                Icon(FIcons.check,
                                    color: AppColors.success,
                                    size: r.clamped(20, 16, 24)),
                                SizedBox(
                                    width: r.clamped(8, 6, 12)),
                                Text('已提交，等待批改',
                                    style: AppTextStyles.scaled(
                                        AppTextStyles.bodyBold,
                                        r.scale)),
                              ],
                            ),
                          ),
                          SizedBox(height: r.clamped(16, 10, 24)),
                        ],

                        // Submission form
                        if (canSubmit) ...[
                          Text('提交作业',
                              style: AppTextStyles.scaled(
                                  AppTextStyles.subheading, r.scale)),
                          SizedBox(height: r.clamped(8, 6, 12)),

                          GlassCard(
                            padding:
                                EdgeInsets.all(r.clamped(16, 12, 20)),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _contentCtrl,
                                  maxLines: 6,
                                  style: AppTextStyles.scaled(
                                      AppTextStyles.body, r.scale),
                                  decoration: const InputDecoration(
                                    hintText: '请输入作业内容...',
                                    border: InputBorder.none,
                                  ),
                                ),
                                SizedBox(
                                    height: r.clamped(12, 8, 16)),
                                Row(
                                  children: [
                                    FButton(
                                      onPress: _pickFile,
                                      variant:
                                          FButtonVariant.ghost,
                                      child: Row(
                                        mainAxisSize:
                                            MainAxisSize.min,
                                        children: [
                                          Icon(FIcons.paperclip,
                                              size: r.clamped(
                                                  16, 14, 18)),
                                          SizedBox(
                                              width: r.clamped(
                                                  4, 2, 6)),
                                          Text('添加附件'),
                                        ],
                                      ),
                                    ),
                                    if (_fileName != null) ...[
                                      SizedBox(
                                          width: r.clamped(
                                              8, 6, 12)),
                                      Expanded(
                                        child: Text(
                                          _fileName!,
                                          style: AppTextStyles
                                              .scaled(
                                                  AppTextStyles
                                                      .caption,
                                                  r.scale),
                                          overflow: TextOverflow
                                              .ellipsis,
                                        ),
                                      ),
                                      FButton.icon(
                                        onPress: () {
                                          setState(() {
                                            _filePath = null;
                                            _fileName = null;
                                          });
                                        },
                                        variant:
                                            FButtonVariant.ghost,
                                        child: Icon(
                                            FIcons.x,
                                            size: r.clamped(
                                                14, 12, 16)),
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(
                                    height: r.clamped(16, 10, 24)),
                                SizedBox(
                                  width: double.infinity,
                                  child: FButton(
                                    onPress:
                                        _submitting
                                            ? null
                                            : _submit,
                                    child: _submitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                                FCircularProgress())
                                        : const Text('提 交'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
