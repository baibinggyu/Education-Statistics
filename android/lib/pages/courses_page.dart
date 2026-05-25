import 'package:flutter/material.dart';
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
  String _selectedCategory = '全部';
  List<dynamic> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
    var list = _courses;
    if (_selectedCategory != '全部') {
      list = list.where((c) {
        final role = c['my_role'] as String? ?? '';
        if (_selectedCategory == '教师') return role == 'teacher';
        if (_selectedCategory == '学生') return role == 'student';
        return true;
      }).toList();
    }
    if (query.isNotEmpty) {
      list = list.where((c) {
        final name = (c['name'] as String? ?? '').toLowerCase();
        return name.contains(query);
      }).toList();
    }
    return list;
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
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCourses,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(r.hPadding, r.vPadding, r.hPadding, 0),
                child: Text('课程',
                    style: AppTextStyles.scaled(AppTextStyles.heading, r.scale)),
              ),
              SizedBox(height: r.clamped(12, 8, 16)),
              _buildSearchBar(context),
              SizedBox(height: r.clamped(12, 8, 16)),
              _buildCategoryFilter(context),
              SizedBox(height: r.clamped(16, 10, 24)),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(child: _buildCourseGrid(context)),
            ],
          ),
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
          prefixIcon: Icon(Icons.search,
              color: Theme.of(context).textTheme.bodySmall?.color ??
                  AppColors.textSecondary),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context) {
    final r = context.responsive;
    final categories = ['全部', '教师', '学生'];
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
            label: Text(cat,
                style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
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
        final teacher = c['teacher']?['username'] as String? ?? '';
        final role = c['my_role'] as String? ?? '';
        final uuid = c['uuid'] as String;
        final videoCount = c['video_count'] as int? ?? 0;

        final progress = videoCount > 0 ? 0.5 : 0.0;

        return CourseCard(
          title: name,
          teacher: teacher,
          category: role,
          progress: progress,
          coverColor: _colorForIndex(index),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _CourseDetailScreen(
                  courseUuid: uuid,
                  courseName: name,
                  teacherName: teacher,
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
  final String teacherName;
  final Color color;
  final AuthProvider auth;

  const _CourseDetailScreen({
    required this.courseUuid,
    required this.courseName,
    required this.teacherName,
    required this.color,
    required this.auth,
  });

  @override
  State<_CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<_CourseDetailScreen> {
  List<dynamic> _videos = [];
  List<dynamic> _attendances = [];
  bool _loadingVideos = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadVideos(), _loadAttendance()]);
  }

  Future<void> _loadVideos() async {
    try {
      final videos = await widget.auth.api.listVideos(widget.courseUuid);
      if (mounted) setState(() { _videos = videos; _loadingVideos = false; });
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

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.courseName)),
        body: Column(
          children: [
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school,
                        size: r.clamped(48, 36, 56),
                        color: Colors.white.withAlpha(204)),
                    SizedBox(height: r.clamped(8, 4, 10)),
                    Text(
                      widget.teacherName,
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: r.clamped(14, 12, 16)),
                    ),
                  ],
                ),
              ),
            ),
            TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor:
                  Theme.of(context).textTheme.labelSmall?.color ??
                      AppColors.textMuted,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: '视频'),
                Tab(text: '签到'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildVideoTab(context),
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
    if (_loadingVideos) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_videos.isEmpty) {
      return Center(
        child: Text('暂无视频',
            style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
      );
    }
    final iconSize = r.clamped(48, 40, 56);
    return ListView.separated(
      padding: EdgeInsets.all(r.hPadding),
      itemCount: _videos.length,
      separatorBuilder: (_, _) => SizedBox(height: r.clamped(8, 6, 10)),
      itemBuilder: (context, index) {
        final v = _videos[index];
        final title = v['title'] as String? ?? '';
        final duration = v['duration'] as int? ?? 0;
        final mins = duration ~/ 60;
        final secs = duration % 60;
        final durStr = '$mins:${secs.toString().padLeft(2, '0')}';
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
                child: const Icon(Icons.play_circle,
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
                    SizedBox(height: r.clamped(2, 1, 4)),
                    Text('时长 $durStr',
                        style: AppTextStyles.scaled(
                            AppTextStyles.caption, r.scale)),
                  ],
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
    if (_attendances.isEmpty) {
      return Center(
        child: Text('暂无签到记录',
            style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
      );
    }
    return ListView(
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
                      : AppColors.textMuted.withAlpha(26),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isOpen ? Icons.check : Icons.lock,
                  color: isOpen ? AppColors.success : AppColors.textMuted,
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
                  color: isOpen ? AppColors.success : AppColors.textMuted),
            ],
          ),
        );
      }).toList(),
    );
  }
}
