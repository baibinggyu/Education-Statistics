import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
              SizedBox(height: r.clamped(20, 12, 28)),
              SectionHeader(title: '最近课程', action: '查看全部'),
              SizedBox(height: r.clamped(8, 4, 12)),
              _buildRecentCourses(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final r = context.responsive;
    final avatarSize = r.clamped(20, 16, 26);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: Row(
        children: [
          CircleAvatar(
            radius: avatarSize,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, color: Colors.white, size: avatarSize * 1.1),
          ),
          SizedBox(width: r.clamped(12, 8, 16)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('早上好', style: AppTextStyles.scaled(AppTextStyles.body, r.scale)),
              Text('张同学', style: AppTextStyles.scaled(AppTextStyles.subheading, r.scale)),
            ],
          ),
          const Spacer(),
          Icon(Icons.notifications_outlined, color: Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary, size: r.clamped(24, 20, 28)),
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
          // Use aspect ratio or minimum height, whichever is larger
          final minHeight = r.clamped(150, 130, 200);
          final aspectHeight = constraints.maxWidth * 0.25;
          final bannerHeight = aspectHeight > minHeight ? aspectHeight : minHeight.toDouble();

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
                  right: -20, top: -20,
                  child: Container(
                    width: r.clamped(120, 80, 160),
                    height: r.clamped(120, 80, 160),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withAlpha(26), width: 2),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(innerPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Edu · AI + 教育', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: r.clamped(8, 4, 10)),
                      Text('让教育更智能，让学习更高效', style: TextStyle(fontSize: bodySize, color: Colors.white70)),
                      SizedBox(height: r.clamped(14, 6, 20)),
                      Row(
                        children: [
                          Icon(Icons.play_circle, color: Colors.white, size: r.clamped(16, 14, 20)),
                          SizedBox(width: r.clamped(4, 2, 6)),
                          Text('继续学习', style: TextStyle(fontSize: bodySize, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
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
    final actions = [
      {'icon': Icons.how_to_reg, 'label': '点名'},
      {'icon': Icons.group_add, 'label': '组队'},
      {'icon': Icons.timer, 'label': '倒计时'},
      {'icon': Icons.play_circle, 'label': '视频'},
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: r.isCompact
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: actions.map((a) => _buildActionButton(context, a, btnSize, iconSize, r)).toList(),
            )
          : Wrap(
              spacing: r.clamped(24, 16, 40),
              runSpacing: r.clamped(12, 8, 18),
              alignment: WrapAlignment.center,
              children: actions.map((a) => _buildActionButton(context, a, btnSize, iconSize, r)).toList(),
            ),
    );
  }

  Widget _buildActionButton(BuildContext context, Map<String, dynamic> a, double btnSize, double iconSize, Responsive r) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        children: [
          Container(
            width: btnSize, height: btnSize,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(r.clamped(14, 10, 18)),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Icon(a['icon'] as IconData, color: AppColors.primary, size: iconSize),
          ),
          SizedBox(height: r.clamped(6, 4, 8)),
          Text(a['label'] as String, style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final r = context.responsive;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: Row(
        children: [
          Expanded(child: StatCard(title: '课程数', value: '8', icon: Icons.book)),
          SizedBox(width: r.clamped(12, 8, 16)),
          Expanded(child: StatCard(title: '学生数', value: '156', icon: Icons.people)),
          SizedBox(width: r.clamped(12, 8, 16)),
          Expanded(child: StatCard(title: '视频数', value: '42', icon: Icons.videocam)),
        ],
      ),
    );
  }

  Widget _buildRecentCourses(BuildContext context) {
    final r = context.responsive;
    final courses = <Map<String, dynamic>>[
      {'title': '电子技术基础', 'teacher': '王教授', 'category': '专业课', 'progress': 0.65, 'color': AppColors.primary},
      {'title': '学科教学设计', 'teacher': '李老师', 'category': '师范', 'progress': 0.32, 'color': AppColors.accent},
      {'title': '高等数学', 'teacher': '张教授', 'category': '基础课', 'progress': 0.78, 'color': AppColors.purple},
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          // Calculate card width so they fill the row naturally
          final spacing = r.clamped(12, 8, 16);
          // On wide screens fit multiple cards, on narrow show 1-2
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
            children: courses.map((c) {
              return SizedBox(
                width: cardWidth,
                child: CourseCard(
                  title: c['title'] as String,
                  teacher: c['teacher'] as String,
                  category: c['category'] as String,
                  progress: c['progress'] as double,
                  coverColor: c['color'] as Color,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _PlaceholderPage(title: '课程详情'))),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('页面开发中...', style: AppTextStyles.body)),
    );
  }
}
