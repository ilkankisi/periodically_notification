import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../models/gamification_badge.dart';

/// İlk yorum sonrası sosyal puan / rozet kazanımında tek adımlı açıklama.
class CommentPointsCoach {
  CommentPointsCoach._();

  static const Object _idAnchor = 'comment_points_anchor';

  static void show({
    required BuildContext context,
    required GlobalKey anchorKey,
    required int pointsEarned,
    required List<String> newBadgeIds,
    required VoidCallback onDone,
  }) {
    final ctx = context;
    const accent = Color(0xFF0095FF);
    const cardBg = Color(0xFF1C1C1E);
    const border = Color(0xFF2C2C2E);
    const muted = Color(0xFF9CA3AF);

    final badgeLine = newBadgeIds.isEmpty
        ? ''
        : newBadgeIds.map((id) => GamificationBadgeDef.byId(id)?.title ?? id).join(', ');

    String body;
    if (pointsEarned > 0 && badgeLine.isNotEmpty) {
      body =
          'Bu yorumla +$pointsEarned sosyal puan ekledin ve yeni rozet açtın: $badgeLine. Toplam puanını ve koleksiyonu Profil → Rozetler ve Puan üzerinden takip edebilirsin.';
    } else if (pointsEarned > 0) {
      body =
          'Yorumların sosyal puanına eklenir. Bu paylaşımla +$pointsEarned puan aldın; özet Profil sekmesindeki Rozetler ve Puan bölümünde.';
    } else if (badgeLine.isNotEmpty) {
      body =
          'Yeni rozet: $badgeLine. Sosyal puan ve rozetlerin tamamı Profil → Rozetler ve Puan’da listelenir.';
    } else {
      body = 'Sosyal puanını Profil sekmesindeki Rozetler ve Puan bölümünden takip edebilirsin.';
    }

    Widget infoCard(TutorialCoachMarkController controller) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x60000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Topluluk puanı',
                        style: GoogleFonts.notoSans(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Puanın güncellendi',
                  style: GoogleFonts.newsreader(
                    color: const Color(0xFFE2E2E2),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: GoogleFonts.notoSans(
                    color: muted,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: controller.next,
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      'Tamam',
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final targets = <TargetFocus>[
      TargetFocus(
        identify: _idAnchor,
        keyTarget: anchorKey,
        shape: ShapeLightFocus.RRect,
        radius: 14,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 8,
        borderSide: const BorderSide(color: Color(0x400095FF), width: 1.5),
        contents: [
          TargetContent(
            align: ContentAlign.top,
            padding: const EdgeInsets.only(bottom: 14),
            builder: (c, controller) => infoCard(controller),
          ),
        ],
      ),
    ];

    void complete() {
      onDone();
    }

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.78,
      paddingFocus: 10,
      pulseEnable: false,
      alignSkip: Alignment.topRight,
      textSkip: 'Geç',
      textStyleSkip: GoogleFonts.notoSans(
        color: const Color(0xFF9CA3AF),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      showSkipInLastTarget: true,
      onSkip: () {
        complete();
        return true;
      },
      onFinish: complete,
      beforeFocus: (target) async {
        if (target.identify == _idAnchor) {
          final kc = anchorKey.currentContext;
          if (kc != null) {
            await Scrollable.ensureVisible(
              kc,
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              alignment: 0.85,
            );
          }
        }
      },
    ).show(context: ctx);
  }
}
