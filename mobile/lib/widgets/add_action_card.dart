import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/login_page.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/gamification_service.dart';
import '../services/local_notification_service.dart';

/// "Bugün bu sözle ne yaptın?" kartı + opt-in sync.
class AddActionCard extends StatefulWidget {
  final String quoteId;
  final String quoteTitle;
  /// Aksiyon sunucuya kaydedildikten sonra (tebrik diyaloğu kapatıldıktan sonra).
  final VoidCallback? onActionSaved;
  /// null: varsayılan başlık; anasayfa Figma için örn. «BUGÜN BU SÖZLE NE YAPTIN?»
  final String? titleText;
  /// null: varsayılan ipucu metni.
  final String? hintText;
  /// false: açıklama paragrafını gizler (anasayfa kompakt kart).
  final bool showDescription;

  const AddActionCard({
    super.key,
    required this.quoteId,
    required this.quoteTitle,
    this.onActionSaved,
    this.titleText,
    this.hintText,
    this.showDescription = true,
  });

  @override
  State<AddActionCard> createState() => _AddActionCardState();
}

class _AddActionCardState extends State<AddActionCard> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onAddAction() async {
    final note = _controller.text.trim();
    if (note.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();

    if (!AuthService.isLoggedIn) {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPage(
            onSuccess: () => Navigator.pop(context, true),
          ),
        ),
      );
      if (ok == true && mounted) _showOptInAndSend(note);
      return;
    }

    await _showOptInAndSend(note);
  }

  Future<void> _showOptInAndSend(String note) async {
    final sync = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text(
          'Senkronizasyon',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Aksiyonlarınız sunucuya senkron edilsin mi?',
          style: TextStyle(color: Color(0xFFB0B0B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hayır', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0095FF)),
            child: const Text('Evet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (sync != true || !mounted) return;

    setState(() => _sending = true);
    try {
      final ok = await BackendService.ensureToken();
      if (!ok || !mounted) {
        _showSnack('Giriş gerekli. Lütfen tekrar giriş yapın.');
        return;
      }

      final localDate = _formatLocalDate(DateTime.now());
      final idempotencyKey = '${widget.quoteId}_${localDate}_${DateTime.now().millisecondsSinceEpoch}';

      final result = await BackendService.client.postAction(
        quoteId: widget.quoteId,
        localDate: localDate,
        note: note,
        idempotencyKey: idempotencyKey,
      );

      if (!mounted) return;
      if (result != null) {
        _controller.clear();
        await LocalNotificationService.scheduleTomorrowReflectionReminder(
          widget.quoteTitle,
        );
        await GamificationService.syncFromBackend();
        await _showCongratulationsDialog();
        widget.onActionSaved?.call();
      } else {
        _showSnack('Kaydedilemedi. Tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatLocalDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _showCongratulationsDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: Text(
          'Harika!',
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        content: Text(
          'Tebrikler! Hayatınıza bugün bir şey katabildik; ne mutlu bize.',
          style: GoogleFonts.notoSans(
            color: const Color(0xFFB0B0B0),
            fontSize: 16,
            height: 1.45,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0095FF)),
            child: const Text('Tamam', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF374151),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.titleText ?? 'Bugün bu sözle ne yaptın?',
            style: GoogleFonts.notoSans(
              fontSize: widget.titleText != null ? 13 : 17,
              fontWeight: FontWeight.w800,
              letterSpacing: widget.titleText != null ? 0.6 : 0,
              height: 1.25,
              color: const Color(0xFFE2E2E2),
            ),
          ),
          if (widget.showDescription) ...[
            const SizedBox(height: 8),
            Text(
              'Pratiğe dökülmeyen bilgi sadece yüktür. Aksiyonunu kaydet.',
              style: GoogleFonts.notoSans(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ],
          SizedBox(height: widget.showDescription ? 16 : 14),
          TextField(
            controller: _controller,
            style: GoogleFonts.notoSans(fontSize: 15, color: Colors.white, height: 1.4),
            decoration: InputDecoration(
              hintText: widget.hintText ?? 'Aksiyonunu buraya yaz...',
              hintStyle: GoogleFonts.notoSans(fontSize: 15, color: const Color(0xFF6B7280)),
              filled: true,
              fillColor: const Color(0xFF141414),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0095FF), width: 1.5),
              ),
            ),
            maxLines: 4,
            minLines: 3,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _sending ? null : _onAddAction,
                child: Ink(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFF0095FF),
                        Color(0xFF0070E0),
                      ],
                    ),
                  ),
                  child: Center(
                    child: _sending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Aksiyon Ekle',
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
