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
                    const _FirstOnboardingPage(),
                    const _SecondOnboardingPage(),
                    const _ThirdOnboardingPage(),
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
                          letterSpacing: _page == 1 ? 0.7 : 0,
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
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        shadowColor: const Color(0x33A1C9FF),
                        elevation: 0,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0095FF),
                              Color(0xFF004880),
                            ],
                          ),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          child: Text(
                            _page < 2 ? 'Devam' : 'UYGULAMAYA GEÇ',
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
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

class _FirstOnboardingPage extends StatelessWidget {
  const _FirstOnboardingPage();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: -80,
          top: 140,
          child: Container(
            width: 256,
            height: 256,
            decoration: BoxDecoration(
              color: const Color(0x0D0095FF),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0095FF),
                  blurRadius: 48,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14A1C9FF),
                        blurRadius: 40,
                        offset: Offset(0, 10),
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bolt, color: Color(0xFFA1C9FF), size: 40),
                ),
                const SizedBox(height: 48),
                Text(
                  'Motive ol,\nkayda geç.',
                  style: GoogleFonts.newsreader(
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    letterSpacing: -1.2,
                    color: const Color(0xFFE2E2E2),
                  ),
                ),
                const SizedBox(height: 24),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.notoSans(
                      fontSize: 18,
                      height: 1.625,
                      color: const Color(0xFFBFC7D5),
                    ),
                    children: [
                      const TextSpan(text: 'DAHA sadece alıntı göstermez.\n'),
                      const TextSpan(text: 'Her gün bir içerikle tetiklenirsin;\n'),
                      const TextSpan(text: 'asıl güç, o gün için yazdığın somut\n'),
                      const TextSpan(text: 'eylemdir. '),
                      TextSpan(
                        text: '"Bugün bu sözle ne yaptın?"\n',
                        style: GoogleFonts.newsreader(
                          fontSize: 36 / 2,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          height: 1.625,
                          color: const Color(0xFFA1C9FF),
                        ),
                      ),
                      const TextSpan(text: 'sorusu alışkanlığını ölçülebilir\n'),
                      const TextSpan(text: 'yapar.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SecondOnboardingPage extends StatelessWidget {
  const _SecondOnboardingPage();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: -80,
          top: 140,
          child: Container(
            width: 256,
            height: 256,
            decoration: BoxDecoration(
              color: const Color(0x0D0095FF),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0095FF),
                  blurRadius: 48,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14A1C9FF),
                        blurRadius: 40,
                        offset: Offset(0, 10),
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.link_rounded, color: Color(0xFFA1C9FF), size: 40),
                ),
                const SizedBox(height: 48),
                Text(
                  'Zincir ve\nrozetler',
                  style: GoogleFonts.newsreader(
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    letterSpacing: -1.2,
                    color: const Color(0xFFE2E2E2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Eylemlerini biriktirerek serini\n'
                  '(streak) ve zincir görünümlerini\n'
                  'güçlendirirsin. Rozetler ve sosyal\n'
                  'puanlar ilerlemeni görünür kılar —\n'
                  'motivasyonu davranışa bağlar.',
                  style: GoogleFonts.notoSans(
                    fontSize: 18,
                    height: 1.625,
                    color: const Color(0xFFBFC7D5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThirdOnboardingPage extends StatelessWidget {
  const _ThirdOnboardingPage();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: -80,
          top: 140,
          child: Container(
            width: 256,
            height: 256,
            decoration: BoxDecoration(
              color: const Color(0x0D0095FF),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0095FF),
                  blurRadius: 48,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14A1C9FF),
                        blurRadius: 40,
                        offset: Offset(0, 10),
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.forum_outlined, color: Color(0xFFA1C9FF), size: 40),
                ),
                const SizedBox(height: 48),
                Text(
                  'Topluluk,\ngüvende',
                  style: GoogleFonts.newsreader(
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    letterSpacing: -1.2,
                    color: const Color(0xFFE2E2E2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Yorumlarla diğer kullanıcılarla\n'
                  'tartışabilir, yanıt verebilirsin.\n'
                  'Uygunsuz içerik için yorumları\n'
                  'raporlayabilir veya kullanıcıyı\n'
                  'engelleyebilirsin. Hesap isteğe\n'
                  'bağlıdır; giriş yaparak verilerini\n'
                  'bulutta birleştirebilirsin.',
                  style: GoogleFonts.notoSans(
                    fontSize: 18,
                    height: 1.625,
                    color: const Color(0xFFBFC7D5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

