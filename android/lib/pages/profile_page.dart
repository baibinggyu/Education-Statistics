import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_provider.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final VoidCallback? onLogout;
  final AuthProvider auth;

  const ProfilePage({
    super.key,
    this.onToggleTheme,
    this.onLogout,
    required this.auth,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _courseCount = 0;
  int _totalWatchSeconds = 0;
  double _totalCredits = 0;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final courses = await widget.auth.api.listCourses();
      int totalSeconds = 0;
      double totalCredits = 0;

      for (final c in courses) {
        final uuid = c['uuid'] as String;
        // Aggregate play records for watch time
        try {
          final records =
              await widget.auth.api.getMyCoursePlayRecords(uuid);
          for (final r in records) {
            totalSeconds += (r['progress'] as int? ?? 0);
          }
        } catch (_) {}

        // Aggregate scores for credits
        try {
          final scores = await widget.auth.api.getMyScores(uuid);
          final wt = scores['weighted_total'];
          if (wt != null && wt is num) {
            totalCredits += wt.toDouble();
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _courseCount = courses.length;
          _totalWatchSeconds = totalSeconds;
          _totalCredits = totalCredits;
          _statsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  String get _watchTimeStr {
    if (_totalWatchSeconds < 60) return '$_totalWatchSeconds秒';
    if (_totalWatchSeconds < 3600) {
      return '${(_totalWatchSeconds / 60).toStringAsFixed(0)}分钟';
    }
    return '${(_totalWatchSeconds / 3600).toStringAsFixed(1)}小时';
  }

  String get _creditsStr {
    if (_totalCredits == 0) return '-';
    return _totalCredits.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: r.vPadding),
        child: Column(
          children: [
            _buildUserCard(context),
            SizedBox(height: r.clamped(16, 10, 24)),
            _buildStatsRow(context),
            SizedBox(height: r.clamped(20, 12, 28)),
            _buildMenuSection(context, '学习', [
              _menuItem(FIcons.clipboardList, '我的作业', '查看待提交和已批改的作业'),
              _menuItem(FIcons.trendingUp, '学习报告', '学习进度和成绩分析',
                  onTap: () => Navigator.pushNamed(context, '/learning-report')),
              _menuItem(FIcons.fileText, '报告历史', '查看和导出历史报告',
                  onTap: () => Navigator.pushNamed(context, '/report-history')),
              _menuItem(FIcons.download, '离线下载', '管理已下载的视频和资料',
                  onTap: () => Navigator.pushNamed(context, '/downloads')),
            ]),
            SizedBox(height: r.clamped(16, 10, 24)),
            _buildMenuSection(context, '账号', [
              _menuItem(FIcons.user, '个人信息', '修改头像、昵称、班级信息',
                  onTap: () => Navigator.pushNamed(context, '/personal-info')),
              _menuItem(FIcons.shield, '账号安全', '修改密码，绑定手机'),
              _menuItem(FIcons.bell, '通知设置', '消息推送和提醒偏好',
                  onTap: () => Navigator.pushNamed(context, '/notifications')),
            ]),
            SizedBox(height: r.clamped(16, 10, 24)),
            _buildMenuSection(context, '其他', [
              _menuItem(FIcons.info, '关于 Edu', 'v1.0.0 · AI + 教育平台',
                  onTap: () => Navigator.pushNamed(context, '/about')),
              _menuItem(FIcons.sunMoon, '主题切换',
                  ThemeScope.of(context).isDark ? '深色模式' : '浅色模式',
                  onTap: widget.onToggleTheme),
              _menuItem(FIcons.circleQuestionMark, '帮助与反馈', '常见问题和意见反馈'),
            ]),
            SizedBox(height: r.clamped(24, 16, 32)),
            GestureDetector(
              onTap: () {
                if (widget.onLogout != null) {
                  widget.onLogout!();
                } else {
                  widget.auth.logout();
                }
              },
              child: const Text('退出登录',
                  style: TextStyle(color: AppColors.danger, fontSize: 15)),
            ),
            SizedBox(height: r.clamped(8, 4, 12)),
            const Text('Edu v1.0.0 · AI + 教育', style: AppTextStyles.small),
            SizedBox(height: r.clamped(16, 10, 24)),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _menuItem(IconData icon, String title, String subtitle,
      {VoidCallback? onTap}) {
    return {'icon': icon, 'title': title, 'subtitle': subtitle, 'onTap': onTap};
  }

  Widget _buildUserCard(BuildContext context) {
    final r = context.responsive;
    final avatarSize = r.clamped(64, 52, 80);
    final name = widget.auth.username ?? '同学';
    final role = widget.auth.role ?? 'student';
    final roleLabel = role == 'teacher'
        ? '教师'
        : role == 'admin'
            ? '管理员'
            : '学生';
    return GlassCard(
      margin: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: Row(
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(avatarSize / 2),
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
            ),
            child: Icon(FIcons.user,
                size: avatarSize * 0.56, color: const Color(0xFFFFFFFF)),
          ),
          SizedBox(width: r.clamped(16, 12, 20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.scaled(
                        AppTextStyles.subheading, r.scale)),
                SizedBox(height: r.clamped(4, 2, 6)),
                Text('角色: $roleLabel',
                    style: AppTextStyles.scaled(
                        AppTextStyles.caption, r.scale)),
                SizedBox(height: r.clamped(8, 4, 10)),
                BadgeChip(label: roleLabel, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;
    final courseVal =
        _statsLoading ? '-' : '$_courseCount';
    final watchVal =
        _statsLoading ? '-' : _watchTimeStr;
    final creditsVal =
        _statsLoading ? '-' : _creditsStr;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: Row(
        children: [
          Expanded(child: _buildStatItem(context, courseVal, '学习课程')),
          Container(
              width: 1,
              height: r.clamped(30, 24, 36),
              color: colors.border),
          Expanded(child: _buildStatItem(context, watchVal, '学习时长')),
          Container(
              width: 1,
              height: r.clamped(30, 24, 36),
              color: colors.border),
          Expanded(child: _buildStatItem(context, creditsVal, '获得学分')),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    final r = context.responsive;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: r.clamped(20, 18, 24),
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
        SizedBox(height: r.clamped(2, 1, 4)),
        Text(label,
            style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
      ],
    );
  }

  Widget _buildMenuSection(
      BuildContext context, String title, List<Map<String, dynamic>> items) {
    final r = context.responsive;
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        SizedBox(height: r.clamped(4, 2, 6)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.hPadding),
          child: FTileGroup(
            divider: FItemDivider.indented,
            children: items.map((item) {
              final icon = item['icon'] as IconData;
              final itemTitle = item['title'] as String;
              final subtitle = item['subtitle'] as String;
              final onTap = item['onTap'] as VoidCallback?;
              return FTile(
                onPress: onTap ?? () {},
                prefix: Icon(icon,
                    color: AppColors.primary,
                    size: r.clamped(22, 20, 26)),
                title: Text(itemTitle,
                    style:
                        AppTextStyles.scaled(AppTextStyles.body, r.scale)),
                subtitle: Text(subtitle,
                    style:
                        AppTextStyles.scaled(AppTextStyles.small, r.scale)),
                suffix: Icon(FIcons.chevronRight,
                    color: colors.textMuted,
                    size: r.clamped(20, 18, 24)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
