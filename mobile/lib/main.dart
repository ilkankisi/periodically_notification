import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'services/api_config.dart';
import 'services/auth_service.dart';
import 'services/backend_service.dart';
import 'services/onboarding_service.dart';
import 'services/push_notification_service.dart';
import 'package:home_widget/home_widget.dart';
import 'screens/home_page.dart';
import 'screens/explore_page.dart';
import 'screens/saved_page.dart';
import 'screens/profile_page.dart';
import 'screens/value_proposition_onboarding.dart';
import 'widgets/bottom_nav_bar.dart';

void appLog(String message) {
  print('[APP-DART] $message');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appLog('main() başladı');
  try {
    ApiConfig.debugLogResolvedUrl();
    await BackendService.loadStoredToken();
    await AuthService.loadCachedSession();
    appLog('BackendService + AuthService oturum yüklendi');

    await PushNotificationService.initialize();
    appLog('PushNotificationService setup tamamlandı');

    runApp(const MyApp());
    appLog('runApp() tamamlandı');
  } catch (e, st) {
    appLog('ERROR runApp: $e');
    appLog('Stack: $st');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() {
    appLog('MyApp.createState() çağrıldı');
    return _MyAppState();
  }
}

class _MyAppState extends State<MyApp> {
  String widgetTitle = 'Günün İçeriği';
  String widgetBody = 'Yükleniyor...';
  String widgetUpdatedAt = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    appLog('_MyAppState.initState() çağrıldı');
    _loadWidgetData();
  }

  Future<void> _loadWidgetData() async {
    appLog('Widget data yükleniyor...');
    try {
      final title = await HomeWidget.getWidgetData<String>(
        'widget_title',
        defaultValue: 'Günün İçeriği',
      );
      final body = await HomeWidget.getWidgetData<String>(
        'widget_body',
        defaultValue: 'Veri bekleniyor...',
      );
      final updatedAt = await HomeWidget.getWidgetData<String>(
        'widget_updatedAt',
        defaultValue: '',
      );

      appLog('Widget title: $title');
      appLog('Widget body: $body');
      appLog('Widget updatedAt: $updatedAt');

      setState(() {
        widgetTitle = title ?? 'Günün İçeriği';
        widgetBody = body ?? 'Veri bekleniyor...';
        widgetUpdatedAt = updatedAt ?? '';
        isLoading = false;
      });
      appLog('Widget verileri setState ile güncellendi');
    } catch (e) {
      appLog('ERROR Widget data yükleme: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    appLog('_MyAppState.didChangeDependencies() çağrıldı');
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    appLog('_MyAppState.build() başladı');
    try {
      appLog('_MyAppState.build() tamamlandı');
      return MaterialApp(
        title: 'DAHA',
        debugShowCheckedModeBanner: false,
        home: const _AppRoot(),
        builder: (context, child) {
          return GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            behavior: HitTestBehavior.translucent,
            child: child,
          );
        },
      );
    } catch (e, st) {
      appLog('ERROR _MyAppState.build: $e');
      appLog('Stack trace: $st');
      return MaterialApp(
        home: Scaffold(body: Center(child: Text('Error: $e'))),
      );
    }
  }

  @override
  void dispose() {
    appLog('_MyAppState.dispose() çağrıldı');
    super.dispose();
  }
}

/// İlk açılış değer önerisi veya ana kabuk.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _ready = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final done = await OnboardingService.isCompleted();
    if (!mounted) return;
    setState(() {
      _showOnboarding = !done;
      _ready = true;
    });
  }

  void _onboardingFinished() => setState(() => _showOnboarding = false);

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2094F3)),
        ),
      );
    }
    if (_showOnboarding) {
      return ValuePropositionOnboarding(onFinished: _onboardingFinished);
    }
    return const _MainShell();
  }
}

/// Ana Sayfa / Keşfet sekmeleri - iPad'de yan menü, telefonda alt navigasyon
class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _currentIndex = 0;
  final GlobalKey _profileTabKey = GlobalKey();
  bool _profileTabSpotlightScheduled = false;

  static const _destinations = [
    (icon: Icons.home_outlined, label: 'Anasayfa'),
    (icon: Icons.explore_outlined, label: 'Keşfet'),
    (icon: Icons.bookmark_outline, label: 'Kaydedilenler'),
    (icon: Icons.person_outline, label: 'Profil'),
  ];

  @override
  void initState() {
    super.initState();
    OnboardingService.registerTabRequestHandler(_onTabTap);
    unawaited(_prepareDebugTourStart());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowProfileTabSpotlight());
    });
  }

  @override
  void dispose() {
    OnboardingService.registerTabRequestHandler(null);
    super.dispose();
  }

  Future<void> _prepareDebugTourStart() async {
    if (!OnboardingService.kDebugRepeatFullTour) return;
    await OnboardingService.resetFullTourForDebug();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final navBar = BottomNavBar(
      activeIndex: _currentIndex,
      onTabTap: _onTabTap,
      itemKeys: [null, null, null, _profileTabKey],
    );
    final body = IndexedStack(
      index: _currentIndex,
      children: [
        HomePage(showBottomBar: false, onTabTap: _onTabTap),
        ExplorePage(showBottomBar: false, onTabTap: _onTabTap),
        SavedPage(showBottomBar: false, onTabTap: _onTabTap),
        ProfilePage(
          showBottomBar: false,
          onTabTap: _onTabTap,
          isMainShellActiveTab: _currentIndex == 3,
        ),
      ],
    );

    if (isTablet) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: const Color(0xFF1F1F1F),
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabTap,
              labelType: NavigationRailLabelType.all,
              destinations: _destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.icon, color: const Color(0xFF9CA3AF)),
                      selectedIcon: Icon(
                        d.icon,
                        color: const Color(0xFF0095FF),
                      ),
                      label: Text(
                        d.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: body,
      bottomNavigationBar: navBar,
    );
  }

  void _onTabTap(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowProfileTabSpotlight());
    });
  }

  Future<void> _maybeShowProfileTabSpotlight() async {
    if (!mounted || _profileTabSpotlightScheduled) return;
    if (MediaQuery.sizeOf(context).width >= 600) return;
    final ftp = await OnboardingService.getGlobalTourStep();
    if (ftp != OnboardingService.ftNeedProfileTabTap) return;
    _profileTabSpotlightScheduled = true;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted || _profileTabKey.currentContext == null) {
      _profileTabSpotlightScheduled = false;
      return;
    }
    var tapped = false;
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'home_profile_tab_spotlight',
          keyTarget: _profileTabKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          enableTargetTab: true,
          enableOverlayTab: false,
          paddingFocus: 6,
          borderSide: const BorderSide(color: Color(0x400095FF), width: 1.5),
          contents: [
            TargetContent(
              align: ContentAlign.top,
              padding: const EdgeInsets.only(bottom: 12, left: 18, right: 18),
              builder: (context, controller) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C2C2E)),
                ),
                child: const Text(
                  'Profil sayfasına geçmek için sağ alttaki PROFİL sekmesine dokun.',
                  style: TextStyle(
                    color: Color(0xFFE2E2E2),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.78,
      pulseEnable: false,
      alignSkip: Alignment.topRight,
      textSkip: 'Geç',
      onClickTarget: (_) {
        tapped = true;
      },
      onFinish: () {
        if (!tapped) {
          _profileTabSpotlightScheduled = false;
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final moved = await OnboardingService.onHomeProfileTabSpotlightTapped();
          if (!mounted) return;
          _profileTabSpotlightScheduled = false;
          if (moved) _onTabTap(3);
        });
      },
      onSkip: () {
        _profileTabSpotlightScheduled = false;
        return true;
      },
    ).show(context: context);
  }
}
