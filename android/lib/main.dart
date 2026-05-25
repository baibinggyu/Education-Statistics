import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'theme/responsive.dart';
import 'services/auth_provider.dart';
import 'pages/home_page.dart';
import 'pages/courses_page.dart';
import 'pages/messages_page.dart';
import 'pages/profile_page.dart';
import 'pages/login_page.dart';
import 'pages/announcement_page.dart';
import 'pages/roll_call_page.dart';
import 'pages/countdown_page.dart';
import 'pages/video_player_page.dart';
import 'pages/student_info_page.dart';

void main() {
  runApp(const EduApp());
}

class EduApp extends StatefulWidget {
  const EduApp({super.key});

  @override
  State<EduApp> createState() => _EduAppState();
}

class _EduAppState extends State<EduApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edu - AI + 教育',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: AppShell(onToggleTheme: _toggleTheme),
      onGenerateRoute: (settings) {
        // Named routes for pages pushed from shortcuts
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
          case '/roll-call':
            if (args is String) {
              return MaterialPageRoute(
                builder: (_) => RollCallPage(courseUuid: args),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const RollCallPage(),
            );
          case '/countdown':
            return MaterialPageRoute(
              builder: (_) => const CountdownPage(),
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
          default:
            return null;
        }
      },
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
      ProfilePage(auth: _auth, onToggleTheme: widget.onToggleTheme, onLogout: _onLogout),
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

  void _onLoginSuccess() {
    setState(() => _loggedIn = true);
  }

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
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_loggedIn) {
      return LoginPage(auth: _auth, onLogin: _onLoginSuccess);
    }

    final r = Responsive.of(context);
    final body = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxContentWidth),
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
    );

    if (r.isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) => setState(() => _currentIndex = index),
              backgroundColor: Theme.of(context).colorScheme.surface,
              indicatorColor: AppColors.primary,
              selectedIconTheme: const IconThemeData(color: AppColors.primary),
              unselectedIconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
              selectedLabelTextStyle:
                  const TextStyle(color: AppColors.primary, fontSize: 11),
              unselectedLabelTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                fontSize: 11),
              destinations: const [
                NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('首页')),
                NavigationRailDestination(
                    icon: Icon(Icons.book_outlined),
                    selectedIcon: Icon(Icons.book),
                    label: Text('课程')),
                NavigationRailDestination(
                    icon: Icon(Icons.message_outlined),
                    selectedIcon: Icon(Icons.message),
                    label: Text('消息')),
                NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: Text('我的')),
              ],
            ),
            VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '首页'),
          BottomNavigationBarItem(
              icon: Icon(Icons.book_outlined),
              activeIcon: Icon(Icons.book),
              label: '课程'),
          BottomNavigationBarItem(
              icon: Icon(Icons.message_outlined),
              activeIcon: Icon(Icons.message),
              label: '消息'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '我的'),
        ],
      ),
    );
  }
}
