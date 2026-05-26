import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
              title: const Text('关于 Edu'),
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
                children: [
                  _buildLogo(context),
                  SizedBox(height: r.clamped(24, 16, 32)),
                  _buildSection(context, '平台简介',
                      'Edu 是一个 AI + 音视频 + 实时互动 + 数据分析的综合教学平台。'
                          '旨在为教师和学生提供一站式的智能教学体验，'
                          '覆盖课程管理、视频教学、考勤签到、成绩分析和 AI 辅助学习等核心场景。'),
                  SizedBox(height: r.clamped(16, 10, 24)),
                  _buildSection(context, '核心功能', null),
                  _buildFeatureList(context),
                  SizedBox(height: r.clamped(16, 10, 24)),
                  _buildSection(context, '技术栈', null),
                  _buildTechTags(context),
                  SizedBox(height: r.clamped(24, 16, 32)),
                  Text('Edu v1.0.0',
                      style: AppTextStyles.scaled(
                          AppTextStyles.caption, r.scale)),
                  SizedBox(height: r.clamped(4, 2, 8)),
                  Text('AI + 教育 · 让教育更智能，让学习更高效',
                      style: AppTextStyles.scaled(
                          AppTextStyles.small, r.scale)),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    final r = context.responsive;
    final logoSize = r.clamped(80, 64, 100);
    return Column(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.clamped(20, 16, 24)),
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent, AppColors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(FIcons.graduationCap,
              size: logoSize * 0.55, color: const Color(0xFFFFFFFF)),
        ),
        SizedBox(height: r.clamped(16, 10, 22)),
        Text('Edu',
            style: TextStyle(
                fontSize: r.clamped(28, 22, 34),
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
        SizedBox(height: r.clamped(4, 2, 6)),
        Text('AI + 教育 · 智能教育平台',
            style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, String? content) {
    final r = context.responsive;
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.clamped(16, 12, 20)),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTextStyles.scaled(AppTextStyles.subheading, r.scale)),
          if (content != null) ...[
            SizedBox(height: r.clamped(8, 4, 12)),
            Text(content,
                style: AppTextStyles.scaled(AppTextStyles.body, r.scale)),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureList(BuildContext context) {
    final r = context.responsive;
    final features = [
      {'icon': FIcons.book, 'title': '课程管理', 'desc': '创建和管理课程，灵活组织教学内容'},
      {'icon': FIcons.video, 'title': '视频教学', 'desc': '上传和播放教学视频，追踪学习进度'},
      {'icon': FIcons.userCheck, 'title': '考勤签到', 'desc': '随机点名和课堂签到，提高出勤率'},
      {'icon': FIcons.trendingUp, 'title': '成绩分析', 'desc': '录入和分析成绩，生成统计报表'},
      {'icon': FIcons.bot, 'title': 'AI 助手', 'desc': '基于 DeepSeek 的智能学习分析和建议'},
      {'icon': FIcons.fileText, 'title': '资源共享', 'desc': '上传和下载课件、文档等教学资料'},
    ];

    return Column(
      children: features.map((f) {
        return Padding(
          padding: EdgeInsets.only(bottom: r.clamped(8, 6, 10)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: r.clamped(36, 30, 42),
                height: r.clamped(36, 30, 42),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(f['icon'] as IconData,
                    color: AppColors.primary, size: 20),
              ),
              SizedBox(width: r.clamped(12, 8, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f['title'] as String,
                        style: AppTextStyles.scaled(
                            AppTextStyles.bodyBold, r.scale)),
                    SizedBox(height: 2),
                    Text(f['desc'] as String,
                        style: AppTextStyles.scaled(
                            AppTextStyles.caption, r.scale)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTechTags(BuildContext context) {
    final tags = [
      'Flutter', 'FastAPI', 'MariaDB', 'DeepSeek AI',
      'Qt / C++', 'QML', 'JWT', 'WebSocket',
      'SQLAlchemy', 'Pydantic', 'media_kit', 'ForUI',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(tag,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        );
      }).toList(),
    );
  }
}
