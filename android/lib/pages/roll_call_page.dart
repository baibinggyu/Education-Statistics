import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';
import '../services/api_client.dart';

class RollCallPage extends StatefulWidget {
  final String? courseUuid;
  const RollCallPage({super.key, this.courseUuid});

  @override
  State<RollCallPage> createState() => _RollCallPageState();
}

class _RollCallPageState extends State<RollCallPage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _members = [];
  List<dynamic> _attendances = [];
  bool _loading = true;
  int _drawCount = 3;
  bool _showClass = true;
  final List<Map<String, String>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.courseUuid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _api.listMembers(widget.courseUuid!),
        _api.listAttendances(widget.courseUuid!),
      ]);
      if (mounted) {
        setState(() {
          _members = results[0];
          _attendances = results[1];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _draw() {
    final students = _members
        .where((m) => m['member_role'] == 'student')
        .toList();
    if (students.isEmpty) return;
    setState(() {
      students.shuffle();
      final drawn = students.take(_drawCount).map((m) {
        return {
          'name': m['student']?['real_name'] as String? ??
              (m['username'] as String? ?? ''),
          'id': m['student']?['student_no'] as String? ?? '',
        };
      }).toList();
      _history.insertAll(0, drawn);
    });
  }

  Future<void> _startAttendance() async {
    if (widget.courseUuid == null) return;
    try {
      await _api.startAttendance(widget.courseUuid!, '课堂签到');
      await _loadData();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Scaffold(
      appBar: AppBar(
        title: const Text('点名'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(r.hPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildControlPanel(),
                  SizedBox(height: r.clamped(16, 10, 24)),
                  if (_history.isNotEmpty) ...[
                    _buildResultCard(),
                    SizedBox(height: r.clamped(16, 10, 24)),
                  ],
                  _buildAttendanceHistory(),
                  SizedBox(height: r.clamped(16, 10, 24)),
                  SectionHeader(title: '课程成员 (${_members.length})'),
                  SizedBox(height: r.clamped(8, 4, 12)),
                  _buildMemberList(),
                ],
              ),
            ),
    );
  }

  Widget _buildControlPanel() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('点名控制台', style: AppTextStyles.subheading),
          const SizedBox(height: 4),
          Text(
              '从 ${_members.where((m) => m['member_role'] == 'student').length} 名学生中随机抽取',
              style: AppTextStyles.caption),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('抽取人数', style: AppTextStyles.body),
              const Spacer(),
              _buildCountButton(-1, Icons.remove),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$_drawCount', style: AppTextStyles.subheading),
              ),
              _buildCountButton(1, Icons.add),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('显示班级', style: AppTextStyles.body),
              const Spacer(),
              Switch(
                value: _showClass,
                onChanged: (v) => setState(() => _showClass = v),
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _draw,
                  child: const Text('开始点名'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _startAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('发起签到'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountButton(int delta, IconData icon) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _drawCount = (_drawCount + delta).clamp(1, 15);
        });
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor ??
              AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _buildResultCard() {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('点名结果', style: AppTextStyles.subheading),
          const SizedBox(height: 4),
          Text('已抽取 $_drawCount 名学生', style: AppTextStyles.caption),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withAlpha(77)),
            ),
            child: Column(
              children: _history.take(_drawCount).map((s) {
                final index = _history.take(_drawCount).toList().indexOf(s);
                return Padding(
                  padding:
                      EdgeInsets.only(bottom: index < _drawCount - 1 ? 8 : 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s['name']!,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                      const SizedBox(width: 8),
                      Text(s['id']!, style: AppTextStyles.caption),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHistory() {
    if (_attendances.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '签到记录'),
        SizedBox(height: context.responsive.clamped(8, 4, 12)),
        ..._attendances.take(5).map((a) {
          final title = a['title'] as String? ?? '';
          final status = a['status'] as String? ?? '';
          final present = a['present_count'] as int? ?? 0;
          final total = a['total'] as int? ?? 0;
          final isOpen = status == 'open';
          return GlassCard(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isOpen ? Icons.check_circle : Icons.lock,
                  color: isOpen ? AppColors.success : AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: AppTextStyles.body)),
                Text('$present/$total',
                    style: AppTextStyles.caption),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMemberList() {
    final students = _members
        .where((m) => m['member_role'] == 'student')
        .toList();
    if (students.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('暂无成员', style: AppTextStyles.caption),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final m = students[index];
        final name = m['student']?['real_name'] as String? ??
            (m['username'] as String? ?? '');
        final no = m['student']?['student_no'] as String? ?? '';
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Text(name, style: AppTextStyles.bodyBold),
              const Spacer(),
              Text(no, style: AppTextStyles.small),
            ],
          ),
        );
      },
    );
  }
}
