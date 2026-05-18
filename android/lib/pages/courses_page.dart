import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = '全部';

  final List<Map<String, dynamic>> _courses = [
    {'title': '电子技术基础', 'teacher': '王教授', 'category': '专业课', 'progress': 0.65, 'color': AppColors.primary},
    {'title': '学科教学设计', 'teacher': '李老师', 'category': '师范', 'progress': 0.32, 'color': AppColors.accent},
    {'title': '高等数学', 'teacher': '张教授', 'category': '基础课', 'progress': 0.78, 'color': AppColors.purple},
    {'title': '大学物理', 'teacher': '刘教授', 'category': '基础课', 'progress': 0.45, 'color': const Color(0xFFF59E0B)},
    {'title': 'C语言程序设计', 'teacher': '陈老师', 'category': '专业课', 'progress': 0.91, 'color': const Color(0xFF3B82F6)},
    {'title': '教育学原理', 'teacher': '赵教授', 'category': '师范', 'progress': 0.15, 'color': const Color(0xFFEC4899)},
    {'title': '英语四级', 'teacher': '吴老师', 'category': '公共课', 'progress': 0.53, 'color': const Color(0xFF8B5CF6)},
    {'title': '线性代数', 'teacher': '周教授', 'category': '基础课', 'progress': 0.88, 'color': const Color(0xFF14B8A6)},
  ];

  List<Map<String, dynamic>> get _filtered {
    if (_selectedCategory == '全部') return _courses;
    return _courses.where((c) => c['category'] == _selectedCategory).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(r.hPadding, r.vPadding, r.hPadding, 0),
              child: Text('课程', style: AppTextStyles.scaled(AppTextStyles.heading, r.scale)),
            ),
            SizedBox(height: r.clamped(12, 8, 16)),
            _buildSearchBar(context),
            SizedBox(height: r.clamped(12, 8, 16)),
            _buildCategoryFilter(context),
            SizedBox(height: r.clamped(16, 10, 24)),
            Expanded(child: _buildCourseGrid(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final r = context.responsive;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: '搜索课程...',
          prefixIcon: Icon(Icons.search, color: Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary),
          suffixIcon: Icon(Icons.filter_list, color: Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context) {
    final r = context.responsive;
    final categories = ['全部', '专业课', '基础课', '师范', '公共课'];
    return SizedBox(
      height: r.clamped(36, 30, 42),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: r.hPadding),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => SizedBox(width: r.clamped(8, 6, 10)),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final selected = _selectedCategory == cat;
          return FilterChip(
            label: Text(cat, style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
            selected: selected,
            onSelected: (_) => setState(() => _selectedCategory = cat),
          );
        },
      ),
    );
  }

  Widget _buildCourseGrid(BuildContext context) {
    final r = context.responsive;
    final filtered = _filtered;
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: r.maxCrossAxisExtent,
        mainAxisSpacing: r.clamped(12, 8, 16),
        crossAxisSpacing: r.clamped(12, 8, 16),
        childAspectRatio: r.courseCardAspectRatio,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final c = filtered[index];
        return CourseCard(
          title: c['title'] as String,
          teacher: c['teacher'] as String,
          category: c['category'] as String,
          progress: c['progress'] as double,
          coverColor: c['color'] as Color,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => _CourseDetailScreen(course: c),
            ));
          },
        );
      },
    );
  }
}

class _CourseDetailScreen extends StatelessWidget {
  final Map<String, dynamic> course;
  const _CourseDetailScreen({required this.course});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final color = course['color'] as Color;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: Text(course['title'] as String)),
        body: Column(
          children: [
            Container(
              height: r.clamped(160, 120, 200),
              margin: EdgeInsets.all(r.hPadding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r.radius),
                gradient: LinearGradient(
                  colors: [color.withAlpha(204), color.withAlpha(51)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school, size: r.clamped(48, 36, 56), color: Colors.white.withAlpha(204)),
                    SizedBox(height: r.clamped(8, 4, 10)),
                    Text(
                      course['teacher'] as String,
                      style: TextStyle(color: Colors.white70, fontSize: r.clamped(14, 12, 16)),
                    ),
                  ],
                ),
              ),
            ),
            TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: Theme.of(context).textTheme.labelSmall?.color ?? AppColors.textMuted,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: '视频'),
                Tab(text: '作业'),
                Tab(text: '签到'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildVideoTab(context),
                  _buildAssignmentTab(context),
                  _buildCheckInTab(context),
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
    final iconSize = r.clamped(48, 40, 56);
    final videos = [
      {'title': '第一章 绪论', 'duration': '45:30', 'watched': true},
      {'title': '第二章 基础理论', 'duration': '52:15', 'watched': true},
      {'title': '第三章 进阶应用', 'duration': '38:20', 'watched': false},
      {'title': '第四章 综合案例', 'duration': '1:02:10', 'watched': false},
    ];

    return ListView.separated(
      padding: EdgeInsets.all(r.hPadding),
      itemCount: videos.length,
      separatorBuilder: (_, _) => SizedBox(height: r.clamped(8, 6, 10)),
      itemBuilder: (context, index) {
        final v = videos[index];
        final watched = v['watched'] as bool;
        return GlassCard(
          padding: EdgeInsets.all(r.clamped(12, 8, 16)),
          child: Row(
            children: [
              Container(
                width: iconSize, height: iconSize,
                decoration: BoxDecoration(
                  color: watched ? AppColors.accent.withAlpha(26) : AppColors.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(r.clamped(10, 8, 12)),
                ),
                child: Icon(
                  watched ? Icons.check_circle : Icons.play_circle,
                  color: watched ? AppColors.accent : AppColors.primary,
                  size: r.clamped(24, 20, 28),
                ),
              ),
              SizedBox(width: r.clamped(12, 8, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v['title'] as String, style: AppTextStyles.scaled(AppTextStyles.bodyBold, r.scale)),
                    SizedBox(height: r.clamped(2, 1, 4)),
                    Text('时长 ${v['duration'] as String}', style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssignmentTab(BuildContext context) {
    final r = context.responsive;
    return ListView(
      padding: EdgeInsets.all(r.hPadding),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BadgeChip(label: '待提交', color: AppColors.warning),
                  const Spacer(),
                  Text('截止: 6月15日', style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
                ],
              ),
              SizedBox(height: r.clamped(8, 4, 10)),
              Text('第一次作业：电路分析报告', style: AppTextStyles.scaled(AppTextStyles.bodyBold, r.scale)),
              SizedBox(height: r.clamped(4, 2, 6)),
              Text('请完成第1-3章的电路分析题目，并提交实验报告。', style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
            ],
          ),
        ),
        SizedBox(height: r.clamped(12, 8, 16)),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BadgeChip(label: '已完成', color: AppColors.success),
                  const Spacer(),
                  Text('已提交: 5月20日', style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
                ],
              ),
              SizedBox(height: r.clamped(8, 4, 10)),
              Text('第二次作业：数字电路设计', style: AppTextStyles.scaled(AppTextStyles.bodyBold, r.scale)),
              SizedBox(height: r.clamped(4, 2, 6)),
              Text('设计一个简单的加法器电路并仿真验证。', style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
            ],
          ),
        ),
        SizedBox(height: r.clamped(12, 8, 16)),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BadgeChip(label: '已批改', color: AppColors.accent),
                  const Spacer(),
                  Text('得分: 92', style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
                ],
              ),
              SizedBox(height: r.clamped(8, 4, 10)),
              Text('第三次作业：模拟电路实验', style: AppTextStyles.scaled(AppTextStyles.bodyBold, r.scale)),
              SizedBox(height: r.clamped(4, 2, 6)),
              Text('搭建并测试一个共射极放大电路。', style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInTab(BuildContext context) {
    final r = context.responsive;
    final iconSize = r.clamped(36, 30, 42);
    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];
    return ListView(
      padding: EdgeInsets.all(r.hPadding),
      children: List.generate(8, (index) {
        final checked = index < 6;
        return GlassCard(
          margin: EdgeInsets.only(bottom: r.clamped(8, 6, 10)),
          padding: EdgeInsets.symmetric(horizontal: r.clamped(16, 12, 20), vertical: r.clamped(12, 8, 16)),
          child: Row(
            children: [
              Container(
                width: iconSize, height: iconSize,
                decoration: BoxDecoration(
                  color: checked ? AppColors.success.withAlpha(26) : (Theme.of(context).textTheme.labelSmall?.color ?? AppColors.textMuted).withAlpha(26),
                  borderRadius: BorderRadius.circular(iconSize / 2),
                ),
                child: Icon(
                  checked ? Icons.check : Icons.close,
                  color: checked ? AppColors.success : Theme.of(context).textTheme.labelSmall?.color ?? AppColors.textMuted,
                  size: iconSize * 0.5,
                ),
              ),
              SizedBox(width: r.clamped(12, 8, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('第${index + 1}周', style: AppTextStyles.scaled(AppTextStyles.body, r.scale)),
                    Text(checked ? '已签到' : '未签到', style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
                  ],
                ),
              ),
              Text('周${weekDays[index % 7]} 08:00', style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
            ],
          ),
        );
      }),
    );
  }
}
