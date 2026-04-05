import 'package:flutter/material.dart';

import '../models/action_entry.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../widgets/app_top_bar.dart';
import 'login_page.dart';

class ActionsPage extends StatefulWidget {
  const ActionsPage({super.key});

  @override
  State<ActionsPage> createState() => _ActionsPageState();
}

class _ActionsPageState extends State<ActionsPage> {
  late Future<List<ActionEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ActionEntry>> _load() async {
    if (!AuthService.isLoggedIn) return [];
    final ok = await BackendService.ensureToken();
    if (!ok) return [];
    return BackendService.client.getMyActions();
  }

  Future<void> _reload() async {
    final data = await _load();
    if (!mounted) return;
    setState(() {
      _future = Future.value(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = AuthService.isLoggedIn;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: const AppTopBar(
        title: 'Aksiyonlar',
        showBackButton: true,
      ),
      body: loggedIn
          ? FutureBuilder<List<ActionEntry>>(
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
                            'Henüz yanıt verdiğiniz bir aksiyon yok.',
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
                      final a = items[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        title: Text(
                          a.quoteTitle.isNotEmpty ? a.quoteTitle : 'Günün Sözü',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (a.note.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                a.note,
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(a.localDate, a.createdAt),
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
            )
          : _buildLoginRequired(context),
    );
  }

  Widget _buildLoginRequired(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Aksiyon zincirinizi görebilmek için giriş yapmanız gerekiyor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFE5E7EB),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                  if (ok == true && mounted) {
                    _reload();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2094F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Giriş Yap',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String localDate, String createdAt) {
    if (localDate.isNotEmpty) return localDate;
    if (createdAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
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
      return '${dt.day} $month ${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

