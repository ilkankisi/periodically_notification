import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/onboarding_service.dart';

/// İlk kurulum: motivasyon + eylem + topluluk mesajı.
class ValuePropositionOnboarding extends StatefulWidget {
  const ValuePropositionOnboarding({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<ValuePropositionOnboarding> createState() => _ValuePropositionOnboardingState();
}

class _ValuePropositionOnboardingState extends State<ValuePropositionOnboarding> {
  final PageController _controller = PageController();
  int _page = 0;

  Future<void> _complete() async {
    await OnboardingService.markCompleted();
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _complete,
                    child: Text(
                      'Geç',
                      style: GoogleFonts.notoSans(
                        color: const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _OnboardingPage(
                      icon: Icons.bolt,
                      title: 'Motive ol, kayda geç',
                      body:
                          'DAHA sadece alıntı göstermez. Her gün bir içerikle tetiklenirsin; asıl güç, o gün '
                          'için yazdığın somut eylemdir. "Bugün bu sözle ne yaptın?" sorusu alışkanlığını ölçülebilir yapar.',
                    ),
                    _OnboardingPage(
                      icon: Icons.link,
                      title: 'Zincir ve rozetler',
                      body:
                          'Eylemlerini biriktirerek serini (streak) ve zincir görünümlerini güçlendirirsin. '
                          'Rozetler ve sosyal puanlar ilerlemeni görünür kılar — motivasyonu davranışa bağlar.',
                    ),
                    _OnboardingPage(
                      icon: Icons.forum_outlined,
                      title: 'Topluluk, güvende',
                      body:
                          'Yorumlarla diğer kullanıcılarla tartışabilir, yanıt verebilirsin. Uygunsuz içerik için '
                          'yorumları raporlayabilir veya kullanıcıyı engelleyebilirsin. Hesap isteğe bağlıdır; '
                          'giriş yaparak verilerini bulutta birleştirebilirsin.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final on = i == _page;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: on ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: on ? const Color(0xFF2094F3) : const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () {
                        _controller.previousPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: Text(
                        'Geri',
                        style: GoogleFonts.notoSans(
                          color: const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 64),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (_page < 2) {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          );
                        } else {
                          _complete();
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2094F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _page < 2 ? 'Devam' : 'Uygulamaya geç',
                        style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF2094F3).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 36, color: const Color(0xFF2094F3)),
        ),
        const SizedBox(height: 28),
        Text(
          title,
          style: GoogleFonts.newsreader(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          body,
          style: GoogleFonts.notoSans(
            fontSize: 16,
            height: 1.5,
            color: const Color(0xFFB0B0B0),
          ),
        ),
      ],
    );
  }
}
