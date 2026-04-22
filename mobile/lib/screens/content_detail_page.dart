import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/comment.dart';
import '../models/motivation.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../models/gamification_badge.dart';
import '../services/comment_service.dart';
import '../services/daily_action_onboarding_helper.dart';
import '../services/onboarding_service.dart';
import '../services/moderation_service.dart';
import '../services/saved_items_service.dart';
import '../services/user_motivation_service.dart';
import '../widgets/add_action_card.dart';
import '../widgets/comment_points_coach.dart';
import '../widgets/first_comment_composer_coach.dart';
import '../widgets/motivation_cached_image.dart';
import 'login_page.dart';

/// İçerik detay sayfası - Görsel tasarıma uygun makale görünümü
class ContentDetailPage extends StatefulWidget {
  final Motivation item;

  /// Onboarding v1: ana sayfadaki günün içeriği kartından açıldıysa yorum alanı coach’u.
  final bool onboardingV1ComposerCoach;

  /// Full tur v2: Kaydedilenler’den açıldıysa yorum coach’u (faz [OnboardingService.ftSavedComment]).
  final bool onboardingFullTourSavedFlow;

  const ContentDetailPage({
    super.key,
    required this.item,
    this.onboardingV1ComposerCoach = false,
    this.onboardingFullTourSavedFlow = false,
  });

  @override
  State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  bool _saved = false;
  Map<String, dynamic>? _myAction;
  List<Comment> _comments = [];
  StreamSubscription<List<Comment>>? _commentsSub;
  final TextEditingController _commentController = TextEditingController();
  bool _sendingComment = false;
  Comment? _replyTo;
  String? _reactingCommentId;
  bool _commentsNewestFirst = true;
  final ScrollController _detailScrollController = ScrollController();

  final GlobalKey _commentPointsSpotlightKey = GlobalKey();
  final GlobalKey _onboardingComposerAreaKey = GlobalKey();
  final GlobalKey _detailReadBodyKey = GlobalKey();
  final GlobalKey _detailActionCardKey = GlobalKey();
  final GlobalKey _detailActionButtonKey = GlobalKey();
  final GlobalKey _detailBackButtonKey = GlobalKey();
  bool _commentPointsSpotlightVisible = false;
  int _spotlightEarnedPoints = 0;
  List<String> _spotlightNewBadgeIds = const [];
  bool _detailReadCoachShown = false;
  bool _detailActionCoachShown = false;
  bool _detailActionButtonCoachShown = false;
  bool _detailBackPopupShown = false;
  /// Geri spotlight hedefine dokunuldu; coach [onFinish] ile kapandıktan sonra anasayfaya dön.
  bool _detailBackSpotlightTargetTapped = false;
  bool _handlingTourBackNavigation = false;

  @override
  void initState() {
    super.initState();
    SavedItemsService.isSaved(
      widget.item.id,
    ).then((v) => setState(() => _saved = v));
    _loadMyAction();
    _commentsSub = CommentService.streamComments(widget.item.id).listen((list) {
      if (mounted) setState(() => _comments = list);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeStartFullTourDetailFlow());
    });
    if (widget.onboardingV1ComposerCoach && AuthService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 420));
        if (!mounted) return;
        FirstCommentComposerCoach.show(
          context: context,
          composerAreaKey: _onboardingComposerAreaKey,
          onFlowFinished: () async {
            await OnboardingService.setOnboardingV1Phase(
              OnboardingService.v1NeedFirstComment,
            );
          },
        );
      });
    } else if (widget.onboardingFullTourSavedFlow && AuthService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 420));
        if (!mounted) return;
        FirstCommentComposerCoach.show(
          context: context,
          composerAreaKey: _onboardingComposerAreaKey,
          onFlowFinished: () async {},
        );
      });
    }
  }

  Future<void> _maybeStartFullTourDetailFlow() async {
    if (!mounted || _detailReadCoachShown) return;
    final ftp = await OnboardingService.getGlobalTourStep();
    if (ftp != OnboardingService.ftDetailReadIntro) return;
    _detailReadCoachShown = true;
    await _showDetailInfoPopup(
      title: 'İçeriği oku',
      stepLabel: 'Adım 16/22',
      body:
          'Kırmızıyla vurgulanan metin gövdesini okuduktan sonra o alana dokun. Sonraki adımda aksiyonunu yazacaksın.',
    );
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    _showDetailReadBodyCoach();
  }

  Future<void> _loadMyAction() async {
    if (!AuthService.isLoggedIn) {
      if (mounted) setState(() => _myAction = null);
      return;
    }
    final tokenOk = await BackendService.ensureToken();
    if (!tokenOk || !mounted) return;
    final a = await BackendService.client.getActionForQuote(widget.item.id);
    if (mounted) setState(() => _myAction = a);
  }

  @override
  void dispose() {
    _commentsSub?.cancel();
    _commentController.dispose();
    _detailScrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleSaved() async {
    final nowSaved = await SavedItemsService.toggleSaved(widget.item.id);
    setState(() => _saved = nowSaved);
  }

  List<Comment> _orderedComments() {
    final roots = _comments.where((c) => c.parentId == null).toList();
    if (_commentsNewestFirst) {
      roots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      roots.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    final byParent = <String, List<Comment>>{};
    for (final c in _comments.where((c) => c.parentId != null)) {
      byParent.putIfAbsent(c.parentId!, () => []).add(c);
    }
    for (final list in byParent.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    final seen = <String>{};
    final out = <Comment>[];
    void add(Comment c) {
      if (seen.add(c.id)) out.add(c);
    }

    void addSubtree(Comment node) {
      add(node);
      for (final ch in byParent[node.id] ?? const []) {
        addSubtree(ch);
      }
    }

    for (final r in roots) {
      addSubtree(r);
    }
    for (final c in _comments) {
      if (!seen.contains(c.id)) add(c);
    }
    return out;
  }

  /// Kökten bu yoruma kadar kaç seviye (1 = doğrudan yanıt).
  int _replyDepth(Comment c) {
    if (c.parentId == null) return 0;
    final byId = {for (final x in _comments) x.id: x};
    var depth = 0;
    var cur = c;
    while (cur.parentId != null) {
      depth++;
      final p = byId[cur.parentId!];
      if (p == null) break;
      cur = p;
    }
    return depth;
  }

  Future<void> _popFullTourBadgesIfNeeded() async {
    final ftp = await OnboardingService.getGlobalTourStep();
    if (ftp != OnboardingService.ftSavedComment) return;
    if (!mounted) return;
    await OnboardingService.setGlobalTourStep(
      OnboardingService.ftBadgesAfterTourComment,
    );
    if (!mounted) return;
    Navigator.of(context).pop<String>('full_tour_badges');
  }

  Future<void> _finishV1CommentPointsCoachAndReturnHome() async {
    final ftp = await OnboardingService.getGlobalTourStep();
    if (ftp == OnboardingService.ftSavedComment) {
      await OnboardingService.setGlobalTourStep(
        OnboardingService.ftBadgesAfterTourComment,
      );
      if (!mounted) return;
      Navigator.of(context).pop<String>('full_tour_badges');
      return;
    }
    await OnboardingService.markCommentPointsSpotlightCompleted();
    if (!mounted) return;
    Navigator.of(context).pop<String>('onboarding_badges');
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!AuthService.isLoggedIn) {
      _openLogin();
      return;
    }
    final me = AuthService.backendUserId;
    final topLevelOthers =
        me != null &&
        _comments.any((c) => c.userId != me && c.parentId == null);
    final hadOthers = _replyTo == null && topLevelOthers;
    setState(() => _sendingComment = true);
    try {
      final posted = await CommentService.postComment(
        widget.item.id,
        text,
        hadOtherAuthorsOnThread: hadOthers,
        parentCommentId: _replyTo?.id,
      );
      if (posted != null && mounted) {
        _commentController.clear();
        setState(() => _replyTo = null);
        final newBadges = posted.newBadgeIds;
        final pts = posted.pointsAwarded;
        final earnedGamification = pts > 0 || newBadges.isNotEmpty;
        if (earnedGamification) {
          final showSpotlight =
              await OnboardingService.shouldShowCommentPointsSpotlight();
          if (!mounted) return;
          if (showSpotlight) {
            setState(() {
              _commentPointsSpotlightVisible = true;
              _spotlightEarnedPoints = pts;
              _spotlightNewBadgeIds = List<String>.from(newBadges);
            });
            final navigatorContext = context;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await Future<void>.delayed(const Duration(milliseconds: 420));
              if (!navigatorContext.mounted ||
                  !_commentPointsSpotlightVisible) {
                return;
              }
              CommentPointsCoach.show(
                context: navigatorContext,
                anchorKey: _commentPointsSpotlightKey,
                pointsEarned: pts,
                newBadgeIds: newBadges,
                onDone: () {
                  if (!mounted) return;
                  setState(() {
                    _commentPointsSpotlightVisible = false;
                    _spotlightEarnedPoints = 0;
                    _spotlightNewBadgeIds = const [];
                  });
                  unawaited(_finishV1CommentPointsCoachAndReturnHome());
                },
              );
            });
          } else {
            await _popFullTourBadgesIfNeeded();
            if (!mounted) return;
            if (newBadges.isNotEmpty) {
              final labels = newBadges
                  .map((id) => GamificationBadgeDef.byId(id)?.title ?? id)
                  .join(', ');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('+$pts puan! Yeni rozet: $labels'),
                  backgroundColor: const Color(0xFF374151),
                ),
              );
            } else if (pts > 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('+$pts sosyal puan kazandın'),
                  backgroundColor: const Color(0xFF374151),
                ),
              );
            }
          }
        } else {
          await _popFullTourBadgesIfNeeded();
        }
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _applyReaction(Comment c, int value) async {
    if (!AuthService.isLoggedIn) {
      _openLogin();
      return;
    }
    if (_reactingCommentId != null) return;
    setState(() => _reactingCommentId = c.id);
    try {
      final data = await CommentService.reactToComment(c.id, value);
      if (!mounted || data == null) return;
      final likes = (data['likeCount'] as num?)?.toInt() ?? c.likeCount;
      final dislikes =
          (data['dislikeCount'] as num?)?.toInt() ?? c.dislikeCount;
      int? myR;
      final mr = data['myReaction'];
      if (mr != null) myR = (mr as num).toInt();
      setState(() {
        _comments = _comments
            .map(
              (x) => x.id == c.id
                  ? x.copyWith(
                      likeCount: likes,
                      dislikeCount: dislikes,
                      myReaction: myR,
                      updateMyReaction: true,
                    )
                  : x,
            )
            .toList();
      });
      final pts = (data['pointsAwarded'] as num?)?.toInt() ?? 0;
      if (pts > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('+$pts sosyal puan'),
            backgroundColor: const Color(0xFF374151),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _reactingCommentId = null);
    }
  }

  Future<void> _deleteUserContent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('İçeriği Sil', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bu içerik silinecek. Devam etmek istiyor musunuz?',
          style: TextStyle(color: Color(0xFFB0B0B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'İptal',
              style: TextStyle(color: Color(0xFF0095FF)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await UserMotivationService.remove(widget.item.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _openLogin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LoginPage(onSuccess: () => Navigator.pop(context, true)),
      ),
    );
    if (result == true && mounted) {
      setState(() {});
      _loadMyAction();
    }
  }

  Future<void> _reportComment(Comment c) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Rapor nedeni',
                style: GoogleFonts.notoSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              title: Text(
                'Spam',
                style: GoogleFonts.notoSans(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, 'spam'),
            ),
            ListTile(
              title: Text(
                'Taciz veya hakaret',
                style: GoogleFonts.notoSans(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, 'abuse'),
            ),
            ListTile(
              title: Text(
                'Uygunsuz içerik',
                style: GoogleFonts.notoSans(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, 'inappropriate'),
            ),
            ListTile(
              title: Text(
                'Diğer',
                style: GoogleFonts.notoSans(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, 'other'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;

    String? details;
    if (reason == 'other') {
      final note = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            backgroundColor: const Color(0xFF1F1F1F),
            title: Text(
              'Kısa açıklama',
              style: GoogleFonts.notoSans(color: Colors.white),
            ),
            content: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'İsteğe bağlı',
                hintStyle: TextStyle(color: Color(0xFF6B7280)),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  controller.dispose();
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Color(0xFF0095FF)),
                ),
              ),
              FilledButton(
                onPressed: () {
                  final t = controller.text.trim();
                  controller.dispose();
                  Navigator.pop(ctx, t);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0095FF),
                ),
                child: const Text('Gönder'),
              ),
            ],
          );
        },
      );
      details = note;
    }

    final ok = await ModerationService.reportComment(
      commentId: c.id,
      quoteId: widget.item.id,
      reason: reason,
      details: details,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Raporunuz alındı. Teşekkürler.'
              : 'Rapor gönderilemedi. Giriş yapın veya tekrar deneyin.',
        ),
        backgroundColor: const Color(0xFF374151),
      ),
    );
  }

  Future<void> _blockCommentAuthor(Comment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text(
          'Kullanıcıyı engelle',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${c.userDisplayName} kullanıcısının yorumlarını görmeyeceksiniz.',
          style: const TextStyle(color: Color(0xFFB0B0B0), height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'İptal',
              style: TextStyle(color: Color(0xFF0095FF)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Engelle', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final success = await ModerationService.blockUser(c.userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Kullanıcı engellendi. Liste bir süre içinde güncellenecek.'
              : 'Engellenemedi. Giriş yapın veya tekrar deneyin.',
        ),
        backgroundColor: const Color(0xFF374151),
      ),
    );
  }

  /// Görsel üzerine bindirilmiş üst bar — Figma 60-889: geri, ortada "Günün Kürasyonu", paylaş.
  Widget _buildDetailAppBarOverlay() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              'Günün Kürasyonu',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE8E8E8),
                letterSpacing: 0.2,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: _detailBackButtonKey,
                    onPressed: _handleBackPressed,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFFE8E8E8),
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  if (widget.item.id.startsWith('user_'))
                    IconButton(
                      onPressed: _deleteUserContent,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFBFC7D5),
                        size: 22,
                      ),
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                ],
              ),
              IconButton(
                onPressed: () => _shareContent(context),
                icon: const Icon(
                  Icons.ios_share_rounded,
                  color: Color(0xFFE8E8E8),
                  size: 22,
                ),
                style: IconButton.styleFrom(padding: const EdgeInsets.all(12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _heroMetadataLine() {
    final date = _formatDate(widget.item.sentAt);
    final a = widget.item.author?.trim();
    if (a != null && a.isNotEmpty) return '$a • $date';
    return date;
  }

  String _formatDayMonthDot(String? sentAt) {
    if (sentAt == null || sentAt.isEmpty) return '—';
    final parsed = DateTime.tryParse(sentAt);
    if (parsed == null) return sentAt;
    return '${parsed.day.toString().padLeft(2, '0')}-${parsed.month.toString().padLeft(2, '0')}';
  }

  (String?, String) _articleBodyParts() {
    final b = widget.item.body.trim();
    final i = b.indexOf('\n\n');
    if (i <= 0 || i >= b.length - 2) return (null, b);
    final intro = b.substring(0, i).trim();
    final rest = b.substring(i + 2).trim();
    if (intro.isEmpty || rest.isEmpty) return (null, b);
    return (intro, rest);
  }

  Widget _buildInDepthDivider() {
    final label = '${_formatDayMonthDot(widget.item.sentAt)} · DERİNLEMESİNE';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: Color(0x22FFFFFF), height: 1, thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: GoogleFonts.notoSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ),
          const Expanded(
            child: Divider(color: Color(0x22FFFFFF), height: 1, thickness: 1),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetailInfoPopup({
    required String title,
    required String stepLabel,
    required String body,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        const accent = Color(0xFF0095FF);
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.newsreader(
                    color: const Color(0xFFE2E2E2),
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  stepLabel,
                  style: GoogleFonts.notoSans(
                    color: const Color(0xFFD1D5DB),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            body,
            style: GoogleFonts.notoSans(
              color: const Color(0xFF9CA3AF),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(foregroundColor: accent),
              child: Text(
                'Tamam',
                style: GoogleFonts.notoSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDetailReadBodyCoach() {
    var tapped = false;
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'detail_read_body',
          keyTarget: _detailReadBodyKey,
          shape: ShapeLightFocus.RRect,
          radius: 10,
          enableTargetTab: true,
          enableOverlayTab: false,
          paddingFocus: 6,
          borderSide: const BorderSide(color: Color(0x400095FF), width: 1.5),
          contents: [],
        ),
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.75,
      pulseEnable: false,
      textSkip: 'Geç',
      onClickTarget: (_) {
        tapped = true;
      },
      onFinish: () {
        if (tapped) {
          unawaited(_onDetailReadBodyTapped());
        }
      },
      onSkip: () => true,
    ).show(context: context);
  }

  Future<void> _onDetailReadBodyTapped() async {
    final ftp = await OnboardingService.getGlobalTourStep();
    if (ftp != OnboardingService.ftDetailReadIntro) return;
    final moved = await OnboardingService.onDetailReadBodyTapped();
    if (!moved) return;
    if (!mounted || _detailActionCoachShown) return;
    _detailActionCoachShown = true;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    final actionCtx = _detailActionCardKey.currentContext;
    if (actionCtx == null || !actionCtx.mounted) return;
    await Scrollable.ensureVisible(
      actionCtx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.2,
    );
    if (!mounted) return;
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'detail_action_card',
          keyTarget: _detailActionCardKey,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          enableTargetTab: true,
          enableOverlayTab: false,
          paddingFocus: 8,
          borderSide: const BorderSide(color: Color(0x400095FF), width: 1.5),
          contents: [
            TargetContent(
              align: ContentAlign.top,
              padding: const EdgeInsets.only(bottom: 12),
              builder: (c, controller) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2C2C2E)),
                ),
                child: Text(
                  'Adım 17/22\n\nKarta bir kez dokunup spotlightı kapat; sonra aksiyonunu yazıp `Aksiyon Ekle` ile kaydet.',
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
      opacityShadow: 0.75,
      pulseEnable: false,
      textSkip: 'Geç',
      onSkip: () => true,
    ).show(context: context);
  }

  Future<void> _onDetailActionSavedForTour() async {
    final moved = await OnboardingService.onDetailActionSaved();
    if (!moved || !mounted || _detailBackPopupShown) return;
    _detailBackPopupShown = true;
    await _showDetailInfoPopup(
      title: 'Anasayfaya dön',
      stepLabel: 'Adım 18/22',
      body:
          'Aksiyon kaydedildi. Şimdi sol üstteki geri oka basıp Anasayfa ekranına dön.',
    );
    if (!mounted) return;
    unawaited(_showBackButtonSpotlight());
  }

  Future<void> _showBackButtonSpotlight() async {
    if (_detailScrollController.hasClients) {
      await _detailScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted || _detailBackButtonKey.currentContext == null) return;
    _detailBackSpotlightTargetTapped = false;
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'detail_back_button',
          keyTarget: _detailBackButtonKey,
          shape: ShapeLightFocus.Circle,
          enableTargetTab: true,
          enableOverlayTab: false,
          paddingFocus: 8,
          borderSide: const BorderSide(color: Color(0x400095FF), width: 1.5),
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              padding: const EdgeInsets.only(top: 10),
              builder: (c, controller) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C2C2E)),
                ),
                child: Text(
                  'Bu geri oka basıp anasayfaya dön.',
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
      opacityShadow: 0.75,
      pulseEnable: false,
      textSkip: 'Geç',
      onClickTarget: (_) {
        _detailBackSpotlightTargetTapped = true;
      },
      onFinish: () {
        if (!_detailBackSpotlightTargetTapped) return;
        _detailBackSpotlightTargetTapped = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_handleBackPressed());
        });
      },
      onSkip: () {
        _detailBackSpotlightTargetTapped = false;
        return true;
      },
    ).show(context: context);
  }

  Future<void> _maybeShowActionButtonSpotlight(String value) async {
    if (_detailActionButtonCoachShown) return;
    if (value.trim().isEmpty) return;
    final ftp = await OnboardingService.getGlobalTourStep();
    if (ftp != OnboardingService.ftDetailReadIntro &&
        ftp != OnboardingService.ftDetailBackToHome) {
      return;
    }
    if (!mounted) return;
    _detailActionButtonCoachShown = true;
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'detail_action_button',
          keyTarget: _detailActionButtonKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          enableTargetTab: true,
          enableOverlayTab: false,
          paddingFocus: 6,
          borderSide: const BorderSide(color: Color(0x400095FF), width: 1.5),
          contents: [
            TargetContent(
              align: ContentAlign.top,
              padding: const EdgeInsets.only(bottom: 12),
              builder: (c, controller) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C2C2E)),
                ),
                child: Text(
                  'Harika. Şimdi `Aksiyon Ekle` butonuna bas.',
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
      opacityShadow: 0.75,
      pulseEnable: false,
      textSkip: 'Geç',
      onSkip: () => true,
    ).show(context: context);
  }

  Future<void> _handleBackPressed() async {
    if (_handlingTourBackNavigation) return;
    _handlingTourBackNavigation = true;
    try {
      final tourBackToProfile =
          await OnboardingService.onDetailBackConfirmedToProfile();
      if (!mounted) return;
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      }
      // Full turda bu noktada kullanıcıyı önce Anasayfa'ya döndürüp
      // alt barda Profil sekmesini spotlight ile tıklatıyoruz.
      if (tourBackToProfile) {
        OnboardingService.requestTab(0);
      }
    } finally {
      _handlingTourBackNavigation = false;
    }
  }

  Widget _buildSaveLibraryCard() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggleSaved,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2C2C2C)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: const Color(0xFFA1C9FF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bu içeriği Sakla',
                        style: GoogleFonts.notoSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE2E2E2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Daha sonra tekrar okumak için kütüphanene ekle.',
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          height: 1.35,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF6B7280),
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadableBodyText(String text) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _onDetailReadBodyTapped,
      child: KeyedSubtree(
        key: _detailReadBodyKey,
        child: Text(
          text,
          style: GoogleFonts.notoSans(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            height: 1.55,
            color: const Color(0xFFE5E7EB),
          ),
        ),
      ),
    );
  }

  static const double _heroImageBodyHeight = 280;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final heroTotalH = _heroImageBodyHeight + pad.top;
    final bodyParts = _articleBodyParts();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _detailScrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                    child: SizedBox(
                      height: heroTotalH,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned.fill(
                            child: _buildHeroImageLayer(height: heroTotalH),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: pad.top + 56,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.55),
                                      Colors.black.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                40,
                                24,
                                22,
                              ),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x00121212),
                                    Color(0xD9121212),
                                    Color(0xFF121212),
                                  ],
                                  stops: [0.0, 0.5, 1.0],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0095FF),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      (widget.item.category ?? 'Günün İçeriği')
                                          .toUpperCase(),
                                      style: GoogleFonts.notoSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                        letterSpacing: 0.8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    widget.item.title,
                                    style: GoogleFonts.newsreader(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                      height: 1.12,
                                      color: const Color(0xFFF5F5F5),
                                      letterSpacing: -0.5,
                                      shadows: const [
                                        Shadow(
                                          offset: Offset(0, 1),
                                          blurRadius: 12,
                                          color: Color(0x99000000),
                                        ),
                                      ],
                                    ),
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _heroMetadataLine(),
                                    style: GoogleFonts.notoSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: pad.top,
                            left: 0,
                            right: 0,
                            child: _buildDetailAppBarOverlay(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (bodyParts.$1 != null) ...[
                          Text(
                            bodyParts.$1!,
                            style: GoogleFonts.notoSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                              height: 1.55,
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          _buildInDepthDivider(),
                          _buildReadableBodyText(bodyParts.$2),
                        ] else ...[
                          _buildInDepthDivider(),
                          _buildReadableBodyText(bodyParts.$2),
                        ],
                        const SizedBox(height: 28),
                        _buildSaveLibraryCard(),
                        const SizedBox(height: 20),
                        KeyedSubtree(
                          key: _detailActionCardKey,
                          child: AddActionCard(
                            quoteId: widget.item.id,
                            quoteTitle: widget.item.title,
                            actionButtonKey: _detailActionButtonKey,
                            onNoteChanged: (value) {
                              unawaited(_maybeShowActionButtonSpotlight(value));
                            },
                            onActionSaved: () async {
                              await _loadMyAction();
                              if (!context.mounted) return;
                              await _onDetailActionSavedForTour();
                              if (!context.mounted) return;
                              await DailyActionOnboardingHelper.afterDailyActionSaved(
                                context,
                              );
                            },
                          ),
                        ),
                        if (_myAction != null) ...[
                          const SizedBox(height: 24),
                          _buildSavedActionCard(),
                        ],
                        const SizedBox(height: 28),
                        _buildCommentsSection(),
                        SizedBox(height: 88 + pad.bottom),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomCommentBar(),
        ],
      ),
    );
  }

  Widget _buildSavedActionCard() {
    final note = (_myAction!['note'] as String?)?.trim() ?? '';
    final rawDate = _myAction!['localDate'] as String?;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0095FF).withValues(alpha: 0.35),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140095FF),
            blurRadius: 20,
            offset: Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFFA1C9FF),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Bu sözle yaptığınız',
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE2E2E2),
                ),
              ),
            ],
          ),
          if (rawDate != null && rawDate.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              rawDate,
              style: GoogleFonts.notoSans(
                fontSize: 12,
                color: const Color(0xFFBFC7D5),
              ),
            ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              note,
              style: GoogleFonts.notoSans(
                fontSize: 15,
                height: 1.45,
                color: const Color(0xFFBFC7D5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Yorumlar (${_comments.length})',
                style: GoogleFonts.notoSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE2E2E2),
                ),
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              offset: const Offset(0, 36),
              color: const Color(0xFF1F1F1F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (v) {
                setState(() {
                  _commentsNewestFirst = v == 'newest';
                });
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'newest',
                  child: Text(
                    'En Yeni',
                    style: GoogleFonts.notoSans(
                      color: _commentsNewestFirst
                          ? const Color(0xFF0095FF)
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'oldest',
                  child: Text(
                    'En Eski',
                    style: GoogleFonts.notoSans(
                      color: !_commentsNewestFirst
                          ? const Color(0xFF0095FF)
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _commentsNewestFirst ? 'En Yeni' : 'En Eski',
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFA1C9FF),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFFA1C9FF),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Henüz yorum yok. İlk yorumu siz yapın!',
              style: GoogleFonts.notoSans(
                fontSize: 14,
                color: const Color(0xFFBFC7D5),
              ),
            ),
          )
        else
          ..._orderedComments().map((c) => _buildCommentItem(c)),
      ],
    );
  }

  Widget _buildCommentItem(Comment c) {
    final depth = _replyDepth(c);
    final busy = _reactingCommentId == c.id;
    final indent = (depth * 20.0).clamp(0.0, 120.0);
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: depth > 0 ? (19 - depth.clamp(1, 3)).toDouble() : 18,
            backgroundColor: const Color(0xFF374151),
            backgroundImage:
                c.userPhotoUrl != null && c.userPhotoUrl!.isNotEmpty
                ? CachedNetworkImageProvider(c.userPhotoUrl!)
                : null,
            child: c.userPhotoUrl == null || c.userPhotoUrl!.isEmpty
                ? Text(
                    (c.userDisplayName.isNotEmpty ? c.userDisplayName[0] : '?')
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      height: 1.4,
                      color: const Color(0xFFE5E7EB),
                    ),
                    children: [
                      TextSpan(
                        text: '${c.userDisplayName} ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(text: c.text),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatRelativeTime(c.createdAt),
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    if (AuthService.isLoggedIn) ...[
                      TextButton(
                        onPressed: () => setState(() => _replyTo = c),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: const Color(0xFFA1C9FF),
                        ),
                        child: Text(
                          'Yanıtla',
                          style: GoogleFonts.notoSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (AuthService.isLoggedIn &&
                        AuthService.backendUserId != null &&
                        c.userId.isNotEmpty &&
                        c.userId != AuthService.backendUserId)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: Color(0xFF6B7280),
                        ),
                        color: const Color(0xFF27272A),
                        onSelected: (v) {
                          if (v == 'report') _reportComment(c);
                          if (v == 'block') _blockCommentAuthor(c);
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'report',
                            child: Text(
                              'Raporla',
                              style: GoogleFonts.notoSans(color: Colors.white),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'block',
                            child: Text(
                              'Kullanıcıyı engelle',
                              style: GoogleFonts.notoSans(
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    InkWell(
                      onTap: busy ? null : () => _applyReaction(c, 1),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.thumb_up_alt_outlined,
                              size: 16,
                              color: c.myReaction == 1
                                  ? const Color(0xFFA1C9FF)
                                  : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${c.likeCount}',
                              style: GoogleFonts.notoSans(
                                fontSize: 12,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: busy ? null : () => _applyReaction(c, -1),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.thumb_down_alt_outlined,
                              size: 16,
                              color: c.myReaction == -1
                                  ? const Color(0xFFF97316)
                                  : const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${c.dislikeCount}',
                              style: GoogleFonts.notoSans(
                                fontSize: 12,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCommentBar() {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      color: const Color(0xFF121212),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: inset),
        child: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              border: Border(
                top: BorderSide(color: Color(0x18FFFFFF), width: 1),
              ),
            ),
            child: AuthService.isLoggedIn
                ? _buildCommentComposerRow()
                : _buildGuestBottomComposer(),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestBottomComposer() {
    return Material(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openLogin,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Düşüncelerini paylaş...',
                  style: GoogleFonts.notoSans(
                    fontSize: 15,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2A2A2A),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Color(0xFF4B5563),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentPointsRewardStrip() {
    final pts = _spotlightEarnedPoints;
    final badges = _spotlightNewBadgeIds;
    final badgeText = badges.isEmpty
        ? ''
        : badges
              .map((id) => GamificationBadgeDef.byId(id)?.title ?? id)
              .join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        key: _commentPointsSpotlightKey,
        color: const Color(0xFF0D2847),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF0095FF).withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.stars_rounded,
                color: Color(0xFF7DD3FC),
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pts > 0
                          ? '+$pts sosyal puan'
                          : (badgeText.isNotEmpty
                                ? 'Yeni rozet açıldı'
                                : 'Puanın güncellendi'),
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (badgeText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        badgeText,
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          height: 1.35,
                          color: const Color(0xFFBFC7D5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentComposerRow() {
    return KeyedSubtree(
      key: _onboardingComposerAreaKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_commentPointsSpotlightVisible) _buildCommentPointsRewardStrip(),
          if (_replyTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x14FFFFFF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.reply_rounded,
                        size: 18,
                        color: Color(0xFFA1C9FF),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_replyTo!.userDisplayName} kullanıcısına yanıt',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSans(
                            fontSize: 13,
                            color: const Color(0xFFE5E7EB),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _replyTo = null),
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFF9CA3AF),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF374151),
                backgroundImage:
                    AuthService.photoUrl != null &&
                        AuthService.photoUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(AuthService.photoUrl!)
                    : null,
                child:
                    AuthService.photoUrl == null ||
                        AuthService.photoUrl!.isEmpty
                    ? Text(
                        (AuthService.displayName?.isNotEmpty == true
                                ? AuthService.displayName![0]
                                : '?')
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: GoogleFonts.notoSans(
                    fontSize: 15,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: _replyTo != null
                        ? 'Yanıtını yaz...'
                        : 'Düşüncelerini paylaş...',
                    hintStyle: GoogleFonts.notoSans(
                      fontSize: 15,
                      color: const Color(0xFF6B7280),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: const BorderSide(color: Color(0xFF333333)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: const BorderSide(color: Color(0xFF333333)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: const BorderSide(
                        color: Color(0xFF0095FF),
                        width: 1.5,
                      ),
                    ),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  onSubmitted: (_) => _postComment(),
                ),
              ),
              const SizedBox(width: 10),
              _buildGradientSendButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradientSendButton() {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _sendingComment ? null : _postComment,
          child: Ink(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0095FF), Color(0xFF0070E0)],
              ),
            ),
            child: Center(
              child: _sendingComment
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    if (diff.inDays < 7) return '${diff.inDays} gün';
    return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
  }

  /// Hero görsel katmanı (tam yükseklik; üst bar + başlık Stack içinde).
  Widget _buildHeroImageLayer({required double height}) {
    final item = widget.item;
    return item.imageBase64 != null
        ? Image.memory(
            base64Decode(item.imageBase64!),
            fit: BoxFit.cover,
            width: double.infinity,
            height: height,
          )
        : (item.displayImageUrl != null && item.displayImageUrl!.isNotEmpty
              ? MotivationCachedImage(
                  imageUrl: item.displayImageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: height,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFF0E0E0E),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0095FF),
                      ),
                    ),
                  ),
                  error: (_, __, ___) => Container(
                    color: const Color(0xFF0E0E0E),
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: Color(0xFF6B7280),
                      size: 48,
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFF0E0E0E),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_outlined,
                    color: Color(0xFF6B7280),
                    size: 64,
                  ),
                ));
  }

  String _formatDate(String? sentAt) {
    if (sentAt == null || sentAt.isEmpty) return '—';
    try {
      final parsed = DateTime.tryParse(sentAt);
      if (parsed != null) {
        const months = [
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
        return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
      }
    } catch (_) {}
    return sentAt;
  }

  Future<void> _shareContent(BuildContext context) async {
    final item = widget.item;
    final text = '${item.title}\n\n${item.body}';

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chat_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                title: Text(
                  'WhatsApp ile Paylaş',
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final encoded = Uri.encodeComponent(text);
                  final uri = Uri.parse('whatsapp://send?text=$encoded');
                  try {
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      await Share.share(text, subject: item.title);
                    }
                  } catch (_) {
                    if (ctx.mounted) {
                      await Share.share(text, subject: item.title);
                    }
                  }
                },
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.share_rounded,
                    color: Color(0xFFA1C9FF),
                    size: 24,
                  ),
                ),
                title: Text(
                  'Diğer uygulamalarla paylaş',
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Share.share(text, subject: item.title);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
