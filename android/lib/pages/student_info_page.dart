import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../services/api_client.dart';

class StudentInfoPage extends StatefulWidget {
  final String? courseUuid;
  const StudentInfoPage({super.key, this.courseUuid});

  @override
  State<StudentInfoPage> createState() => _StudentInfoPageState();
}

class _StudentInfoPageState extends State<StudentInfoPage> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _summary;
  List<String> _unitNames = [];
  bool _loading = true;

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
      final summary = await _api.getScoreSummary(widget.courseUuid!);
      if (mounted) {
        setState(() {
          _summary = summary;
          _unitNames = (summary['unit_names'] as List?)?.cast<String>() ?? [];
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
    return SafeArea(
      child: Column(
        children: [
          FHeader.nested(
            title: Text(
                _summary?['course_name'] as String? ?? '成绩汇总'),
            prefixes: [
              FButton.icon(
                onPress: () => Navigator.pop(context),
                variant: FButtonVariant.ghost,
                child: const Icon(FIcons.arrowLeft),
              ),
            ],
            suffixes: [
              FButton.icon(
                onPress: _loadData,
                variant: FButtonVariant.ghost,
                child: const Icon(FIcons.refreshCw),
              ),
            ],
          ),
          if (_loading)
            const Expanded(child: Center(child: FCircularProgress()))
          else
            Expanded(
              child: Column(
                children: [
                  SizedBox(height: r.clamped(8, 4, 12)),
                  _buildTableHeader(context),
                  Expanded(child: _buildStudentList(context)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final r = context.responsive;
    final units = _unitNames;
    if (units.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('暂无成绩数据', style: AppTextStyles.caption),
      );
    }
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.hPadding, vertical: r.clamped(10, 6, 14)),
      color: colors.surfaceLight,
      child: Row(
        children: [
          const SizedBox(
              width: 60, child: Text('学号', style: AppTextStyles.caption)),
          const SizedBox(
              width: 60, child: Text('姓名', style: AppTextStyles.caption)),
          ...units.map((name) {
            final short = name.length > 3 ? name.substring(0, 3) : name;
            return SizedBox(
              width: 50,
              child: Text(short, style: AppTextStyles.caption),
            );
          }),
          const Expanded(
              child: Text('总分',
                  style: AppTextStyles.caption, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _buildStudentList(BuildContext context) {
    final r = context.responsive;
    final students = (_summary?['students'] as List?) ?? [];
    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('暂无学生数据',
              style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
        ),
      );
    }
    final colors = context.appColors;
    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final s = students[index] as Map<String, dynamic>;
        final isEven = index % 2 == 0;
        final no = s['student_no'] as String? ?? '';
        final name = s['real_name'] as String? ?? '';
        final scores = (s['scores'] as List?) ?? [];
        final total = s['weighted_total'];
        final totalStr = total != null ? total.toStringAsFixed(1) : '-';

        final studentUuid = s['student_uuid'] as String? ?? '';

        return GestureDetector(
          onTap: () {
            if (studentUuid.isNotEmpty && widget.courseUuid != null) {
              Navigator.pushNamed(
                context,
                '/student-analysis',
                arguments: {
                  'courseUuid': widget.courseUuid!,
                  'studentUuid': studentUuid,
                  'studentName': name.isNotEmpty ? name : no,
                },
              );
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: r.hPadding, vertical: r.clamped(11, 8, 14)),
            color: isEven ? const Color(0x00000000) : colors.cardBg,
            child: Row(
              children: [
                SizedBox(width: 60, child: Text(no, style: AppTextStyles.body)),
                SizedBox(
                    width: 60,
                    child: Text(name, style: AppTextStyles.bodyBold)),
                ..._unitNames.asMap().entries.map((entry) {
                  final i = entry.key;
                  final score = i < scores.length ? scores[i] : null;
                  final scoreStr =
                      score != null ? score.toStringAsFixed(0) : '-';
                  return SizedBox(
                    width: 50,
                    child: Text(scoreStr, style: AppTextStyles.body),
                  );
                }),
                Expanded(
                  child: Text(totalStr,
                      style: AppTextStyles.bodyBold,
                      textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
