import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'services/firebase_service.dart';
import 'package:home_widget/home_widget.dart';
import 'screens/home_page.dart';
import 'screens/explore_page.dart';
import 'screens/saved_page.dart';
import 'widgets/bottom_nav_bar.dart';

void appLog(String message) {
  print('[APP-DART] $message');
}

Future<void> _initializeFirebaseWithRetry({int maxAttempts = 3}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      appLog('Firebase initialize deneme $attempt/$maxAttempts...');
      await Firebase.initializeApp();
      appLog('Firebase initialize tamamlandı');
      return;
    } on Exception catch (e) {
      final isChannelError = e.toString().contains('channel-error') ||
          e.toString().contains('FirebaseCoreHostApi');
      if (isChannelError && attempt < maxAttempts) {
        appLog('Kanal henüz hazır değil, ${200 * attempt}ms sonra tekrar denenecek...');
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      } else {
        rethrow;
      }
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appLog('main() başladı');
  try {
    await _initializeFirebaseWithRetry();

    await FirebaseService.initialize();
    appLog('FirebaseService setup tamamlandı');

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
      final title = await HomeWidget.getWidgetData<String>('widget_title', defaultValue: 'Günün İçeriği');
      final body = await HomeWidget.getWidgetData<String>('widget_body', defaultValue: 'Veri bekleniyor...');
      final updatedAt = await HomeWidget.getWidgetData<String>('widget_updatedAt', defaultValue: '');
      
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

  Future<void> _sendTestNotification() async {
    appLog('Test notification gönderiliyor...');
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('manualSendDailyContent')
          .call();
      
      appLog('✅ Test notification gönderildi: ${result.data}');
      
      // Veriyi yenile
      await Future.delayed(const Duration(seconds: 1));
      _loadWidgetData();
    } catch (e) {
      appLog('❌ Test notification hatası: $e');
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
        title: 'Periodically Notification',
        debugShowCheckedModeBanner: false,
        home: const _MainShell(),
      );
    } catch (e, st) {
      appLog('ERROR _MyAppState.build: $e');
      appLog('Stack trace: $st');
      return MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Error: $e')),
        ),
      );
    }
  }

  @override
  void dispose() {
    appLog('_MyAppState.dispose() çağrıldı');
    super.dispose();
  }
}

/// Ana Sayfa / Keşfet sekmeleri ve ortak alt navigasyon.
class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(showBottomBar: false, onTabTap: _onTabTap),
          ExplorePage(showBottomBar: false, onTabTap: _onTabTap),
          SavedPage(showBottomBar: false, onTabTap: _onTabTap),
          _PlaceholderPage(title: 'Profil', onTabTap: _onTabTap),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        activeIndex: _currentIndex,
        onTabTap: _onTabTap,
      ),
    );
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title, required this.onTabTap});

  final String title;
  final ValueChanged<int> onTabTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      bottomNavigationBar: BottomNavBar(activeIndex: 3, onTabTap: onTabTap),
    );
  }
}
