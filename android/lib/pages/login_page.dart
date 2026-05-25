import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../services/auth_provider.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLogin;
  final AuthProvider auth;

  const LoginPage({super.key, required this.onLogin, required this.auth});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _rememberMe = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final user = await widget.auth.getSavedUsername();
    final pass = await widget.auth.getSavedPassword();
    if (user != null && user.isNotEmpty) {
      _usernameCtrl.text = user;
      if (pass != null && pass.isNotEmpty) {
        _passwordCtrl.text = pass;
        _rememberMe = true;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    final user = _usernameCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();
    if (user.isEmpty || pass.isEmpty) {
      setState(() => _error = '请输入用户名和密码');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await widget.auth.login(user, pass, remember: _rememberMe);
    if (!mounted) return;

    if (ok) {
      widget.onLogin();
    } else {
      setState(() {
        _loading = false;
        _error = widget.auth.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final cardWidth = r.isCompact ? double.infinity : r.clamped(400, 340, 480);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF0B0D17), Color(0xFF1A1D2A), Color(0xFF0B0D17)]
                : [AppLightColors.background, AppLightColors.surfaceLight, AppLightColors.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: r.hPadding * 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBranding(context),
                  SizedBox(height: r.clamped(48, 32, 64)),
                  _buildLoginCard(context, cardWidth),
                  SizedBox(height: r.clamped(32, 20, 40)),
                  Text('Edu v1.0.0 · AI + 教育',
                      style: AppTextStyles.scaled(AppTextStyles.small, r.scale)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranding(BuildContext context) {
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
          child: Icon(Icons.school, size: logoSize * 0.55, color: Colors.white),
        ),
        SizedBox(height: r.clamped(20, 14, 26)),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.primary, AppColors.accent, AppColors.purple],
          ).createShader(bounds),
          child: Text(
            'Edu',
            style: TextStyle(
                fontSize: r.clamped(36, 30, 44),
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ),
        SizedBox(height: r.clamped(8, 4, 12)),
        Text('AI + 教育 · 智能教育平台',
            style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context, double cardWidth) {
    final r = context.responsive;
    final theme = Theme.of(context);
    final captionColor =
        theme.textTheme.bodySmall?.color ?? AppColors.textSecondary;
    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: EdgeInsets.all(r.clamped(28, 20, 36)),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(r.radius),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('账号登录',
                style: AppTextStyles.scaled(AppTextStyles.heading, r.scale)),
            SizedBox(height: r.clamped(24, 16, 32)),
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withAlpha(77)),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
            ],
            Text('用户名',
                style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
            SizedBox(height: r.clamped(6, 4, 8)),
            TextField(
              controller: _usernameCtrl,
              enabled: !_loading,
              decoration: InputDecoration(
                hintText: '请输入用户名',
                prefixIcon: Icon(Icons.person_outline, color: captionColor, size: 20),
              ),
              onSubmitted: _loading ? null : (_) => _doLogin(),
            ),
            SizedBox(height: r.clamped(16, 12, 20)),
            Text('密码',
                style: AppTextStyles.scaled(AppTextStyles.caption, r.scale)),
            SizedBox(height: r.clamped(6, 4, 8)),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              enabled: !_loading,
              decoration: InputDecoration(
                hintText: '请输入密码',
                prefixIcon: Icon(Icons.lock_outline, color: captionColor, size: 20),
              ),
              onSubmitted: _loading ? null : (_) => _doLogin(),
            ),
            SizedBox(height: r.clamped(16, 12, 20)),
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _rememberMe ? Icons.check_box : Icons.check_box_outline_blank,
                        color: _rememberMe ? AppColors.primary : captionColor,
                        size: r.clamped(18, 16, 20),
                      ),
                      SizedBox(width: r.clamped(6, 4, 8)),
                      Text('记住密码',
                          style: AppTextStyles.scaled(
                              AppTextStyles.caption, r.scale)),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Text('忘记密码？',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: r.clamped(12, 11, 14))),
                ),
              ],
            ),
            SizedBox(height: r.clamped(24, 16, 32)),
            SizedBox(
              width: double.infinity,
              height: r.clamped(48, 42, 54),
              child: ElevatedButton(
                onPressed: _loading ? null : _doLogin,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('登  录'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
