import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class AnnouncementPage extends StatelessWidget {
  const AnnouncementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('公告')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPinnedAnnouncement(),
          const SizedBox(height: 16),
          const SectionHeader(title: '全部公告'),
          const SizedBox(height: 8),
          ..._announcements.map((a) => _buildAnnouncementCard(a)),
        ],
      ),
    );
  }

  Widget _buildPinnedAnnouncement() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              BadgeChip(label: '置顶', color: AppColors.primary),
              SizedBox(width: 8),
              BadgeChip(label: '重要', color: AppColors.danger),
              Spacer(),
              Text('5月15日', style: AppTextStyles.small),
            ],
          ),
          const SizedBox(height: 10),
          const Text('关于期末考试安排的重要通知', style: AppTextStyles.subheading),
          const SizedBox(height: 6),
          const Text(
            '各位同学，本学期期末考试将于6月20日至6月30日进行，具体考试安排请查看附件。请同学们提前做好复习准备，如有特殊情况无法参加考试，请提前一周向教务处提交缓考申请。',
            style: AppTextStyles.caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.visibility, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              const Text('256 阅读', style: AppTextStyles.small),
              const Spacer(),
              const Icon(Icons.attach_file, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              const Text('考试安排.pdf', style: AppTextStyles.small),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, String> a) {
    final typeColor = switch (a['type']) {
      '通知' => AppColors.primary,
      '作业' => AppColors.warning,
      '活动' => AppColors.accent,
      '重要' => AppColors.danger,
      _ => AppColors.textSecondary,
    };

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BadgeChip(label: a['type']!, color: typeColor),
              const Spacer(),
              Text(a['date']!, style: AppTextStyles.small),
            ],
          ),
          const SizedBox(height: 8),
          Text(a['title']!, style: AppTextStyles.bodyBold),
          const SizedBox(height: 4),
          Text(a['content']!, style: AppTextStyles.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.visibility, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${a['views']} 阅读', style: AppTextStyles.small),
              const SizedBox(width: 16),
              const Icon(Icons.person, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(a['author']!, style: AppTextStyles.small),
            ],
          ),
        ],
      ),
    );
  }
}

final List<Map<String, String>> _announcements = [
  {'title': '第五章实验安排调整', 'type': '通知', 'date': '5月16日', 'author': '王教授', 'views': '189', 'content': '由于实验室设备维护，原定于下周二的实验课调整至周四下午，请各位同学相互转告。'},
  {'title': '第四次作业提交提醒', 'type': '作业', 'date': '5月14日', 'author': '李老师', 'views': '312', 'content': '同学们，第四次作业截止日期为5月20日，请按时提交。作业内容为第三章课后习题第1-10题。'},
  {'title': '电子设计竞赛报名通知', 'type': '活动', 'date': '5月12日', 'author': '教务处', 'views': '445', 'content': '2026年度大学生电子设计竞赛开始报名，欢迎全校同学积极参与。报名截止日期为6月1日。'},
  {'title': '关于"五一"假期安全提醒', 'type': '重要', 'date': '4月30日', 'author': '辅导员', 'views': '678', 'content': '五一假期将至，请各位同学注意人身财产安全，离校前检查宿舍水电，遵守交通规则。'},
  {'title': '期中教学检查通知', 'type': '通知', 'date': '4月25日', 'author': '教务处', 'views': '390', 'content': '根据学校教学工作安排，下周将进行期中教学检查，请各位任课教师做好准备。'},
  {'title': '课程设计题目公布', 'type': '通知', 'date': '4月20日', 'author': '张教授', 'views': '521', 'content': '本学期课程设计题目已公布，请同学们自由组队（3-5人），选题后于5月1日前提交选题表。'},
];
