import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:media_kit/media_kit.dart';

import 'theme/app_theme.dart';
import 'services/auth_provider.dart';
import 'services/api_client.dart';
import 'pages/home_page.dart';
import 'pages/courses_page.dart';
import 'pages/messages_page.dart';
import 'pages/profile_page.dart';
import 'pages/login_page.dart';
import 'pages/announcement_page.dart';
import 'pages/video_player_page.dart';
import 'pages/student_info_page.dart';
import 'pages/about_page.dart';
import 'pages/personal_info_page.dart';
import 'pages/notifications_page.dart';
import 'pages/downloads_page.dart';
import 'pages/learning_report_page.dart';
import 'pages/student_analysis_page.dart';
import 'pages/report_history_page.dart';
import 'pages/submit_homework_page.dart';
import 'pages/check_in_page.dart';
import 'pages/my_homework_page.dart';

void main() {
  MediaKit.ensureInitialized();
  runApp(const EduApp());
}

class EduApp extends StatefulWidget {
  const EduApp({super.key});

  @override
  State<EduApp> createState() => _EduAppState();
}

class _EduAppState extends State<EduApp> {
  bool _isDark = true;
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final isDark = await ThemeScope.loadFromPrefs();
    if (mounted) {
      setState(() {
        _isDark = isDark;
        _themeLoaded = true;
      });
    }
  }

  void _toggleTheme() {
    final next = !_isDark;
    ThemeScope.saveToPrefs(next);
    setState(() => _isDark = next);
  }

  @override
  Widget build(BuildContext context) {
    final themeData =
        _isDark ? FThemes.blue.dark.desktop : FThemes.blue.light.desktop;

    return WidgetsApp(
      debugShowCheckedModeBanner: false,
      color: const Color(0xFF0f766e),
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return MaterialPageRoute<T>(settings: settings, builder: builder);
      },
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      builder: (context, child) => ThemeScope(
        isDark: _isDark,
        toggle: _toggleTheme,
        child: FTheme(
          data: themeData,
          child: ScaffoldMessenger(
            child: FToaster(
              child: FTooltipGroup(
                child: child!,
              ),
            ),
          ),
        ),
      ),
      home: _themeLoaded ? AppShell(onToggleTheme: _toggleTheme) : _splash(),
      onGenerateRoute: (settings) {
        final args = settings.arguments;
        switch (settings.name) {
          case '/announcements':
            if (args is String) {
              return MaterialPageRoute(
                builder: (_) => AnnouncementPage(courseUuid: args),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const AnnouncementPage(),
            );
          case '/video':
            if (args is String) {
              return MaterialPageRoute(
                builder: (_) => VideoPlayerPage(videoUuid: args),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const VideoPlayerPage(),
            );
          case '/student-info':
            if (args is String) {
              return MaterialPageRoute(
                builder: (_) => StudentInfoPage(courseUuid: args),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const StudentInfoPage(),
            );
          case '/about':
            return MaterialPageRoute(
              builder: (_) => const AboutPage(),
            );
          case '/personal-info':
            return MaterialPageRoute(
              builder: (_) => const PersonalInfoPage(),
            );
          case '/notifications':
            return MaterialPageRoute(
              builder: (_) => NotificationsPage(api: ApiClient()),
            );
          case '/downloads':
            return MaterialPageRoute(
              builder: (_) => DownloadsPage(api: ApiClient()),
            );
          case '/learning-report':
            return MaterialPageRoute(
              builder: (_) => const LearningReportPage(),
            );
          case '/report-history':
            return MaterialPageRoute(
              builder: (_) => const ReportHistoryPage(),
            );
          case '/my-homework':
            return MaterialPageRoute(
              builder: (_) => MyHomeworkPage(auth: AuthProvider()),
            );
          case '/student-analysis':
            if (args is Map<String, String>) {
              return MaterialPageRoute(
                builder: (_) => StudentAnalysisPage(
                  courseUuid: args['courseUuid']!,
                  studentUuid: args['studentUuid']!,
                  studentName: args['studentName']!,
                ),
              );
            }
            return null;
          case '/submit-homework':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => SubmitHomeworkPage(
                  auth: AuthProvider(),
                  courseUuid: args['courseUuid'] as String,
                  assignmentUuid: args['assignmentUuid'] as String,
                  assignment: args['assignment'] as Map<String, dynamic>,
                ),
              );
            }
            return null;
          case '/check-in':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => CheckInPage(
                  auth: AuthProvider(),
                  courseUuid: args['courseUuid'] as String,
                  attendanceUuid: args['attendanceUuid'] as String,
                ),
              );
            }
            return null;
          default:
            return null;
        }
      },
    );
  }

  Widget _splash() {
    return Builder(
      builder: (context) => Container(
        color: context.appColors.background,
        child: const Center(child: FCircularProgress()),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const AppShell({super.key, required this.onToggleTheme});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  bool _loggedIn = false;
  bool _checkingAuth = true;

  final AuthProvider _auth = AuthProvider();
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(auth: _auth),
      CoursesPage(auth: _auth),
      MessagesPage(auth: _auth),
      ProfilePage(
        auth: _auth,
        onToggleTheme: widget.onToggleTheme,
        onLogout: _onLogout,
      ),
    ];
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final ok = await _auth.tryAutoLogin();
    if (mounted) {
      setState(() {
        _loggedIn = ok;
        _checkingAuth = false;
      });
    }
  }

  void _onLoginSuccess() => setState(() => _loggedIn = true);

  void _onLogout() {
    _auth.logout();
    setState(() {
      _loggedIn = false;
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Center(child: FCircularProgress());
    }

    if (!_loggedIn) {
      return LoginPage(auth: _auth, onLogin: _onLoginSuccess);
    }

    final isWide = MediaQuery.of(context).size.width >= 720;
    final colors = context.appColors;

    final body = IndexedStack(
      index: _currentIndex,
      children: _pages,
    );

    if (isWide) {
      return Container(
        color: colors.background,
        child: Row(
          children: [
            FSidebar(
            children: [
              FSidebarItem(
                icon: const Icon(FIcons.house),
                label: const Text('首页'),
                onPress: () => setState(() => _currentIndex = 0),
                selected: _currentIndex == 0,
              ),
              FSidebarItem(
                icon: const Icon(FIcons.book),
                label: const Text('课程'),
                onPress: () => setState(() => _currentIndex = 1),
                selected: _currentIndex == 1,
              ),
              FSidebarItem(
                icon: const Icon(FIcons.mail),
                label: const Text('消息'),
                onPress: () => setState(() => _currentIndex = 2),
                selected: _currentIndex == 2,
              ),
              FSidebarItem(
                icon: const Icon(FIcons.user),
                label: const Text('我的'),
                onPress: () => setState(() => _currentIndex = 3),
                selected: _currentIndex == 3,
              ),
            ],
          ),
          const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return FScaffold(
      footer: FBottomNavigationBar(
        index: _currentIndex,
        onChange: (i) => setState(() => _currentIndex = i),
        children: [
          const FBottomNavigationBarItem(
            icon: Icon(FIcons.house),
            label: Text('首页'),
          ),
          const FBottomNavigationBarItem(
            icon: Icon(FIcons.book),
            label: Text('课程'),
          ),
          const FBottomNavigationBarItem(
            icon: Icon(FIcons.mail),
            label: Text('消息'),
          ),
          const FBottomNavigationBarItem(
            icon: Icon(FIcons.user),
            label: Text('我的'),
          ),
        ],
      ),
      child: body,
    );
  }
}
