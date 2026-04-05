import 'package:flutter/material.dart';

import '../models/notification_entry.dart';
import '../services/notification_badge_controller.dart';
import '../services/notification_store_service.dart';
import '../widgets/app_top_bar.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<NotificationEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _bootstrap();
  }

  Future<List<NotificationEntry>> _bootstrap() async {
    await NotificationStoreService.syncFromBackend();
    await NotificationStoreService.markAllRead();
    await NotificationBadgeController.instance.refresh();
    return NotificationStoreService.loadAll();
  }

  Future<void> _reload() async {
    await NotificationStoreService.syncFromBackend();
    if (!mounted) return;
    final data = await NotificationStoreService.loadAll();
    if (!mounted) return;
    setState(() {
      _future = Future.value(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: const AppTopBar(
        title: 'Bildirimler',
        showBackButton: true,
      ),
      body: FutureBuilder<List<NotificationEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2094F3)),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              color: Colors.white,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 64),
                  Center(
                    child: Text(
                      'Henüz bir bildirim yok.',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            color: Colors.white,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: Color(0xFF1F2933),
              ),
              itemBuilder: (context, index) {
                final n = items[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        n.body,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(n.createdAt),
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = [
        'Ocak',
        'Şubat',
        'Mart',
        'Nisan',
        'Mayıs',
        'Haziran',
        'Temmuz',
        'Ağustos',
        'Eylül',
        'Ekim',
        'Kasım',
        'Aralık',
      ];
      final month = months[dt.month - 1];
      return '${dt.day} $month ${dt.year} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
