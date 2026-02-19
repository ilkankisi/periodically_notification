import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'services/firebase_service.dart';
import 'package:home_widget/home_widget.dart';
import 'screens/home_page.dart';

void appLog(String message) {
  print('[APP-DART] $message');
}

void main() async {
  
  
  WidgetsFlutterBinding.ensureInitialized();
  appLog('main() başladı');
  try {
    appLog('Firebase initialize başlanıyor...');
    await Firebase.initializeApp();
    appLog('Firebase initialize tamamlandı');
    
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
        home: const HomePage(),
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
