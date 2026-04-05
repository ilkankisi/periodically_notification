import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/auth_service.dart';
import '../services/gamification_service.dart';
import '../services/notification_badge_controller.dart';
import '../services/notification_store_service.dart';

/// Giriş sayfası - Apple ve Google ile giriş
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.onSuccess,
  });

  /// Giriş başarılı olduğunda çağrılır (örn. Navigator.pop)
  final VoidCallback? onSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;
  String? _errorMessage;

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
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }

  @override
  Widget build(BuildContext context) {
    final isAppleAvailable = Platform.isIOS || Platform.isMacOS;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Text(
                'DAHA',
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Yorum yapmak ve paylaşmak için giriş yapın',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSans(
                  fontSize: 16,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              const Spacer(flex: 1),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (isAppleAvailable)
                _buildSignInButton(
                  label: 'Apple ile Giriş Yap',
                  icon: Icons.apple,
                  onPressed: _loading ? null : _signInWithApple,
                ),
              if (isAppleAvailable) const SizedBox(height: 12),
              _buildSignInButton(
                label: 'Google ile Giriş Yap',
                icon: Icons.g_mobiledata_rounded,
                onPressed: _loading ? null : _signInWithGoogle,
              ),
              const SizedBox(height: 16),
              Text(
                'Hesabınız yoksa otomatik oluşturulur',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2094F3),
                    ),
                  ),
                ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton({
    required String label,
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF374151)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.white),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
