import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'screens/explore_page.dart';
import 'screens/home_page.dart';
import 'screens/profile_page.dart';
import 'screens/saved_page.dart';
import 'screens/service_unavailable_page.dart';
import 'screens/value_proposition_onboarding.dart';
import 'services/api_config.dart';
import 'services/auth_service.dart';
import 'services/backend_service.dart';
import 'services/onboarding_service.dart';
import 'services/push_notification_service.dart';
import 'services/reachability_service.dart';
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

class _AppRootState extends State<_AppRoot> with WidgetsBindingObserver {
  bool _ready = false;
  bool _showOnboarding = false;
  bool _reachabilityReady = false;
  bool _reachabilityOk = false;
  ReachabilityResult _lastReachability =
      const ReachabilityResult(ReachabilityKind.serverUnreachable);
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _connectivityDebounce;
  int _gateEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivityDebounce?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_ready || _showOnboarding || _reachabilityOk) return;
    unawaited(_runReachabilityGate());
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!_ready || _showOnboarding || _reachabilityOk) return;
    _connectivityDebounce?.cancel();
    _connectivityDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (!_ready || _showOnboarding || _reachabilityOk) return;
      unawaited(_runReachabilityGate());
    });
  }

  Future<void> _runReachabilityGate() async {
    if (!_ready || _showOnboarding) return;
    final epoch = ++_gateEpoch;
    if (mounted) {
      setState(() => _reachabilityReady = false);
    }
    final result = await ReachabilityService.check();
    if (!mounted || epoch != _gateEpoch) return;
    setState(() {
      _reachabilityReady = true;
      _reachabilityOk = result.isOk;
      _lastReachability = result;
    });
  }

  Future<void> _load() async {
    final done = await OnboardingService.isCompleted();
    if (!mounted) return;
    setState(() {
      _showOnboarding = !done;
      _ready = true;
    });
    if (done) {
      unawaited(_runReachabilityGate());
    }
  }

  void _onboardingFinished() {
    setState(() => _showOnboarding = false);
    unawaited(_runReachabilityGate());
  }

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
    if (!_reachabilityReady) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2094F3)),
        ),
      );
    }
    if (!_reachabilityOk) {
      return ServiceUnavailablePage(
        lastResult: _lastReachability,
        onRetry: _runReachabilityGate,
      );
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
  final GlobalKey _exploreTabKey = GlobalKey();
  final GlobalKey _savedTabKey = GlobalKey();
  final GlobalKey _exploreRailIdleKey = GlobalKey();
  final GlobalKey _exploreRailSelectedKey = GlobalKey();
  final GlobalKey _savedRailIdleKey = GlobalKey();
  final GlobalKey _savedRailSelectedKey = GlobalKey();
  bool _profileTabSpotlightScheduled = false;
  bool _postBadgesExploreTabSpotlightScheduled = false;
  bool _postBadgesSavedTabSpotlightScheduled = false;
  StreamSubscription<List<ConnectivityResult>>? _spotlightConnectivitySub;
  bool _spotlightNetworkOk = true;

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
    _spotlightConnectivitySub =
        Connectivity().onConnectivityChanged.listen(_onSpotlightConnectivity);
    unawaited(_syncSpotlightConnectivity());
    unawaited(_prepareDebugTourStart());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowProfileTabSpotlight());
      unawaited(_maybeShowPostBadgesExploreTabSpotlight());
      unawaited(_maybeShowPostBadgesSavedTabSpotlight());
    });
  }

  void _onSpotlightConnectivity(List<ConnectivityResult> results) {
    final ok = results.any((r) => r != ConnectivityResult.none);
    if (!mounted) return;
    setState(() => _spotlightNetworkOk = ok);
  }

  Future<void> _syncSpotlightConnectivity() async {
    try {
      final r = await Connectivity().checkConnectivity();
      final ok = r.any((x) => x != ConnectivityResult.none);
      if (mounted) setState(() => _spotlightNetworkOk = ok);
    } on Object catch (_) {
      if (mounted) setState(() => _spotlightNetworkOk = false);
    }
  }

  @override
  void dispose() {
    _spotlightConnectivitySub?.cancel();
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
      itemKeys: [null, _exploreTabKey, _savedTabKey, _profileTabKey],
    );
    final body = IndexedStack(
      index: _currentIndex,
      children: [
        HomePage(showBottomBar: false, onTabTap: _onTabTap),
        ExplorePage(
          showBottomBar: false,
          onTabTap: _onTabTap,
          shellTabIndex: _currentIndex,
        ),
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
              destinations: [
                for (var i = 0; i < _destinations.length; i++)
                  NavigationRailDestination(
                    icon: _railLeadingIcon(i, false),
                    selectedIcon: _railLeadingIcon(i, true),
                    label: Text(
                      _destinations[i].label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
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

  /// NavigationRail hem [icon] hem [selectedIcon] ağacında tuttuğu için iki ayrı anahtar.
  GlobalKey _pickRailSpotlightKey(GlobalKey idle, GlobalKey selected) {
    if (selected.currentContext != null) return selected;
    if (idle.currentContext != null) return idle;
    return selected;
  }

  Widget _railLeadingIcon(int index, bool selected) {
    final d = _destinations[index];
    final icon = Icon(
      d.icon,
      color: selected
          ? const Color(0xFF0095FF)
          : const Color(0xFF9CA3AF),
    );
    final GlobalKey? key;
    if (index == 1) {
      key = selected ? _exploreRailSelectedKey : _exploreRailIdleKey;
    } else if (index == 2) {
      key = selected ? _savedRailSelectedKey : _savedRailIdleKey;
    } else {
      key = null;
    }
    if (key != null) return KeyedSubtree(key: key, child: icon);
    return icon;
  }

  void _onTabTap(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowProfileTabSpotlight());
      unawaited(_maybeShowPostBadgesExploreTabSpotlight());
      unawaited(_maybeShowPostBadgesSavedTabSpotlight());
    });
  }

  Future<void> _maybeShowProfileTabSpotlight() async {
    if (!mounted || _profileTabSpotlightScheduled) return;
    if (!_spotlightNetworkOk) return;
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

  Future<void> _maybeShowPostBadgesExploreTabSpotlight() async {
    if (!mounted || _postBadgesExploreTabSpotlightScheduled) return;
    if (!_spotlightNetworkOk) return;
    final ftp = await OnboardingService.getGlobalTourStep();
    if (ftp != OnboardingService.ftPostBadgesExploreTab) return;
    _postBadgesExploreTabSpotlightScheduled = true;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) {
      _postBadgesExploreTabSpotlightScheduled = false;
      return;
    }
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final GlobalKey key = isTablet
        ? _pickRailSpotlightKey(_exploreRailIdleKey, _exploreRailSelectedKey)
        : _exploreTabKey;
    if (key.currentContext == null) {
      _postBadgesExploreTabSpotlightScheduled = false;
      return;
    }
    var tapped = false;
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'post_badges_explore_tab_spotlight',
          keyTarget: key,
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
                  'Keşfet sekmesine dokunarak yeni içeriklere göz at.',
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
          _postBadgesExploreTabSpotlightScheduled = false;
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final moved = await OnboardingService.onPostBadgesExploreTabTapped();
          if (!mounted) return;
          _postBadgesExploreTabSpotlightScheduled = false;
          if (moved) _onTabTap(1);
        });
      },
      onSkip: () {
        _postBadgesExploreTabSpotlightScheduled = false;
        return true;
      },
    ).show(context: context);
  }

  Future<void> _maybeShowPostBadgesSavedTabSpotlight() async {
    if (!mounted || _postBadgesSavedTabSpotlightScheduled) return;
    if (!_spotlightNetworkOk) return;
    final ftp = await OnboardingService.getGlobalTourStep();
    if (ftp != OnboardingService.ftPostBadgesSavedTab) return;
    _postBadgesSavedTabSpotlightScheduled = true;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) {
      _postBadgesSavedTabSpotlightScheduled = false;
      return;
    }
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final GlobalKey key = isTablet
        ? _pickRailSpotlightKey(_savedRailIdleKey, _savedRailSelectedKey)
        : _savedTabKey;
    if (key.currentContext == null) {
      _postBadgesSavedTabSpotlightScheduled = false;
      return;
    }
    var tapped = false;
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'post_badges_saved_tab_spotlight',
          keyTarget: key,
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
                  'Kaydettiğin içerikleri Kaydedilenler sekmesinde bulursun; sekmeye dokun.',
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
          _postBadgesSavedTabSpotlightScheduled = false;
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final moved = await OnboardingService.onPostBadgesSavedTabTapped();
          if (!mounted) return;
          _postBadgesSavedTabSpotlightScheduled = false;
          if (moved) _onTabTap(2);
        });
      },
      onSkip: () {
        _postBadgesSavedTabSpotlightScheduled = false;
        return true;
      },
    ).show(context: context);
  }
}
