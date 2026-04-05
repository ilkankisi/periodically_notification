import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/gamification_service.dart';
import '../services/notification_badge_controller.dart';
import '../services/notification_settings_service.dart';
import '../services/profile_service.dart';
import '../widgets/header_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/app_top_bar.dart';
import 'account_info_page.dart';
import 'badges_page.dart';
import 'login_page.dart';
import 'notifications_page.dart';
import 'zincir_page.dart';

/// Profil sayfası: giriş/çıkış, avatar, kullanıcı adı, Ayarlar (Hesap Bilgileri, Tema).
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.showBottomBar = true,
    this.onTabTap,
  });

  final bool showBottomBar;
  final ValueChanged<int>? onTabTap;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // bool _darkModeOn = true; // Tema için - şimdilik yorumda
  String? _displayName;
  String? _profileImagePath;
  String? _authPhotoUrl;
  bool _isLoggedIn = false;
  int _preferredNotificationHour = 9;
  GamificationSnapshot? _gamification;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _updateAuthState();
    AuthService.authStateChanges.listen((_) => _updateAuthState());
    GamificationService.onStateChanged.addListener(_onGamificationChanged);
  }

  @override
  void dispose() {
    GamificationService.onStateChanged.removeListener(_onGamificationChanged);
    super.dispose();
  }

  void _onGamificationChanged() {
    _refreshGamification();
  }

  Future<void> _refreshGamification() async {
    if (!AuthService.isLoggedIn) {
      if (mounted) setState(() => _gamification = null);
      return;
    }
    final snap = await GamificationService.readSnapshot();
    if (mounted) setState(() => _gamification = snap);
  }

  void _updateAuthState() {
    final loggedIn = AuthService.isLoggedIn;
    if (mounted && _isLoggedIn != loggedIn) {
      setState(() {
        _isLoggedIn = loggedIn;
        if (loggedIn) {
          _displayName = AuthService.displayName ?? AuthService.email;
          _authPhotoUrl = AuthService.photoUrl;
        } else {
          _authPhotoUrl = null;
        }
      });
      if (loggedIn) {
        _loadProfile();
      } else if (mounted) {
        setState(() => _gamification = null);
      }
    }
  }

  Future<void> _loadProfile() async {
    if (AuthService.isLoggedIn) {
      await GamificationService.syncFromBackend();
    }
    final name = await ProfileService.getDisplayName();
    final imagePath = await ProfileService.getProfileImagePath();
    final hour = await NotificationSettingsService.getPreferredHour();
    GamificationSnapshot? gam;
    if (AuthService.isLoggedIn) {
      gam = await GamificationService.readSnapshot();
    }
    if (!mounted) return;
    setState(() {
      if (AuthService.isLoggedIn) {
        _displayName = AuthService.displayName ?? AuthService.email ?? name;
        _authPhotoUrl = AuthService.photoUrl;
      } else {
        _displayName = name;
        _authPhotoUrl = null;
      }
      _profileImagePath = imagePath;
      _preferredNotificationHour = hour;
      _gamification = AuthService.isLoggedIn ? gam : null;
    });
  }

  Future<void> _showNotificationTimePicker() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => _NotificationTimePickerDialog(
        currentHour: _preferredNotificationHour,
      ),
    );
    if (selected != null && mounted) {
      await NotificationSettingsService.setPreferredHour(selected);
      setState(() => _preferredNotificationHour = selected);
    }
  }

  Future<void> _openLogin() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
    if (ok == true && mounted) _loadProfile();
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (mounted) _loadProfile();
  }

  Future<void> _deleteAccount() async {
    final ok1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Hesabı sil', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Hesabınız ve sunucudaki profil verileriniz kalıcı olarak kapatılır. '
          'Yorumlarınız politikalarımız gereği işlenebilir. Bu işlem geri alınamaz.',
          style: TextStyle(color: Color(0xFFB0B0B0), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: Color(0xFF2094F3))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Devam', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok1 != true || !mounted) return;

    final ok2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Emin misiniz?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Hesabınızı silmek üzeresiniz. Onaylıyor musunuz?',
          style: TextStyle(color: Color(0xFFB0B0B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: Color(0xFF2094F3))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Hesabı sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok2 != true || !mounted) return;

    final deleted = await AuthService.deleteAccountOnServer();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted ? 'Hesabınız silindi' : 'Hesap silinemedi. Bağlantınızı kontrol edin.'),
        backgroundColor: const Color(0xFF374151),
      ),
    );
    if (deleted) _loadProfile();
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (xFile == null || !mounted) return;
    await ProfileService.setProfileImageFromFile(xFile.path);
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppTopBar(
        title: 'Profil',
        onNotificationsTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          );
          await NotificationBadgeController.instance.refresh();
        },
        onChainTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ZincirPage()),
          );
        },
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  if (!AuthService.isLoggedIn) ...[
                    const SizedBox(height: 16),
                    _buildLoginButton(),
                  ],
                  if (AuthService.isLoggedIn && _gamification != null) ...[
                    const SizedBox(height: 8),
                    _buildGamificationSummary(_gamification!),
                  ],
                  _buildSectionTitle('AYARLAR'),

                  if (AuthService.isLoggedIn)
                    _buildSettingsRow(
                      icon: Icons.person_outline,
                      label: 'Hesap Bilgileri',
                      onTap: () async {
                        final saved = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (context) => const AccountInfoPage()),
                        );
                        if (saved == true) _loadProfile();
                      },
                    ),
                  // _buildThemeRow(), // TODO: Tema özelliği şimdilik devre dışı
                  if (AuthService.isLoggedIn) ...[
                    const SizedBox(height: 8),
                    _buildDeleteAccountRow(),
                    const SizedBox(height: 8),
                    _buildLogoutRow(),
                  ],
                ],
              ),
            ),
          ),
          if (widget.showBottomBar)
            BottomNavBar(activeIndex: 3, onTabTap: widget.onTabTap),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final showAuthPhoto = AuthService.isLoggedIn && _authPhotoUrl != null && _authPhotoUrl!.isNotEmpty;
    final showLocalPhoto = !showAuthPhoto && _profileImagePath != null && File(_profileImagePath!).existsSync();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: AuthService.isLoggedIn ? _pickProfileImage : null,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2094F3).withValues(alpha: 0.3), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2094F3).withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: showAuthPhoto
                    ? CachedNetworkImage(
                        imageUrl: _authPhotoUrl!,
                        fit: BoxFit.cover,
                        width: 128,
                        height: 128,
                        placeholder: (_, __) => Container(color: const Color(0xFF27272A), child: const Center(child: CircularProgressIndicator(color: Color(0xFF2094F3)))),
                        errorWidget: (_, __, ___) => Container(color: const Color(0xFF27272A), child: const Icon(Icons.person, color: Color(0xFF6B7280), size: 64)),
                      )
                    : showLocalPhoto
                        ? Image.file(File(_profileImagePath!), fit: BoxFit.cover, width: 128, height: 128)
                        : Container(
                            color: const Color(0xFF27272A),
                            child: const Icon(Icons.person, color: Color(0xFF6B7280), size: 64),
                          ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _displayName?.trim().isNotEmpty == true ? _displayName! : (AuthService.isLoggedIn ? 'Kullanıcı' : 'Misafir'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamificationSummary(GamificationSnapshot g) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const BadgesPage()),
            );
            if (mounted) await _refreshGamification();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events_outlined, color: Color(0xFFEAB308), size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Rozetler ve sosyal puan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${g.unlocked.length} rozet',
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 22),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Sosyal puan: ${g.socialPoints}',
                  style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
                ),
                Text(
                  'Kayıtlı en uzun zincir: ${g.maxStreakRecorded} gün',
                  style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: _openLogin,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2094F3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Giriş Yap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountRow() {
    return InkWell(
      onTap: _deleteAccount,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Hesabı sil',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutRow() {
    return InkWell(
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1F1F1F),
            title: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
            content: const Text('Hesabınızdan çıkmak istediğinize emin misiniz?', style: TextStyle(color: Color(0xFFB0B0B0))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal', style: TextStyle(color: Color(0xFF2094F3)))),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Çıkış Yap', style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        );
        if (confirm == true) await _logout();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Çıkış Yap',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Widget? trailing,
    bool iconBgGray = false,
  }) {
    final iconBg = iconBgGray ? const Color(0xFF374151) : const Color(0xFF2094F3).withValues(alpha: 0.15);
    final iconColor = iconBgGray ? const Color(0xFF9CA3AF) : const Color(0xFF2094F3);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 24),
          ],
        ),
      ),
    );
  }

  // /// Tema: görünür ama değiştirilemez (disabled).
  // Widget _buildThemeRow() { ... }
}

/// Bildirim saati seçici dialog (6-22 arası saatler)
class _NotificationTimePickerDialog extends StatefulWidget {
  final int currentHour;

  const _NotificationTimePickerDialog({required this.currentHour});

  @override
  State<_NotificationTimePickerDialog> createState() => _NotificationTimePickerDialogState();
}

class _NotificationTimePickerDialogState extends State<_NotificationTimePickerDialog> {
  late int _selectedHour;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.currentHour;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1F1F1F),
      title: const Text('Bildirim Saati', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 200,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(17, (i) {
              final h = 6 + i;
              final selected = h == _selectedHour;
              return ListTile(
                title: Text(
                  '${h.toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                    color: selected ? const Color(0xFF2094F3) : Colors.white,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                onTap: () => setState(() => _selectedHour = h),
              );
            }),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal', style: TextStyle(color: Color(0xFF9CA3AF))),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedHour),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2094F3)),
          child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

