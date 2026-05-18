import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common_widgets.dart';

class RollCallPage extends StatefulWidget {
  const RollCallPage({super.key});

  @override
  State<RollCallPage> createState() => _RollCallPageState();
}

class _RollCallPageState extends State<RollCallPage> {
  int _drawCount = 3;
  String _drawMode = '随机';
  bool _showClass = true;
  final List<Map<String, String>> _history = [];

  final List<String> _allStudents = [
    '张三', '李四', '王五', '赵六', '孙七',
    '周八', '吴九', '郑十', '陈一一', '刘二三',
  ];

  void _draw() {
    setState(() {
      _allStudents.shuffle();
      final drawn = _allStudents.take(_drawCount).map((n) => {'name': n, 'id': '2024${1000 + (_allStudents.indexOf(n) + 1)}'}).toList();
      _history.insertAll(0, drawn);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Scaffold(
      appBar: AppBar(title: const Text('点名')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(r.hPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildControlPanel(),
            const SizedBox(height: 20),
            if (_history.isNotEmpty) ...[
              _buildResultCard(),
              const SizedBox(height: 20),
            ],
            const SectionHeader(title: '点名记录'),
            _buildHistoryList(),
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
          const Text('从学生名单中随机抽取', style: AppTextStyles.caption),
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
              const Text('抽取模式', style: AppTextStyles.body),
              const Spacer(),
              _buildModeChip('随机'),
              const SizedBox(width: 8),
              _buildModeChip('少重复'),
              const SizedBox(width: 8),
              _buildModeChip('未点名'),
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
                  onPressed: () => setState(() => _history.clear()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).inputDecorationTheme.fillColor ?? AppColors.surfaceLight,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: const Text('重置记录'),
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
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor ?? AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _buildModeChip(String mode) {
    final selected = _drawMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _drawMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(26) : Theme.of(context).inputDecorationTheme.fillColor ?? AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.primary : Theme.of(context).dividerColor),
        ),
        child: Text(
          mode,
          style: TextStyle(
            fontSize: 12,
            color: selected ? AppColors.primary : Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary,
          ),
        ),
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
                  padding: EdgeInsets.only(bottom: index < _drawCount - 1 ? 8 : 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${s['name']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      const SizedBox(width: 8),
                      Text('${s['id']}', style: AppTextStyles.caption),
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

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('暂无点名记录', style: AppTextStyles.caption)),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final s = _history[index];
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text('${index + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Text(s['name']!, style: AppTextStyles.bodyBold),
              const Spacer(),
              Text(s['id']!, style: AppTextStyles.small),
            ],
          ),
        );
      },
    );
  }
}
