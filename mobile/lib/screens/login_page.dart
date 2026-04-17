import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/auth_service.dart';
import '../services/gamification_service.dart';
import '../services/notification_badge_controller.dart';
import '../services/notification_store_service.dart';
import '../widgets/login_full_tour_coach.dart';

/// Giriş sayfası — Apple ve Google ile giriş ([Figma](https://www.figma.com/design/v3UoAoZoaW92TprwR8CSk1/Periodicly-Notification?node-id=60-1024)).
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.onSuccess,
    this.onboardingFullTour = false,
  });

  /// Giriş başarılı olduğunda çağrılır (örn. Navigator.pop)
  final VoidCallback? onSuccess;

  /// Genişletilmiş onboarding turu: coach metni ve platform spotlight’ları.
  final bool onboardingFullTour;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;
  String? _errorMessage;

  final GlobalKey _googleSignInKey = GlobalKey();
  final GlobalKey _appleSignInKey = GlobalKey();
  bool _fullTourCoachScheduled = false;

  static const Color _bg = Color(0xFF131313);
  static const Color _accent = Color(0xFFA1C9FF);
  static const Color _muted = Color(0xFFBFC7D5);
  static const Color _borderSubtle = Color(0x14FFFFFF);
  static const Color _cardFill = Color(0xFF1F1F1F);

  Future<void> _signInWithApple() async {
    if (!await SignInWithApple.isAvailable()) {
      _showError('Apple ile giriş bu cihazda desteklenmiyor.');
      return;
    }
    await _signIn(() => AuthService.signInWithApple());
  }

  Future<void> _signInWithGoogle() async {
    await _signIn(() => AuthService.signInWithGoogle());
  }

  Future<void> _signIn(Future<bool> Function() signInFn) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final ok = await signInFn();
      if (!mounted) return;
      if (ok) {
        await GamificationService.syncFromBackend();
        await NotificationStoreService.syncFromBackend();
        await NotificationBadgeController.instance.refresh();
        if (!mounted) return;
        widget.onSuccess?.call();
        if (mounted) Navigator.of(context).pop(true);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      _showError(_formatAuthError(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String msg) {
    setState(() => _errorMessage = msg);
  }

  @override
  void initState() {
    super.initState();
    if (widget.onboardingFullTour) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _fullTourCoachScheduled) return;
        _fullTourCoachScheduled = true;
        unawaited(_showFullTourLoginCoach());
      });
    }
  }

  Future<void> _showFullTourLoginCoach() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final appleKey = (Platform.isIOS || Platform.isMacOS) ? _appleSignInKey : null;
    LoginFullTourCoach.show(
      context: context,
      googleKey: _googleSignInKey,
      appleKey: appleKey,
    );
  }

  String _formatAuthError(String err) {
    if (err.contains('user_canceled') || err.contains('canceled')) {
      return 'Giriş iptal edildi.';
    }
    if (err.contains('network')) {
      return 'İnternet bağlantısı gerekli.';
    }
    if (err.contains('sign_in_failed') || err.contains('invalid_credential')) {
      return 'Giriş başarısız. Lütfen tekrar deneyin.';
    }
    if (err.contains('Geçersiz Google token')) {
      return 'Google oturumu sunucuda doğrulanamadı. Uygulama güncel mi ve API aynı Google projesini mi kullanıyor kontrol edin.';
    }
    if (err.contains('Google OAuth yapılandırılmamış')) {
      return 'Sunucuda Google girişi yapılandırılmamış.';
    }
    if (err.contains('Kullanıcı oluşturulamadı')) {
      return 'Hesap oluşturulamadı. Lütfen daha sonra tekrar deneyin.';
    }
    final stripped = err.replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (stripped != err && stripped.length < 220) {
      return stripped;
    }
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }

  @override
  Widget build(BuildContext context) {
    final isAppleAvailable = Platform.isIOS || Platform.isMacOS;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _loading ? null : () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _accent, size: 20),
                  style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0x1AA1C9FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: _borderSubtle),
                        ),
                        child: const Icon(Icons.lock_outline_rounded, color: _accent, size: 34),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Giriş yap',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.newsreader(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.onboardingFullTour
                          ? 'Günlük aksiyonunu paylaşmak için giriş yap. Aşağıdaki seçeneklerden biriyle devam et.'
                          : 'Yorum yapmak ve paylaşmak için hesabınıza giriş yapın.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        height: 1.45,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 36),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0x1AFF6B6B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x33FF6B6B)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.notoSans(
                            color: const Color(0xFFFFB4B4),
                            fontSize: 14,
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (isAppleAvailable)
                      KeyedSubtree(
                        key: _appleSignInKey,
                        child: _buildAppleButton(
                          onPressed: _loading ? null : _signInWithApple,
                        ),
                      ),
                    if (isAppleAvailable) const SizedBox(height: 12),
                    KeyedSubtree(
                      key: _googleSignInKey,
                      child: _buildGoogleButton(
                        onPressed: _loading ? null : _signInWithGoogle,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Hesabınız yoksa ilk girişte otomatik oluşturulur.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        height: 1.4,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    if (_loading) ...[
                      const SizedBox(height: 28),
                      const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0095FF),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppleButton({VoidCallback? onPressed}) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: const Color(0xFF3F3F3F),
          disabledForegroundColor: const Color(0xFF9CA3AF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.apple,
              size: 26,
              color: onPressed == null ? const Color(0xFF9CA3AF) : Colors.black,
            ),
            const SizedBox(width: 10),
            Text(
              'Apple ile devam et',
              style: GoogleFonts.notoSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: onPressed == null ? const Color(0xFF9CA3AF) : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton({VoidCallback? onPressed}) {
    return SizedBox(
      height: 54,
      child: Material(
        color: _cardFill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.g_mobiledata_rounded,
                  size: 32,
                  color: onPressed == null ? const Color(0xFF6B7280) : const Color(0xFF4285F4),
                ),
                const SizedBox(width: 4),
                Text(
                  'Google ile devam et',
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: onPressed == null ? const Color(0xFF6B7280) : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
