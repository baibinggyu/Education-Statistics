import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';
import '../services/api_client.dart';

class NotificationsPage extends StatefulWidget {
  final ApiClient api;
  const NotificationsPage({super.key, required this.api});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final courses = await widget.api.listCourses();
      final all = <Map<String, dynamic>>[];
      for (final c in courses) {
        final courseUuid = c['uuid'] as String;
        final courseName = c['name'] as String? ?? '';

        // Load announcements
        try {
          final announcements =
              await widget.api.listAnnouncements(courseUuid);
          for (final a in announcements) {
            all.add({
              ...a as Map<String, dynamic>,
              'course_uuid': courseUuid,
              'course_name': courseName,
              'kind': 'announcement',
            });
          }
        } catch (_) {}

        // Load assignments
        try {
          final assignments =
              await widget.api.listAssignments(courseUuid);
          for (final a in assignments) {
            all.add({
              ...a as Map<String, dynamic>,
              'course_uuid': courseUuid,
              'course_name': courseName,
              'kind': 'assignment',
            });
          }
        } catch (_) {}
      }
      all.sort((a, b) {
        final da = a['created_at'] as String? ?? '';
        final db = b['created_at'] as String? ?? '';
        return db.compareTo(da);
      });
      if (mounted) {
        setState(() {
          _items = all;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;
    final unreadCount = _items.length;

    return SafeArea(
      child: Column(
        children: [
          FHeader.nested(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('通知'),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  FBadge(
                    variant: FBadgeVariant.destructive,
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            prefixes: [
              FButton.icon(
                onPress: () => Navigator.pop(context),
                variant: FButtonVariant.ghost,
                child: const Icon(FIcons.arrowLeft),
              ),
            ],
            suffixes: [
              FButton.icon(
                onPress: _loadNotifications,
                variant: FButtonVariant.ghost,
                child: const Icon(FIcons.refreshCw),
              ),
            ],
          ),
          if (_loading)
            const Expanded(child: Center(child: FCircularProgress()))
          else
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FIcons.bell,
                              size: 48, color: colors.textMuted),
                          const SizedBox(height: 16),
                          Text('暂无通知',
                              style: AppTextStyles.scaled(
                                  AppTextStyles.caption, r.scale)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.separated(
                        padding: EdgeInsets.all(r.hPadding),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) =>
                            SizedBox(height: r.clamped(10, 6, 14)),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _buildNotificationCard(item, colors, r);
                        },
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
      Map<String, dynamic> item, AppColors colors, Responsive r) {
    final kind = item['kind'] as String? ?? 'announcement';
    final isAssignment = kind == 'assignment';

    final title = item['title'] as String? ?? '';
    final content = item['content'] as String? ?? item['description'] as String? ?? '';
    final courseName = item['course_name'] as String? ?? '';
    final annType = isAssignment ? '作业提醒' : item['ann_type'] as String? ?? '课程通知';
    final createdAt = item['created_at'] as String? ?? '';
    final courseUuid = item['course_uuid'] as String? ?? '';
    final typeColor = _typeColor(annType, colors);

    // Assignment-specific fields
    final dueDate = item['due_date'] as String?;
    final totalPoints = item['total_points'];
    final status = item['status'] as String?;
    final assignmentUuid = item['uuid'] as String?;

    return GestureDetector(
      onTap: () {
        if (isAssignment && assignmentUuid != null) {
          Navigator.pushNamed(context, '/submit-homework', arguments: {
            'courseUuid': courseUuid,
            'assignmentUuid': assignmentUuid,
            'assignment': item,
          });
        } else {
          Navigator.pushNamed(context, '/announcements', arguments: courseUuid);
        }
      },
      child: Container(
        padding: EdgeInsets.all(r.clamped(14, 10, 18)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(r.radius),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BadgeChip(label: annType, color: typeColor),
                const Spacer(),
                Text(_formatDate(createdAt),
                    style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
              ],
            ),
            SizedBox(height: r.clamped(8, 4, 12)),
            Text(title,
                style:
                    AppTextStyles.scaled(AppTextStyles.bodyBold, r.scale)),
            if (content.isNotEmpty) ...[
              SizedBox(height: r.clamped(4, 2, 6)),
              Text(content,
                  style: AppTextStyles.scaled(AppTextStyles.caption, r.scale),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            // Assignment extra info row
            if (isAssignment) ...[
              SizedBox(height: r.clamped(6, 3, 8)),
              Row(
                children: [
                  if (dueDate != null) ...[
                    Icon(FIcons.clock, size: 13, color: colors.textSecondary),
                    const SizedBox(width: 3),
                    Text(_formatDate(dueDate),
                        style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
                    const SizedBox(width: 12),
                  ],
                  if (totalPoints != null) ...[
                    Icon(FIcons.target, size: 13, color: colors.textSecondary),
                    const SizedBox(width: 3),
                    Text('满分 $totalPoints 分',
                        style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
                    const SizedBox(width: 12),
                  ],
                  BadgeChip(
                    label: status == 'open' ? '进行中' : '已关闭',
                    color: status == 'open' ? AppColors.success : colors.textMuted,
                  ),
                ],
              ),
            ],
            SizedBox(height: r.clamped(8, 4, 10)),
            Row(
              children: [
                Icon(FIcons.book, size: 14, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text(courseName,
                    style: AppTextStyles.scaled(
                        AppTextStyles.small, r.scale)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type, AppColors colors) {
    return switch (type) {
      '课程通知' => AppColors.primary,
      '作业提醒' => AppColors.warning,
      '考试安排' => AppColors.danger,
      '资料更新' => AppColors.accent,
      _ => colors.textSecondary,
    };
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return '${dt.month}月${dt.day}日';
    } catch (_) {
      return '';
    }
  }
}

