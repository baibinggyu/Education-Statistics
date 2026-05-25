import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_provider.dart';

class ProfilePage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: r.vPadding),
          child: Column(
            children: [
              _buildUserCard(context),
              SizedBox(height: r.clamped(16, 10, 24)),
              _buildStatsRow(context),
              SizedBox(height: r.clamped(20, 12, 28)),
              _buildMenuSection(context, '学习', [
                {
                  'icon': Icons.assignment,
                  'title': '我的作业',
                  'subtitle': '查看待提交和已批改的作业'
                },
                {
                  'icon': Icons.trending_up,
                  'title': '学习报告',
                  'subtitle': '学习进度和成绩分析'
                },
                {
                  'icon': Icons.download,
                  'title': '离线下载',
                  'subtitle': '管理已下载的视频和资料'
                },
              ]),
              SizedBox(height: r.clamped(16, 10, 24)),
              _buildMenuSection(context, '账号', [
                {
                  'icon': Icons.person_outline,
                  'title': '个人信息',
                  'subtitle': '修改头像、昵称、班级信息'
                },
                {
                  'icon': Icons.security,
                  'title': '账号安全',
                  'subtitle': '修改密码，绑定手机'
                },
                {
                  'icon': Icons.notifications_outlined,
                  'title': '通知设置',
                  'subtitle': '消息推送和提醒偏好'
                },
              ]),
              SizedBox(height: r.clamped(16, 10, 24)),
              _buildMenuSection(context, '其他', [
                {
                  'icon': Icons.info_outline,
                  'title': '关于 Edu',
                  'subtitle': 'v1.0.0 · AI + 教育平台'
                },
                {
                  'icon': Icons.brightness_6,
                  'title': '主题切换',
                  'subtitle':
                      Theme.of(context).brightness == Brightness.dark
                          ? '深色模式'
                          : '浅色模式',
                  'onTap': onToggleTheme,
                },
                {
                  'icon': Icons.help_outline,
                  'title': '帮助与反馈',
                  'subtitle': '常见问题和意见反馈'
                },
              ]),
              SizedBox(height: r.clamped(24, 16, 32)),
              TextButton(
                onPressed: () {
                  if (onLogout != null) {
                    onLogout!();
                  } else {
                    auth.logout();
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
      ),
    );
  }

  Widget _buildUserCard(BuildContext context) {
    final r = context.responsive;
    final avatarSize = r.clamped(64, 52, 80);
    final name = auth.username ?? '同学';
    final role = auth.role ?? 'student';
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
            child:
                Icon(Icons.person, size: avatarSize * 0.56, color: Colors.white),
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: Row(
        children: [
          Expanded(child: _buildStatItem(context, '-', '学习课程')),
          Container(
              width: 1,
              height: r.clamped(30, 24, 36),
              color: Theme.of(context).dividerColor),
          Expanded(child: _buildStatItem(context, '-', '学习时长')),
          Container(
              width: 1,
              height: r.clamped(30, 24, 36),
              color: Theme.of(context).dividerColor),
          Expanded(child: _buildStatItem(context, '-', '获得学分')),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        SizedBox(height: r.clamped(4, 2, 6)),
        GlassCard(
          margin: EdgeInsets.symmetric(horizontal: r.hPadding),
          padding: EdgeInsets.zero,
          child: Column(
            children: items.asMap().entries.map((entry) {
              final i = entry.value;
              final isLast = entry.key == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    leading: Icon(i['icon'] as IconData,
                        color: AppColors.primary,
                        size: r.clamped(22, 20, 26)),
                    title: Text(i['title'] as String,
                        style: AppTextStyles.scaled(
                            AppTextStyles.body, r.scale)),
                    subtitle: Text(i['subtitle'] as String,
                        style: AppTextStyles.scaled(
                            AppTextStyles.small, r.scale)),
                    trailing: Icon(Icons.chevron_right,
                        color: Theme.of(context).textTheme.bodySmall?.color ??
                            AppColors.textSecondary,
                        size: r.clamped(20, 18, 24)),
                    onTap: i['onTap'] is VoidCallback
                        ? (i['onTap'] as VoidCallback)
                        : () {},
                  ),
                  if (!isLast)
                    Divider(
                        indent: r.clamped(56, 48, 64),
                        endIndent: r.hPadding),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
