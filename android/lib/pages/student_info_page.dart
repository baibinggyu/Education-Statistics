import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';


class StudentInfoPage extends StatefulWidget {
  const StudentInfoPage({super.key});

  @override
  State<StudentInfoPage> createState() => _StudentInfoPageState();
}

class _StudentInfoPageState extends State<StudentInfoPage> {
  String _selectedClass = '全部';

  final List<Map<String, String>> _students = [
    {'no': '20240001', 'name': '张三', 'class': '电子技术1班', 'unit1': '92', 'unit2': '88', 'unit3': '95', 'unit4': '90'},
    {'no': '20240002', 'name': '李四', 'class': '电子技术1班', 'unit1': '85', 'unit2': '90', 'unit3': '78', 'unit4': '82'},
    {'no': '20240003', 'name': '王五', 'class': '电子技术2班', 'unit1': '76', 'unit2': '72', 'unit3': '80', 'unit4': '75'},
    {'no': '20240004', 'name': '赵六', 'class': '电子技术1班', 'unit1': '98', 'unit2': '96', 'unit3': '94', 'unit4': '99'},
    {'no': '20240005', 'name': '孙七', 'class': '电子技术2班', 'unit1': '68', 'unit2': '65', 'unit3': '70', 'unit4': '72'},
    {'no': '20240006', 'name': '周八', 'class': '电子技术1班', 'unit1': '88', 'unit2': '82', 'unit3': '85', 'unit4': '91'},
    {'no': '20240007', 'name': '吴九', 'class': '电子技术3班', 'unit1': '73', 'unit2': '78', 'unit3': '75', 'unit4': '70'},
    {'no': '20240008', 'name': '郑十', 'class': '电子技术2班', 'unit1': '91', 'unit2': '93', 'unit3': '89', 'unit4': '87'},
    {'no': '20240009', 'name': '陈一一', 'class': '电子技术3班', 'unit1': '82', 'unit2': '80', 'unit3': '85', 'unit4': '79'},
    {'no': '20240010', 'name': '刘二三', 'class': '电子技术1班', 'unit1': '77', 'unit2': '74', 'unit3': '71', 'unit4': '76'},
  ];

  List<Map<String, String>> get _filtered {
    if (_selectedClass == '全部') return _students;
    return _students.where((s) => s['class'] == _selectedClass).toList();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Scaffold(
      appBar: AppBar(title: const Text('学生信息')),
      body: Column(
        children: [
          _buildSearchAndFilter(context),
          SizedBox(height: r.clamped(8, 4, 12)),
          _buildTableHeader(context),
          Expanded(child: _buildStudentList(context)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(BuildContext context) {
    final r = context.responsive;
    final classes = ['全部', '电子技术1班', '电子技术2班', '电子技术3班'];

    return Padding(
      padding: EdgeInsets.all(r.hPadding),
      child: Column(
        children: [
          const TextField(
            decoration: InputDecoration(
              hintText: '搜索学生...',
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
            ),
          ),
          SizedBox(height: r.clamped(10, 6, 14)),
          SizedBox(
            height: r.clamped(32, 28, 38),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: classes.length,
              separatorBuilder: (_, _) => SizedBox(width: r.clamped(8, 6, 10)),
              itemBuilder: (context, index) {
                final cls = classes[index];
                final selected = _selectedClass == cls;
                return FilterChip(
                  label: Text(cls, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedClass = cls),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final r = context.responsive;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.hPadding, vertical: r.clamped(10, 6, 14)),
      color: Theme.of(context).inputDecorationTheme.fillColor ?? AppColors.surfaceLight,
      child: const Row(
        children: [
          SizedBox(width: 60, child: Text('学号', style: AppTextStyles.caption)),
          SizedBox(width: 60, child: Text('姓名', style: AppTextStyles.caption)),
          Expanded(child: Text('班级', style: AppTextStyles.caption)),
          SizedBox(width: 44, child: Text('一', style: AppTextStyles.caption)),
          SizedBox(width: 44, child: Text('二', style: AppTextStyles.caption)),
          SizedBox(width: 44, child: Text('三', style: AppTextStyles.caption)),
          SizedBox(width: 44, child: Text('四', style: AppTextStyles.caption)),
        ],
      ),
    );
  }

  Widget _buildStudentList(BuildContext context) {
    final r = context.responsive;
    final filtered = _filtered;
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final s = filtered[index];
        final isEven = index % 2 == 0;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: r.hPadding, vertical: r.clamped(11, 8, 14)),
          color: isEven ? Colors.transparent : AppColors.cardBg,
          child: Row(
            children: [
              SizedBox(width: 60, child: Text(s['no']!, style: AppTextStyles.body)),
              SizedBox(width: 60, child: Text(s['name']!, style: AppTextStyles.bodyBold)),
              Expanded(child: Text(s['class']!, style: AppTextStyles.caption)),
              SizedBox(width: 44, child: Text(s['unit1']!, style: AppTextStyles.body)),
              SizedBox(width: 44, child: Text(s['unit2']!, style: AppTextStyles.body)),
              SizedBox(width: 44, child: Text(s['unit3']!, style: AppTextStyles.body)),
              SizedBox(width: 44, child: Text(s['unit4']!, style: AppTextStyles.body)),
            ],
          ),
        );
      },
    );
  }
}
