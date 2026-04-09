import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/action_entry.dart';
import '../models/motivation.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/motivation_service.dart';
import '../widgets/app_top_bar.dart';
import 'content_detail_page.dart';
import 'all_content_list_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'streak_chain_page.dart';

/// Kullanıcının içeriklere verdiği aksiyonların listesi (boş ve dolu durumlar).
class ActionsPage extends StatefulWidget {
  const ActionsPage({super.key});

  @override
  State<ActionsPage> createState() => _ActionsPageState();
}

class _ActionsPageState extends State<ActionsPage> {
  late Future<List<ActionEntry>> _future;

  static const Color _bg = Color(0xFF131313);

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

  /// Figma 60-1219: geri + başlık + sağda marka.
  PreferredSizeWidget _buildFigmaFilledAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Text(
        'Aksiyonlar',
        style: GoogleFonts.newsreader(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.1,
        ),
      ),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Center(
            child: Text(
              'Nocturnal',
              style: GoogleFonts.newsreader(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFB0B0B0),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFigmaFab(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0095FF).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        backgroundColor: const Color(0xFF0095FF),
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }

  Future<void> _openActionQuote(ActionEntry entry) async {
    final all = await MotivationService.loadAll();
    Motivation? found;
    for (final m in all) {
      if (m.id == entry.quoteId) {
        found = m;
        break;
      }
    }
    if (!mounted) return;
    if (found != null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ContentDetailPage(item: found!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu içerik cihazda bulunamadı. Keşfet veya ana sayfadan açabilirsiniz.'),
          backgroundColor: Color(0xFF374151),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = AuthService.isLoggedIn;
    if (!loggedIn) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: const AppTopBar(
          title: 'Aksiyonlar',
          showBackButton: true,
        ),
        body: _buildLoginRequired(context),
      );
    }
    return FutureBuilder<List<ActionEntry>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF000000),
            appBar: _buildFigmaFilledAppBar(context),
            body: const Center(
              child: CircularProgressIndicator(color: Color(0xFF0095FF)),
            ),
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFF000000),
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFigmaEmptyHeader(context),
                  Expanded(child: _buildFigmaEmptyMain(context)),
                  _buildFigmaEmptyFooter(context),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: const Color(0xFF000000),
          appBar: _buildFigmaFilledAppBar(context),
          floatingActionButton: _buildFigmaFab(context),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          body: _buildFilledBody(items),
        );
      },
    );
  }

  /// Figma 60-1166: Geçmiş Kayıtlar (sol) + aktif «Aksiyonlar» (sağ).
  Widget _buildFigmaEmptyHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const StreakChainPage()),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      'Geçmiş Kayıtlar',
                      style: GoogleFonts.newsreader(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF7BA3D4),
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Aksiyonlar',
                  style: GoogleFonts.newsreader(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Gradient gövde + boş durum + pull-to-refresh.
  Widget _buildFigmaEmptyMain(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F1C2E),
            Color(0xFF05080E),
            Color(0xFF000000),
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            color: const Color(0xFF0095FF),
            backgroundColor: const Color(0xFF1F1F1F),
            onRefresh: _reload,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      _buildFigmaEmptyIconBlock(),
                      const SizedBox(height: 36),
                      Text(
                        'Henüz bir aksiyonun yok',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.newsreader(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Günün içeriğinden ilk eylemini ekleyerek zincirini başlat.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSans(
                          fontSize: 15,
                          height: 1.55,
                          color: const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildFigmaGoToDailyCta(context),
                      const SizedBox(height: 20),
                      _buildFigmaNewContentPill(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFigmaEmptyIconBlock() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF3D3D42)),
          ),
          child: const Icon(
            Icons.edit_note_rounded,
            color: Color(0xFFA1C9FF),
            size: 48,
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1E),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF404048)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.list_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFigmaGoToDailyCta(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF0095FF),
                Color(0xFF0066CC),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'GÜNÜN İÇERİĞİNE GİT',
                  style: GoogleFonts.notoSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFigmaNewContentPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF0095FF),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'YENİ İÇERİK YAYINDA',
            style: GoogleFonts.notoSans(
              color: const Color(0xFF6B7280),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFigmaEmptyFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        border: Border(
          top: BorderSide(color: Color(0x14FFFFFF), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The Curator',
            style: GoogleFonts.newsreader(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFA1C9FF),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Hergün seçilen tek bir içerik, gerçekleştirilen tek bir eylem. Hayatın ritmini beraber yakalıyoruz.',
            style: GoogleFonts.notoSans(
              fontSize: 13,
              height: 1.45,
              color: const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0095FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const AllContentListPage()),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'ARŞİV',
                  style: GoogleFonts.notoSans(
                    color: const Color(0xFF9CA3AF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfilePage(showBottomBar: false),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'AYARLAR',
                  style: GoogleFonts.notoSans(
                    color: const Color(0xFF9CA3AF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Figma 60-1219: üst editorial blok.
  Widget _buildCuratorHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KÜRATÖR GÜNLÜĞÜ',
            style: GoogleFonts.notoSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.15,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Gelişimin Sessiz Ayak Sesleri.',
            style: GoogleFonts.newsreader(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.12,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF0095FF),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilledBody(List<ActionEntry> items) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: const Color(0xFF0095FF),
      edgeOffset: 8,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          _buildCuratorHero(),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _ActionCard(
              entry: items[i],
              index: i,
              dateUpper: _formatDateDayMonthUpper(items[i].localDate, items[i].createdAt),
              onTap: () => _openActionQuote(items[i]),
            ),
          ],
        ],
      ),
    );
  }

  /// Örn. «18 MART»
  String _formatDateDayMonthUpper(String localDate, String createdAt) {
    DateTime? dt;
    if (localDate.isNotEmpty) {
      dt = DateTime.tryParse(localDate);
      dt ??= _tryParseLocalDate(localDate);
    }
    if (dt == null && createdAt.isNotEmpty) {
      dt = DateTime.tryParse(createdAt)?.toLocal();
    }
    if (dt == null) return '';
    const months = [
      'OCAK',
      'ŞUBAT',
      'MART',
      'NİSAN',
      'MAYIS',
      'HAZİRAN',
      'TEMMUZ',
      'AĞUSTOS',
      'EYLÜL',
      'EKİM',
      'KASIM',
      'ARALIK',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  DateTime? _tryParseLocalDate(String s) {
    final parts = s.split(RegExp(r'[-/]'));
    if (parts.length >= 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return null;
  }

  Widget _buildLoginRequired(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Aksiyon zincirinizi görebilmek için giriş yapmanız gerekiyor.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: const Color(0xFFE5E7EB),
                fontSize: 16,
                height: 1.4,
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
                  backgroundColor: const Color(0xFF0095FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Giriş Yap',
                  style: GoogleFonts.notoSans(
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

}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.entry,
    required this.index,
    required this.dateUpper,
    required this.onTap,
  });

  final ActionEntry entry;
  final int index;
  final String dateUpper;
  final VoidCallback onTap;

  static const List<IconData> _leftIcons = [
    Icons.calendar_month_rounded,
    Icons.hourglass_top_rounded,
    Icons.fitness_center_rounded,
  ];

  static const List<IconData> _statusIcons = [
    Icons.auto_awesome_rounded,
    Icons.check_circle_outline_rounded,
    Icons.bolt_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final quote = entry.quoteTitle.isNotEmpty ? entry.quoteTitle : 'Günün sözü';
    final leftIcon = _leftIcons[index % _leftIcons.length];
    final statusIcon = _statusIcons[index % _statusIcons.length];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2C2C30)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF252528),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0095FF).withValues(alpha: 0.25)),
                      ),
                      child: Icon(
                        leftIcon,
                        color: const Color(0xFF0095FF),
                        size: 26,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      statusIcon,
                      color: const Color(0xFF6B7280),
                      size: 22,
                    ),
                  ],
                ),
                if (dateUpper.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    dateUpper,
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  quote,
                  style: GoogleFonts.newsreader(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
                if (entry.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A2A2E)),
                    ),
                    child: Text(
                      'Not: ${entry.note.trim()}',
                      style: GoogleFonts.notoSans(
                        color: const Color(0xFFBFC7D5),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
