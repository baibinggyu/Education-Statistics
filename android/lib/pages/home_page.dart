import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_provider.dart';

class HomePage extends StatefulWidget {
  final AuthProvider auth;
  const HomePage({super.key, required this.auth});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> _courses = [];
  Map<String, double> _courseProgress = {};
  Map<String, int> _videoCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final courses = await widget.auth.api.listCourses();
      final progress = <String, double>{};
      final videoCounts = <String, int>{};
      for (final c in courses) {
        final uuid = c['uuid'] as String;
        try {
          final records = await widget.auth.api
              .getMyCoursePlayRecords(uuid);
          final total = records.length;
          final completed =
              records.where((r) => (r['completed'] as bool? ?? false)).length;
          progress[uuid] =
              total > 0 ? completed / total : 0.0;
        } catch (_) {
          progress[uuid] = 0.0;
        }
        try {
          final videos = await widget.auth.api.listVideos(uuid);
          videoCounts[uuid] = videos.length;
        } catch (_) {
          videoCounts[uuid] = 0;
        }
      }
      if (mounted) {
        setState(() {
          _courses = courses;
          _courseProgress = progress;
          _videoCounts = videoCounts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _totalStudents {
    int count = 0;
    for (final c in _courses) {
      count += (c['member_count'] as int? ?? 0);
    }
    return count;
  }

  int get _totalVideos {
    int count = 0;
    for (final n in _videoCounts.values) {
      count += n;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    if (_loading) {
      return const Center(child: FCircularProgress());
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(vertical: r.vPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              SizedBox(height: r.clamped(16, 10, 24)),
              _buildBanner(context),
              SizedBox(height: r.clamped(20, 12, 28)),
              _buildQuickActions(context),
              SizedBox(height: r.clamped(20, 12, 28)),
              _buildStats(context),
              if (_courses.isNotEmpty) ...[
                SizedBox(height: r.clamped(20, 12, 28)),
                SectionHeader(title: '最近课程', action: '查看全部'),
                SizedBox(height: r.clamped(8, 4, 12)),
                _buildRecentCourses(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final r = context.responsive;
    final avatarSize = r.clamped(20, 16, 26);
    final name = widget.auth.username ?? '同学';
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: Row(
        children: [
          FAvatar.raw(
            size: avatarSize * 2,
            child: Container(
              color: AppColors.primary,
              alignment: Alignment.center,
              child: Icon(FIcons.user,
                  color: const Color(0xFFFFFFFF),
                  size: avatarSize * 1.1),
            ),
          ),
          SizedBox(width: r.clamped(12, 8, 16)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('早上好',
                  style: AppTextStyles.scaled(AppTextStyles.body, r.scale)),
              Text(name,
                  style: AppTextStyles.scaled(
                      AppTextStyles.subheading, r.scale)),
            ],
          ),
          const Spacer(),
          FButton.icon(
            onPress: _loadData,
            variant: FButtonVariant.ghost,
            child: Icon(FIcons.refreshCw,
                size: r.clamped(22, 18, 26)),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    final r = context.responsive;
    final titleSize = r.clamped(22, 18, 28);
    final bodySize = r.clamped(13, 11, 15);
    final innerPadding = r.clamped(20, 14, 32);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minHeight = r.clamped(150, 130, 200);
          final aspectHeight = constraints.maxWidth * 0.25;
          final bannerHeight = aspectHeight > minHeight
              ? aspectHeight
              : minHeight.toDouble();

          return Container(
            height: bannerHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r.radius),
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent, AppColors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: r.clamped(120, 80, 160),
                    height: r.clamped(120, 80, 160),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0x42FFFFFF), width: 2),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(innerPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Edu · AI + 教育',
                          style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFFFFFF))),
                      SizedBox(height: r.clamped(8, 4, 10)),
                      Text('让教育更智能，让学习更高效',
                          style: TextStyle(
                              fontSize: bodySize,
                              color: const Color(0xB3FFFFFF))),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final r = context.responsive;
    final btnSize = r.iconButtonSize;
    final iconSize = btnSize * 0.46;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: _buildActionButton(
          context,
          {'icon': FIcons.megaphone, 'label': '公告', 'route': '/announcements'},
          btnSize, iconSize, r),
    );
  }

  Widget _buildActionButton(BuildContext context, Map<String, dynamic> a,
      double btnSize, double iconSize, Responsive r) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: () => _handleActionTap(context, a['route'] as String),
      child: Column(
        children: [
          Container(
            width: btnSize,
            height: btnSize,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(r.clamped(14, 10, 18)),
              border: Border.all(color: colors.border),
            ),
            child: Icon(a['icon'] as IconData,
                color: AppColors.primary, size: iconSize),
          ),
          SizedBox(height: r.clamped(6, 4, 8)),
          Text(a['label'] as String,
              style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
        ],
      ),
    );
  }

  void _handleActionTap(BuildContext context, String route) async {
    final firstCourseUuid = _courses.isEmpty ? null : _courses.first['uuid'] as String;
    if (firstCourseUuid != null) {
      Navigator.pushNamed(context, route, arguments: firstCourseUuid);
    } else {
      Navigator.pushNamed(context, route);
    }
  }

  Widget _buildStats(BuildContext context) {
    final r = context.responsive;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: Row(
        children: [
          Expanded(
              child: StatCard(
                  title: '课程数',
                  value: '${_courses.length}',
                  icon: FIcons.book)),
          SizedBox(width: r.clamped(12, 8, 16)),
          Expanded(
              child: StatCard(
                  title: '学生数',
                  value: '$_totalStudents',
                  icon: FIcons.users)),
          SizedBox(width: r.clamped(12, 8, 16)),
          Expanded(
              child: StatCard(
                  title: '视频数',
                  value: '$_totalVideos',
                  icon: FIcons.video)),
        ],
      ),
    );
  }

  Widget _buildRecentCourses(BuildContext context) {
    final r = context.responsive;
    final displayCourses = _courses.take(4).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final spacing = r.clamped(12, 8, 16).toDouble();
          int cols;
          if (availableWidth > 600) {
            cols = (availableWidth / 200).ceil().clamp(2, 4);
          } else if (availableWidth > 360) {
            cols = 2;
          } else {
            cols = 1;
          }
          final cardWidth = (availableWidth - spacing * (cols - 1)) / cols;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: displayCourses.map((c) {
              final name = c['name'] as String? ?? '';
              final uuid = c['uuid'] as String;
              final progress = _courseProgress[uuid] ?? 0.0;

              return SizedBox(
                width: cardWidth,
                child: CourseCard(
                  title: name,
                  progress: progress,
                  coverColor: AppColors.primary,
                  onTap: () async {
                    final uuid = c['uuid'] as String;
                    Navigator.pushNamed(context, '/announcements',
                        arguments: uuid);
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
