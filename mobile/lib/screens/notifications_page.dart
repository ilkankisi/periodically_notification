import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  static const Color _accent = Color(0xFFA1C9FF);
  static const Color _accentSoft = Color(0x1AA1C9FF);
  static const Color _borderSubtle = Color(0x14FFFFFF);
  static const Color _card = Color(0xFF1F1F1F);
  static const Color _muted = Color(0xFFBFC7D5);

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
      backgroundColor: const Color(0xFF131313),
      appBar: const AppTopBar(
        title: 'Bildirimler',
        showBackButton: true,
      ),
      body: FutureBuilder<List<NotificationEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0095FF)),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return _buildEmptyState();
          }
          return _buildFilledList(items);
        },
      ),
    );
  }

  Widget _buildFilledList(List<NotificationEntry> items) {
    final unread = items.where((e) => !e.read).length;

    return RefreshIndicator(
      onRefresh: _reload,
      color: const Color(0xFF0095FF),
      edgeOffset: 12,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Son bildirimler',
                  style: GoogleFonts.newsreader(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _borderSubtle),
                ),
                child: Text(
                  '${items.length} kayıt',
                  style: GoogleFonts.notoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _accent,
                  ),
                ),
              ),
            ],
          ),
          if (unread > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$unread okunmamış',
              style: GoogleFonts.notoSans(
                fontSize: 13,
                color: const Color(0xFF0095FF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _NotificationCard(
              entry: items[i],
              formatDate: _formatDate,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _reload,
      color: const Color(0xFF0095FF),
      edgeOffset: 24,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        children: [
          SizedBox(height: MediaQuery.paddingOf(context).top > 0 ? 16 : 40),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _accentSoft,
                shape: BoxShape.circle,
                border: Border.all(color: _borderSubtle),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: _accent,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Henüz bildirim yok',
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Yeni içerik, hatırlatmalar veya güncellemeler geldiğinde burada listelenir.',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(
              fontSize: 15,
              height: 1.5,
              color: _muted,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.swipe_down_rounded, color: _accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aşağı çekerek listeyi yenileyebilirsin; bildirimler cihazına düştükçe burada birikir.',
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      height: 1.45,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 120),
        ],
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
      return '${dt.day} $month ${dt.year} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.entry,
    required this.formatDate,
  });

  final NotificationEntry entry;
  final String Function(String iso) formatDate;

  static const Color _accent = Color(0xFFA1C9FF);
  static const Color _accentSoft = Color(0x1AA1C9FF);
  static const Color _borderSubtle = Color(0x14FFFFFF);
  static const Color _card = Color(0xFF1F1F1F);

  static IconData _iconForType(String type) {
    switch (type) {
      case 'COMMENT_REPLY':
        return Icons.chat_bubble_outline_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = formatDate(entry.createdAt);
    final unread = !entry.read;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unread ? const Color(0x40A1C9FF) : _borderSubtle,
          width: unread ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: unread ? _accentSoft : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: unread ? const Color(0x33A1C9FF) : _borderSubtle,
              ),
            ),
            child: Icon(
              _iconForType(entry.type),
              color: unread ? _accent : const Color(0xFF9CA3AF),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        style: GoogleFonts.notoSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6, top: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0095FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (entry.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    entry.body,
                    style: GoogleFonts.notoSans(
                      color: const Color(0xFFBFC7D5),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        dateStr,
                        style: GoogleFonts.notoSans(
                          color: const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
