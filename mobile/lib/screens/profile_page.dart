import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../services/auth_service.dart';
import '../services/gamification_service.dart';
import '../services/notification_badge_controller.dart';
import '../services/onboarding_service.dart';
import '../services/profile_service.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import 'account_info_page.dart';
import 'badges_page.dart';
import 'login_page.dart';
import 'notifications_page.dart';

/// Profil sayfası: giriş/çıkış, avatar, kullanıcı adı, Ayarlar (Hesap Bilgileri, Tema).
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.showBottomBar = true,
    this.onTabTap,
    this.isMainShellActiveTab = false,
  });

  final bool showBottomBar;
  final ValueChanged<int>? onTabTap;

  /// [main.dart] IndexedStack’te bu sekme seçildiğinde true; tur spotlight’ı yeniden denemek için.
  final bool isMainShellActiveTab;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // bool _darkModeOn = true; // Tema için - şimdilik yorumda
  String? _displayName;
  String? _profileImagePath;
  String? _authPhotoUrl;
  bool _isLoggedIn = false;
  GamificationSnapshot? _gamification;
  final GlobalKey _profileHeroTourKey = GlobalKey();
  bool _profileTourScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _updateAuthState();
    AuthService.authStateChanges.listen((_) => _updateAuthState());
    GamificationService.onStateChanged.addListener(_onGamificationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowProfileTourSpotlight());
    });
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isMainShellActiveTab && widget.isMainShellActiveTab) {
      unawaited(_maybeShowProfileTourSpotlight());
    }
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
      _gamification = AuthService.isLoggedIn ? gam : null;
    });
    unawaited(_maybeShowProfileTourSpotlight());
  }

  Future<void> _maybeShowProfileTourSpotlight() async {
    if (!mounted || _profileTourScheduled || !_isLoggedIn) return;
    final ftp = await OnboardingService.getGlobalTourStep();
    if (ftp != OnboardingService.ftProfileSpotlight) return;
    _profileTourScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted) return;
      TutorialCoachMark(
        targets: [
          TargetFocus(
            identify: 'profile_hero_spotlight',
            keyTarget: _profileHeroTourKey,
            shape: ShapeLightFocus.RRect,
            radius: 20,
            enableTargetTab: false,
            enableOverlayTab: false,
            paddingFocus: 8,
            borderSide: const BorderSide(color: Color(0x400095FF), width: 1.5),
            contents: [
              TargetContent(
                align: ContentAlign.bottom,
                padding: const EdgeInsets.only(top: 14),
                builder: (c, controller) => Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2C2C2E)),
                  ),
                  child: Text(
                    'Adım 22/22\n\nProfil sayfasına geldin. Tur tamamlandı.',
                    style: GoogleFonts.notoSans(
                      color: const Color(0xFFE2E2E2),
                      fontSize: 14,
                      height: 1.4,
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
        textSkip: 'Geç',
        onSkip: () {
          unawaited(OnboardingService.setGlobalTourStep(OnboardingService.ftFullTourDone));
          return true;
        },
        onFinish: () {
          unawaited(OnboardingService.setGlobalTourStep(OnboardingService.ftFullTourDone));
        },
      ).show(context: context);
    });
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
    if (!_isLoggedIn) {
      return Scaffold(
        backgroundColor: const Color(0xFF131313),
        body: SafeArea(
          child: Column(
            children: [
              _buildGuestProfileTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _buildGuestProfileContent(),
                ),
              ),
              if (widget.showBottomBar) BottomNavBar(activeIndex: 3, onTabTap: widget.onTabTap),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      body: SafeArea(
        child: Column(
          children: [
            _buildLoggedInTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _buildLoggedInHero(),
                    const SizedBox(height: 40),
                    _buildGamificationBento(
                      _gamification ??
                          const GamificationSnapshot(
                            socialPoints: 0,
                            commentCount: 0,
                            maxStreakRecorded: 0,
                            unlocked: {},
                          ),
                    ),
                    const SizedBox(height: 32),
                    _buildLoggedInGeneralSettings(),
                    const SizedBox(height: 32),
                    _buildLoggedInAppSettings(),
                    const SizedBox(height: 33),
                    _buildLoggedInDangerActions(),
                  ],
                ),
              ),
            ),
            if (widget.showBottomBar) BottomNavBar(activeIndex: 3, onTabTap: widget.onTabTap),
          ],
        ),
      ),
    );
  }

  String _loggedInSubtitle() {
    final e = AuthService.email;
    if (e != null && e.isNotEmpty) return 'Üye • $e';
    return 'Üye';
  }

  Widget _buildLoggedInTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Center(
        child: Text(
          'Profil',
          textAlign: TextAlign.center,
          style: AppTopBar.centeredTitleStyle(),
        ),
      ),
    );
  }

  Widget _buildLoggedInHero() {
    final showAuthPhoto = _authPhotoUrl != null && _authPhotoUrl!.isNotEmpty;
    final showLocalPhoto = !showAuthPhoto && _profileImagePath != null && File(_profileImagePath!).existsSync();
    final name = _displayName?.trim().isNotEmpty == true ? _displayName! : 'Kullanıcı';

    return KeyedSubtree(
      key: _profileHeroTourKey,
      child: SizedBox(
        height: 204,
        child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x330095FF),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _pickProfileImage,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1F1F1F), width: 4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 50,
                          offset: Offset(0, 25),
                          spreadRadius: -12,
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
                              placeholder: (_, __) => Container(
                                color: const Color(0xFF0E0E0E),
                                child: const Center(child: CircularProgressIndicator(color: Color(0xFF0095FF), strokeWidth: 2)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFF0E0E0E),
                                child: const Icon(Icons.person, color: Color(0xFF6B7280), size: 64),
                              ),
                            )
                          : showLocalPhoto
                              ? Image.file(File(_profileImagePath!), fit: BoxFit.cover, width: 128, height: 128)
                              : Container(
                                  color: const Color(0xFF0E0E0E),
                                  child: const Icon(Icons.person, color: Color(0xFF6B7280), size: 64),
                                ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: GestureDetector(
                    onTap: _pickProfileImage,
                    child: Container(
                      width: 31,
                      height: 31,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0095FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_outlined, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 144,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.newsreader(
                    color: const Color(0xFFE2E2E2),
                    fontSize: 30,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _loggedInSubtitle(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    color: const Color(0xFFBFC7D5),
                    fontSize: 14,
                    letterSpacing: 0.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  String _formatPoints(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return n < 0 ? '-$buf' : buf.toString();
  }

  Widget _buildGamificationBento(GamificationSnapshot g) {
    final streak = g.maxStreakRecorded;
    final points = _formatPoints(g.socialPoints);
    final badgeCount = g.unlocked.length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -48,
          top: -48,
          child: IgnorePointer(
            child: Container(
              width: 192,
              height: 192,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x0D0095FF),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PERFORMANS ÖZETİ',
                    style: GoogleFonts.notoSans(
                      color: const Color(0xFFBFC7D5),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  Icon(Icons.auto_awesome_outlined, color: const Color(0xFFBFC7D5).withValues(alpha: 0.8), size: 22),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _bentoStatCell(
                      icon: Icons.local_fire_department_outlined,
                      label: 'SERİ',
                      value: streak > 0 ? '$streak Gün' : '—',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _bentoStatCell(
                      icon: Icons.star_border_rounded,
                      label: 'PUAN',
                      value: points,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'KAZANILAN ROZETLER',
                    style: GoogleFonts.notoSans(
                      color: const Color(0xFFBFC7D5),
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const BadgesPage()),
                      );
                      if (mounted) await _refreshGamification();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Tümünü Gör',
                      style: GoogleFonts.notoSans(
                        color: const Color(0xFFA1C9FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _badgePreviewSlot(icon: Icons.emoji_events_outlined, filled: badgeCount >= 1),
                  const SizedBox(width: 16),
                  _badgePreviewSlot(icon: Icons.workspace_premium_outlined, filled: badgeCount >= 2),
                  const SizedBox(width: 16),
                  _badgePreviewSlot(icon: Icons.verified_outlined, filled: badgeCount >= 3),
                  const SizedBox(width: 16),
                  _badgePreviewLocked(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bentoStatCell({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFFBFC7D5)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.notoSans(
                  color: const Color(0xFFBFC7D5),
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.newsreader(
              color: const Color(0xFFE2E2E2),
              fontSize: 24,
              height: 1.33,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgePreviewSlot({required IconData icon, required bool filled}) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: filled ? const Color(0xFF353535) : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: filled ? const Color(0xFFA1C9FF) : const Color(0xFF6B7280),
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _badgePreviewLocked() {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF404753), width: 2, style: BorderStyle.solid),
          ),
          child: const Center(
            child: Icon(Icons.lock_outline, color: Color(0xFF6B7280), size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedInGeneralSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            'GENEL AYARLAR',
            style: GoogleFonts.notoSans(
              color: const Color(0xFFBFC7D5),
              fontSize: 11,
              letterSpacing: 2.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _loggedInSettingsTile(
          icon: Icons.person_outline_rounded,
          label: 'Hesap Bilgileri',
          onTap: () async {
            final saved = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (context) => const AccountInfoPage()),
            );
            if (saved == true) _loadProfile();
          },
        ),
        const SizedBox(height: 4),
        _loggedInSettingsTile(
          icon: Icons.lock_outline_rounded,
          label: 'Gizlilik',
          onTap: () => _showComingSoon('Gizlilik'),
        ),
        const SizedBox(height: 4),
        _loggedInSettingsTile(
          icon: Icons.notifications_none_rounded,
          label: 'Bildirim Tercihleri',
          onTap: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
            );
            await NotificationBadgeController.instance.refresh();
          },
        ),
      ],
    );
  }

  Widget _buildLoggedInAppSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            'UYGULAMA',
            style: GoogleFonts.notoSans(
              color: const Color(0xFFBFC7D5),
              fontSize: 11,
              letterSpacing: 2.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _loggedInSettingsTile(
          icon: Icons.palette_outlined,
          label: 'Tema Seçimi',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x1AA1C9FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'KOYU',
              style: GoogleFonts.notoSans(
                color: const Color(0xFFA1C9FF),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          onTap: () => _showComingSoon('Tema seçimi'),
        ),
        const SizedBox(height: 4),
        _loggedInSettingsTile(
          icon: Icons.help_outline_rounded,
          label: 'Yardım Merkezi',
          onTap: () => _showComingSoon('Yardım merkezi'),
        ),
      ],
    );
  }

  Widget _loggedInSettingsTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFFA1C9FF)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.notoSans(
                    color: const Color(0xFFE2E2E2),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right, color: Color(0xFFBFC7D5), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedInDangerActions() {
    return Column(
      children: [
        Material(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
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
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, color: Color(0xFFE2E2E2), size: 18),
                  const SizedBox(width: 12),
                  Text(
                    'OTURUMU KAPAT',
                    style: GoogleFonts.notoSans(
                      color: const Color(0xFFE2E2E2),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: const Color(0x1A93000A),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _deleteAccount,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x3393000A)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 17),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.delete_forever_outlined, color: Color(0xFFFFB4AB), size: 18),
                  const SizedBox(width: 12),
                  Text(
                    'HESABI SİL',
                    style: GoogleFonts.notoSans(
                      color: const Color(0xFFFFB4AB),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestProfileTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Center(
        child: Text(
          'Profil',
          textAlign: TextAlign.center,
          style: AppTopBar.centeredTitleStyle(),
        ),
      ),
    );
  }

  Widget _buildGuestProfileContent() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A0095FF),
                    blurRadius: 40,
                    offset: Offset(0, 20),
                    spreadRadius: -15,
                  ),
                ],
              ),
              child: const Icon(Icons.person_2_outlined, color: Color(0xFFA1C9FF), size: 45),
            ),
            Positioned(
              right: -8,
              bottom: -8,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFF0095FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Hoş Geldiniz',
          style: GoogleFonts.newsreader(
            color: const Color(0xFFE2E2E2),
            fontSize: 30,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tüm özelliklere erişmek ve yolculuğunuzu\nkaydetmek için giriş yapın.',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSans(
            color: const Color(0xFFBFC7D5),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        _buildGuestJoinCard(),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'UYGULAMA AYARLARI',
              style: GoogleFonts.notoSans(
                color: const Color(0xFFBFC7D5),
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildGuestSettingsCard(),
        const SizedBox(height: 36),
        Text(
          'Hesabınız var mı? Kaldığınız yerden devam etmek için\ngiriş yapın.',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSans(
            color: const Color(0xFFBFC7D5),
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _openLogin,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 22),
              side: const BorderSide(color: Color(0xFF0095FF), width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text(
              'GİRİŞ YAP / KAYIT OL',
              style: GoogleFonts.notoSans(
                color: const Color(0xFFA1C9FF),
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGuestJoinCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0x991F1F1F),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOPLULUĞA KATIL',
              style: GoogleFonts.notoSans(
                color: const Color(0xFFA1C9FF),
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gelişiminizi takip etmeye bugün\nbaşlayın.',
              style: GoogleFonts.newsreader(
                color: const Color(0xFFE2E2E2),
                fontSize: 36 / 1.8,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Rozetler kazanın, istatistiklerinizi görün ve diğer\nkullanıcılarla etkileşime geçin.',
              style: GoogleFonts.notoSans(
                color: const Color(0xFFBFC7D5),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _openLogin,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Ink(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0095FF), Color(0xFF004880)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'HEMEN KATIL',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSans(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildGuestSettingsRow(
            icon: Icons.language_rounded,
            label: 'Dil',
            trailingText: 'Türkçe',
            onTap: () => _showComingSoon('Dil seçimi'),
          ),
          _buildGuestSettingsRow(
            icon: Icons.description_outlined,
            label: 'Kullanım Koşulları',
            onTap: () => _showComingSoon('Kullanım Koşulları'),
          ),
          _buildGuestSettingsRow(
            icon: Icons.verified_user_outlined,
            label: 'Gizlilik Politikası',
            onTap: () => _showComingSoon('Gizlilik Politikası'),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildGuestSettingsRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? trailingText,
    bool showDivider = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: Color(0x0DFFFFFF)))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF353535),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFFA1C9FF)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.notoSans(
                  color: const Color(0xFFE2E2E2),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: GoogleFonts.notoSans(
                  color: const Color(0xFFBFC7D5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, color: Color(0xFFBFC7D5), size: 18),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title yakında eklenecek.'),
        backgroundColor: const Color(0xFF374151),
      ),
    );
  }

  // /// Tema: görünür ama değiştirilemez (disabled).
  // Widget _buildThemeRow() { ... }
}

