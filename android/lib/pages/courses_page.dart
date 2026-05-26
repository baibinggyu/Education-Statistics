import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_provider.dart';

class CoursesPage extends StatefulWidget {
  final AuthProvider auth;
  const CoursesPage({super.key, required this.auth});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await widget.auth.api.listCourses();
      if (mounted) {
        setState(() {
          _courses = courses;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _courses;
    return _courses.where((c) {
      final name = (c['name'] as String? ?? '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  Color _colorForIndex(int index) {
    const colors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.purple,
      Color(0xFFF59E0B),
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
      Color(0xFF14B8A6),
    ];
    return colors[index % colors.length];
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadCourses,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  EdgeInsets.fromLTRB(r.hPadding, r.vPadding, r.hPadding, 0),
              child: Text('课程',
                  style: AppTextStyles.scaled(AppTextStyles.heading, r.scale)),
            ),
            SizedBox(height: r.clamped(12, 8, 16)),
            _buildSearchBar(context),
            SizedBox(height: r.clamped(16, 10, 24)),
            if (_loading)
              const Expanded(
                  child: Center(child: FCircularProgress()))
            else
              Expanded(child: _buildCourseGrid(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: FTextField(
        control: FTextFieldControl.managed(controller: _searchCtrl),
        hint: '搜索课程...',
        prefixBuilder: (context, style, _) => Icon(FIcons.search,
            color: colors.textSecondary, size: 20),
      ),
    );
  }

  Widget _buildCourseGrid(BuildContext context) {
    final r = context.responsive;
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(
        child: Text('暂无课程',
            style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: r.maxCrossAxisExtent,
        mainAxisSpacing: r.clamped(12, 8, 16).toDouble(),
        crossAxisSpacing: r.clamped(12, 8, 16).toDouble(),
        childAspectRatio: r.courseCardAspectRatio,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final c = filtered[index];
        final name = c['name'] as String? ?? '';
        final uuid = c['uuid'] as String;
        final videoCount = c['video_count'] as int? ?? 0;

        final progress = videoCount > 0 ? 0.5 : 0.0;

        return CourseCard(
          title: name,
          progress: progress,
          coverColor: _colorForIndex(index),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, a, b) => _CourseDetailScreen(
                  courseUuid: uuid,
                  courseName: name,
                  color: _colorForIndex(index),
                  auth: widget.auth,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CourseDetailScreen extends StatefulWidget {
  final String courseUuid;
  final String courseName;
  final Color color;
  final AuthProvider auth;

  const _CourseDetailScreen({
    required this.courseUuid,
    required this.courseName,
    required this.color,
    required this.auth,
  });

  @override
  State<_CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<_CourseDetailScreen> {
  List<dynamic> _videos = [];
  List<dynamic> _attendances = [];
  List<dynamic> _resources = [];
  List<dynamic> _assignments = [];
  bool _loadingVideos = true;
  bool _loadingResources = true;
  bool _loadingAssignments = true;
  Map<String, dynamic> _mySubmissions = {};

  bool get _isTeacher =>
      widget.auth.role == 'teacher' || widget.auth.role == 'admin';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadVideos(), _loadAttendance(), _loadResources(), _loadAssignments()]);
  }

  Future<void> _loadVideos() async {
    try {
      final videos = await widget.auth.api.listVideos(widget.courseUuid);
      if (mounted) {
        setState(() {
          _videos = videos;
          _loadingVideos = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVideos = false);
    }
  }

  Future<void> _loadAttendance() async {
    try {
      final list = await widget.auth.api.listAttendances(widget.courseUuid);
      if (mounted) setState(() => _attendances = list);
    } catch (_) {}
  }

  Future<void> _loadResources() async {
    try {
      final list = await widget.auth.api.listResources(widget.courseUuid);
      if (mounted) {
        setState(() {
          _resources = list;
          _loadingResources = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingResources = false);
    }
  }

  Future<void> _loadAssignments() async {
    try {
      final list = await widget.auth.api.listAssignments(widget.courseUuid);
      if (mounted) {
        setState(() {
          _assignments = list;
          _loadingAssignments = false;
        });
      }
      // Load submission status for each assignment
      final subs = <String, dynamic>{};
      for (final a in list) {
        try {
          final sub = await widget.auth.api.getMySubmission(
              widget.courseUuid, a['uuid'] as String);
          subs[a['uuid'] as String] = sub;
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _mySubmissions = subs);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAssignments = false);
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final dlDir = Directory('${dir.path}/downloads');
    await dlDir.create(recursive: true);
    final filePath = '${dlDir.path}/$fileName';

    try {
      await widget.auth.api.downloadToFile(url, filePath);
    } catch (_) {}
  }

  Future<void> _downloadVideo(String videoUuid, String title) async {
    final url = widget.auth.api.getVideoDownloadUrl(videoUuid);
    await _downloadFile(url, '$title.mp4');
  }

  Future<void> _downloadResource(
      String resourceUuid, String fileName) async {
    final url = widget.auth.api
        .getResourceDownloadUrl(widget.courseUuid, resourceUuid);
    await _downloadFile(url, fileName);
  }

  Future<void> _deleteResource(String resourceUuid) async {
    try {
      await widget.auth.api
          .deleteCourseResource(widget.courseUuid, resourceUuid);
      await _loadResources();
    } catch (_) {}
  }

  void _showUploadDialog() {
    final pathCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('上传资料'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pathCtrl,
              decoration: const InputDecoration(
                labelText: '文件路径',
                hintText: '/home/user/document.pdf',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: '标题（可选，默认使用文件名）',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FButton(
            onPress: () async {
              final fp = pathCtrl.text.trim();
              if (fp.isEmpty) return;
              try {
                final file = File(fp);
                if (!await file.exists()) {
                  return;
                }
                Navigator.pop(ctx);
                final fileName = fp.split('/').last;
                await widget.auth.api.uploadResource(
                  widget.courseUuid,
                  fp,
                  fileName,
                  title: titleCtrl.text.trim(),
                );
                await _loadResources();
              } catch (_) {}
            },
            child: const Text('上传'),
          ),
        ],
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
            title: Text(widget.courseName),
            prefixes: [
              FButton.icon(
                onPress: () => Navigator.pop(context),
                variant: FButtonVariant.ghost,
                child: const Icon(FIcons.arrowLeft),
              ),
            ],
            suffixes: [
              if (_isTeacher)
                FButton.icon(
                  onPress: () => Navigator.pushNamed(
                      context, '/student-info',
                      arguments: widget.courseUuid),
                  variant: FButtonVariant.ghost,
                  child: const Icon(FIcons.users),
                ),
            ],
          ),
          Container(
            height: r.clamped(160, 120, 200),
            margin: EdgeInsets.all(r.hPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r.radius),
              gradient: LinearGradient(
                colors: [
                  widget.color.withAlpha(204),
                  widget.color.withAlpha(51)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Icon(FIcons.graduationCap,
                  size: r.clamped(48, 36, 56),
                  color: const Color(0xCCFFFFFF)),
            ),
          ),
          Expanded(
            child: FTabs(
              children: [
                FTabEntry(
                  label: const Text('视频'),
                  child: _buildVideoTab(context),
                ),
                FTabEntry(
                  label: const Text('签到'),
                  child: _buildCheckInTab(context),
                ),
                FTabEntry(
                  label: const Text('资料'),
                  child: _buildResourcesTab(context),
                ),
                FTabEntry(
                  label: const Text('作业'),
                  child: _buildAssignmentTab(context),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildVideoTab(BuildContext context) {
    final r = context.responsive;
    if (_loadingVideos) {
      return const Center(child: FCircularProgress());
    }
    if (_videos.isEmpty) {
      return Center(
        child: Text('暂无视频',
            style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
      );
    }
    final iconSize = r.clamped(48, 40, 56);
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(r.hPadding),
      itemCount: _videos.length,
      separatorBuilder: (_, _) => SizedBox(height: r.clamped(8, 6, 10)),
      itemBuilder: (context, index) {
        final v = _videos[index];
        final title = v['title'] as String? ?? '';
        final uuid = v['uuid'] as String;
        return GlassCard(
          padding: EdgeInsets.all(r.clamped(12, 8, 16)),
          onTap: () {
            Navigator.pushNamed(context, '/video', arguments: uuid);
          },
          child: Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(r.clamped(10, 8, 12)),
                ),
                child: const Icon(FIcons.circlePlay,
                    color: AppColors.primary, size: 28),
              ),
              SizedBox(width: r.clamped(12, 8, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.scaled(
                            AppTextStyles.bodyBold, r.scale)),
                  ],
                ),
              ),
              SizedBox(width: r.clamped(8, 6, 10)),
              GestureDetector(
                onTap: () => _downloadVideo(uuid, title),
                child: Container(
                  width: r.clamped(34, 30, 40),
                  height: r.clamped(34, 30, 40),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(26),
                    borderRadius:
                        BorderRadius.circular(r.clamped(8, 6, 10)),
                  ),
                  child: const Icon(FIcons.download,
                      color: AppColors.primary, size: 18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckInTab(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;
    if (_attendances.isEmpty) {
      return Center(
        child: Text('暂无签到记录',
            style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
      );
    }
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(r.hPadding),
      children: _attendances.map((a) {
        final title = a['title'] as String? ?? '';
        final status = a['status'] as String? ?? 'open';
        final present = a['present_count'] as int? ?? 0;
        final total = a['total'] as int? ?? 0;
        final isOpen = status == 'open';
        return GlassCard(
          margin: EdgeInsets.only(bottom: r.clamped(8, 6, 10)),
          padding: EdgeInsets.symmetric(
              horizontal: r.clamped(16, 12, 20),
              vertical: r.clamped(12, 8, 16)),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isOpen
                      ? AppColors.success.withAlpha(26)
                      : colors.textMuted.withAlpha(26),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isOpen ? FIcons.check : FIcons.lock,
                  color: isOpen ? AppColors.success : colors.textMuted,
                  size: 20,
                ),
              ),
              SizedBox(width: r.clamped(12, 8, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.scaled(
                            AppTextStyles.body, r.scale)),
                    Text('$present/$total 已签到',
                        style: AppTextStyles.scaled(
                            AppTextStyles.caption, r.scale)),
                  ],
                ),
              ),
              BadgeChip(
                  label: isOpen ? '进行中' : '已结束',
                  color: isOpen ? AppColors.success : colors.textMuted),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResourcesTab(BuildContext context) {
    final r = context.responsive;
    if (_loadingResources) {
      return const Center(child: FCircularProgress());
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isTeacher)
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: r.hPadding, vertical: r.clamped(8, 4, 12)),
            child: FButton(
              onPress: _showUploadDialog,
              size: FButtonSizeVariant.sm,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FIcons.upload, size: 16),
                  SizedBox(width: 6),
                  Text('上传资料'),
                ],
              ),
            ),
          ),
        if (_resources.isEmpty)
          Padding(
            padding: EdgeInsets.all(r.clamped(32, 24, 48)),
            child: Center(
              child: Text('暂无资料',
                  style: AppTextStyles.scaled(
                      AppTextStyles.caption, r.scale)),
            ),
          )
        else
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: r.hPadding),
            children: _resources.map((res) {
                    final title = res['title'] as String? ?? '';
                    final fileName = res['file_name'] as String? ?? '';
                    final fileSize = res['file_size'] as int? ?? 0;
                    final fileType = res['file_type'] as String? ?? '';
                    final resourceUuid = res['uuid'] as String;
                    final sizeStr = fileSize > 1024 * 1024
                        ? '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
                        : fileSize > 1024
                            ? '${(fileSize ~/ 1024)} KB'
                            : '$fileSize B';
                    final icon = _fileIcon(fileType);
                    final iconColor = _fileColor(context, fileType);
                    return GlassCard(
                      margin: EdgeInsets.only(bottom: r.clamped(8, 6, 10)),
                      padding: EdgeInsets.symmetric(
                          horizontal: r.clamped(14, 10, 18),
                          vertical: r.clamped(10, 8, 12)),
                      child: Row(
                        children: [
                          Container(
                            width: r.clamped(40, 34, 48),
                            height: r.clamped(40, 34, 48),
                            decoration: BoxDecoration(
                              color: iconColor.withAlpha(26),
                              borderRadius: BorderRadius.circular(
                                  r.clamped(10, 8, 12)),
                            ),
                            child: Icon(icon, color: iconColor, size: 22),
                          ),
                          SizedBox(width: r.clamped(10, 8, 14)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: AppTextStyles.scaled(
                                        AppTextStyles.bodyBold, r.scale),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                SizedBox(height: r.clamped(2, 1, 3)),
                                Text('$fileName  $sizeStr',
                                    style: AppTextStyles.scaled(
                                        AppTextStyles.caption, r.scale)),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => _downloadResource(
                                    resourceUuid, fileName),
                                child: Container(
                                  width: r.clamped(34, 30, 40),
                                  height: r.clamped(34, 30, 40),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(26),
                                    borderRadius: BorderRadius.circular(
                                        r.clamped(8, 6, 10)),
                                  ),
                                  child: const Icon(FIcons.download,
                                      color: AppColors.primary, size: 18),
                                ),
                              ),
                              if (_isTeacher) ...[
                                SizedBox(width: r.clamped(6, 4, 8)),
                                GestureDetector(
                                  onTap: () => _deleteResource(resourceUuid),
                                  child: Container(
                                    width: r.clamped(34, 30, 40),
                                    height: r.clamped(34, 30, 40),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger.withAlpha(26),
                                      borderRadius: BorderRadius.circular(
                                          r.clamped(8, 6, 10)),
                                    ),
                                    child: const Icon(FIcons.trash,
                                        color: AppColors.danger, size: 18),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
          ),
      ],
    );
  }

  Widget _buildAssignmentTab(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;
    if (_loadingAssignments) {
      return const Center(child: FCircularProgress());
    }
    if (_assignments.isEmpty) {
      return Center(
        child: Text('暂无作业',
            style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(r.hPadding),
      itemCount: _assignments.length,
      separatorBuilder: (_, _) => SizedBox(height: r.clamped(8, 6, 10)),
      itemBuilder: (context, index) {
        final a = _assignments[index];
        final uuid = a['uuid'] as String;
        final title = a['title'] as String? ?? '';
        final dueDate = a['due_date'] as String?;
        final totalPoints = a['total_points'];
        final status = a['status'] as String? ?? 'open';

        final sub = _mySubmissions[uuid];
        final bool isSubmitted = sub is Map && sub['submitted'] != false;
        final bool isGraded = isSubmitted && (sub['status'] == 'graded');
        final subStatus = isGraded ? 'graded' : (isSubmitted ? 'submitted' : 'pending');
        final double? score = sub is Map ? (sub['score'] as num?)?.toDouble() : null;

        return GlassCard(
          padding: EdgeInsets.all(r.clamped(12, 8, 16)),
          onTap: () {
            Navigator.pushNamed(context, '/submit-homework', arguments: {
              'courseUuid': widget.courseUuid,
              'assignmentUuid': uuid,
              'assignment': a,
            }).then((_) => _loadAssignments());
          },
          child: Row(
            children: [
              Container(
                width: r.clamped(42, 36, 48),
                height: r.clamped(42, 36, 48),
                decoration: BoxDecoration(
                  color: (subStatus == 'graded'
                          ? AppColors.success
                          : (subStatus == 'submitted'
                              ? AppColors.warning
                              : AppColors.primary))
                      .withAlpha(26),
                  borderRadius:
                      BorderRadius.circular(r.clamped(10, 8, 12)),
                ),
                child: Icon(
                  subStatus == 'graded'
                      ? FIcons.check
                      : (subStatus == 'submitted'
                          ? FIcons.clock
                          : FIcons.clipboardList),
                  color: subStatus == 'graded'
                      ? AppColors.success
                      : (subStatus == 'submitted'
                          ? AppColors.warning
                          : AppColors.primary),
                  size: r.clamped(22, 18, 26),
                ),
              ),
              SizedBox(width: r.clamped(12, 8, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.scaled(
                            AppTextStyles.bodyBold, r.scale)),
                    SizedBox(height: r.clamped(4, 2, 6)),
                    Row(
                      children: [
                        if (dueDate != null) ...[
                          Icon(FIcons.calendar,
                              size: r.clamped(12, 10, 14),
                              color: _isOverdue(dueDate, status)
                                  ? AppColors.danger
                                  : colors.textSecondary),
                          SizedBox(width: r.clamped(4, 2, 6)),
                          Text(
                            _formatDueDate(dueDate),
                            style: AppTextStyles.scaled(
                                AppTextStyles.caption, r.scale),
                          ),
                          SizedBox(width: r.clamped(12, 8, 16)),
                        ],
                        if (totalPoints != null)
                          Text('满分: ${totalPoints is int ? totalPoints : totalPoints.toStringAsFixed(0)}',
                              style: AppTextStyles.scaled(
                                  AppTextStyles.caption, r.scale)),
                      ],
                    ),
                  ],
                ),
              ),
              _buildSubmissionBadge(subStatus, score),
            ],
          ),
        );
      },
    );
  }

  bool _isOverdue(String dueDate, String status) {
    if (status != 'open') return false;
    try {
      final due = DateTime.parse(dueDate);
      return DateTime.now().isAfter(due);
    } catch (_) {
      return false;
    }
  }

  String _formatDueDate(String dueDate) {
    try {
      final dt = DateTime.parse(dueDate);
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dueDate;
    }
  }

  Widget _buildSubmissionBadge(String subStatus, double? score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: subStatus == 'graded'
            ? AppColors.success.withAlpha(26)
            : (subStatus == 'submitted'
                ? AppColors.warning.withAlpha(26)
                : AppColors.primary.withAlpha(26)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        subStatus == 'graded'
            ? '${score?.toStringAsFixed(0) ?? "?"}分'
            : (subStatus == 'submitted' ? '已提交' : '待提交'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: subStatus == 'graded'
              ? AppColors.success
              : (subStatus == 'submitted'
                  ? AppColors.warning
                  : AppColors.primary),
        ),
      ),
    );
  }

  IconData _fileIcon(String type) {
    return switch (type) {
      'pdf' => FIcons.fileText,
      'doc' || 'docx' => FIcons.fileText,
      'xls' || 'xlsx' || 'csv' => FIcons.fileSpreadsheet,
      'ppt' || 'pptx' => FIcons.monitor,
      'zip' || 'rar' || '7z' => FIcons.fileArchive,
      'jpg' || 'jpeg' || 'png' || 'webp' || 'gif' => FIcons.fileImage,
      'mp3' || 'wav' || 'flac' => FIcons.music,
      'txt' => FIcons.fileText,
      _ => FIcons.file,
    };
  }

  Color _fileColor(BuildContext context, String type) {
    final colors = context.appColors;
    return switch (type) {
      'pdf' => AppColors.danger,
      'doc' || 'docx' => const Color(0xFF3B82F6),
      'xls' || 'xlsx' || 'csv' => AppColors.success,
      'ppt' || 'pptx' => AppColors.warning,
      'zip' || 'rar' || '7z' => AppColors.purple,
      'jpg' || 'jpeg' || 'png' || 'webp' || 'gif' => AppColors.accent,
      _ => colors.textSecondary,
    };
  }
}
