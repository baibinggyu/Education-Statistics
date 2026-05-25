import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';
import '../services/api_client.dart';

class AnnouncementPage extends StatefulWidget {
  final String? courseUuid;
  const AnnouncementPage({super.key, this.courseUuid});

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _announcements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    if (widget.courseUuid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final list = await _api.listAnnouncements(widget.courseUuid!);
      if (mounted) {
        setState(() {
          _announcements = list;
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
    final pinned =
        _announcements.where((a) => (a['pinned'] as bool? ?? false) == true).toList();
    final normal =
        _announcements.where((a) => (a['pinned'] as bool? ?? false) != true).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('公告')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnnouncements,
              child: ListView(
                padding: EdgeInsets.all(r.hPadding),
                children: [
                  if (pinned.isNotEmpty)
                    ...pinned.map((a) => _buildPinnedCard(a, context)),
                  if (pinned.isNotEmpty && normal.isNotEmpty)
                    SizedBox(height: r.clamped(16, 10, 24)),
                  if (normal.isNotEmpty) ...[
                    const SectionHeader(title: '全部公告'),
                    SizedBox(height: r.clamped(8, 4, 12)),
                    ...normal.map((a) => _buildAnnouncementCard(a)),
                  ],
                  if (_announcements.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('暂无公告', style: AppTextStyles.caption),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPinnedCard(dynamic a, BuildContext context) {
    final annType = a['ann_type'] as String? ?? '课程通知';
    final typeColor = _typeColor(annType);
    final title = a['title'] as String? ?? '';
    final content = a['content'] as String? ?? '';
    final author = a['author']?['username'] as String? ?? '';
    final createdAt = a['created_at'] as String? ?? '';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BadgeChip(label: '置顶', color: AppColors.primary),
              const SizedBox(width: 8),
              BadgeChip(label: annType, color: typeColor),
              const Spacer(),
              Text(_formatDate(createdAt), style: AppTextStyles.small),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: AppTextStyles.subheading),
          const SizedBox(height: 6),
          Text(content,
              style: AppTextStyles.caption,
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(author, style: AppTextStyles.small),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(dynamic a) {
    final annType = a['ann_type'] as String? ?? '课程通知';
    final typeColor = _typeColor(annType);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BadgeChip(label: annType, color: typeColor),
              const Spacer(),
              Text(_formatDate(a['created_at'] as String?),
                  style: AppTextStyles.small),
            ],
          ),
          const SizedBox(height: 8),
          Text(a['title'] as String? ?? '', style: AppTextStyles.bodyBold),
          const SizedBox(height: 4),
          Text(a['content'] as String? ?? '',
              style: AppTextStyles.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(a['author']?['username'] as String? ?? '',
                  style: AppTextStyles.small),
            ],
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    return switch (type) {
      '课程通知' => AppColors.primary,
      '作业提醒' => AppColors.warning,
      '考试安排' => AppColors.danger,
      '资料更新' => AppColors.accent,
      _ => AppColors.textSecondary,
    };
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month}月${dt.day}日';
    } catch (_) {
      return '';
    }
  }
}
