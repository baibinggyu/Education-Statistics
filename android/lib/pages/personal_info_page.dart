import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../services/api_client.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _userData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _api.fetchCurrentUser();
      if (mounted) {
        setState(() {
          _userData = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载用户信息失败';
        });
      }
    }
  }

  Future<void> _editUsername() async {
    final ctrl = TextEditingController(text: _api.username ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改用户名'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '请输入新用户名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FButton(
            onPress: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    try {
      await _api.updateMe(username: result);
      await _loadData();
    } catch (_) {}
  }

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
              title: const Text('个人信息'),
            prefixes: [
              FButton.icon(
                onPress: () => Navigator.pop(context),
                variant: FButtonVariant.ghost,
                child: const Icon(FIcons.arrowLeft),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: FCircularProgress())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 16),
                            FButton(
                              onPress: _loadData,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(r.hPadding),
                        child: Column(
                          children: [
                            _buildAvatar(context),
                            SizedBox(height: r.clamped(24, 16, 32)),
                            _buildInfoCard(context),
                          ],
                        ),
                      ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final r = context.responsive;
    final avatarSize = r.clamped(80, 64, 100);
    return Column(
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
              size: avatarSize * 0.55, color: const Color(0xFFFFFFFF)),
        ),
        SizedBox(height: r.clamped(12, 8, 16)),
        Text(_api.username ?? '',
            style: AppTextStyles.scaled(AppTextStyles.subheading, r.scale)),
        SizedBox(height: r.clamped(4, 2, 6)),
        Text(roleLabel(_api.role),
            style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final r = context.responsive;
    final colors = context.appColors;
    final student = _userData?['student'];
    final studentNo = student?['student_no'] as String? ?? '-';
    final realName = student?['real_name'] as String? ?? '-';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.clamped(20, 16, 24)),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('账号信息',
              style: AppTextStyles.scaled(AppTextStyles.subheading, r.scale)),
          SizedBox(height: r.clamped(16, 12, 20)),
          _buildInfoRow(context, '用户名', _api.username ?? '-',
              trailing: FButton.icon(
                onPress: _editUsername,
                variant: FButtonVariant.ghost,
                size: FButtonSizeVariant.sm,
                child: const Icon(FIcons.pencil, size: 16),
              )),
          _buildInfoRow(context, '角色', roleLabel(_api.role)),
          _buildInfoRow(context, 'UUID', _api.userUuid ?? '-'),
          if (_api.role == 'student') ...[
            SizedBox(height: r.clamped(8, 4, 12)),
            Container(
              padding: EdgeInsets.all(r.clamped(12, 8, 16)),
              decoration: BoxDecoration(
                color: colors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('学生档案',
                      style: AppTextStyles.scaled(
                          AppTextStyles.bodyBold, r.scale)),
                  SizedBox(height: r.clamped(8, 4, 12)),
                  _buildInfoRow(context, '学号', studentNo),
                  _buildInfoRow(context, '姓名', realName),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value,
      {Widget? trailing}) {
    final r = context.responsive;
    return Padding(
      padding: EdgeInsets.only(bottom: r.clamped(12, 8, 14)),
      child: Row(
        children: [
          SizedBox(
            width: r.clamped(60, 50, 70),
            child: Text(label,
                style: AppTextStyles.scaled(
                    AppTextStyles.caption, r.scale)),
          ),
          Expanded(
            child: Text(value,
                style: AppTextStyles.scaled(
                    AppTextStyles.body, r.scale),
                overflow: TextOverflow.ellipsis),
          ),
          ?trailing,
        ],
      ),
    );
  }

  String roleLabel(String? role) {
    return role == 'teacher'
        ? '教师'
        : role == 'admin'
            ? '管理员'
            : '学生';
  }
}
