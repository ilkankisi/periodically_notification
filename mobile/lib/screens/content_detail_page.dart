import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/comment.dart';
import '../models/motivation.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../models/gamification_badge.dart';
import '../services/comment_service.dart';
import '../services/moderation_service.dart';
import '../services/saved_items_service.dart';
import '../services/user_motivation_service.dart';
import '../widgets/add_action_card.dart';
import '../widgets/header_bar.dart';
import '../widgets/motivation_cached_image.dart';
import 'login_page.dart';

/// İçerik detay sayfası - Görsel tasarıma uygun makale görünümü
class ContentDetailPage extends StatefulWidget {
  final Motivation item;

  const ContentDetailPage({super.key, required this.item});

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

  @override
  void initState() {
    super.initState();
    SavedItemsService.isSaved(widget.item.id).then((v) => setState(() => _saved = v));
    _loadMyAction();
    _commentsSub = CommentService.streamComments(widget.item.id).listen((list) {
      if (mounted) setState(() => _comments = list);
    });
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
    super.dispose();
  }

  Future<void> _toggleSaved() async {
    final nowSaved = await SavedItemsService.toggleSaved(widget.item.id);
    setState(() => _saved = nowSaved);
  }

  List<Comment> _orderedComments() {
    final roots = _comments.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
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

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!AuthService.isLoggedIn) {
      _openLogin();
      return;
    }
    final me = AuthService.backendUserId;
    final topLevelOthers = me != null &&
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
      final dislikes = (data['dislikeCount'] as num?)?.toInt() ?? c.dislikeCount;
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
            child: const Text('İptal', style: TextStyle(color: Color(0xFF2094F3))),
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
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _openLogin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPage(
          onSuccess: () => Navigator.pop(context, true),
        ),
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
              title: Text('Spam', style: GoogleFonts.notoSans(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'spam'),
            ),
            ListTile(
              title: Text('Taciz veya hakaret', style: GoogleFonts.notoSans(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'abuse'),
            ),
            ListTile(
              title: Text('Uygunsuz içerik', style: GoogleFonts.notoSans(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'inappropriate'),
            ),
            ListTile(
              title: Text('Diğer', style: GoogleFonts.notoSans(color: Colors.white)),
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
            title: Text('Kısa açıklama', style: GoogleFonts.notoSans(color: Colors.white)),
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
                child: const Text('İptal', style: TextStyle(color: Color(0xFF2094F3))),
              ),
              FilledButton(
                onPressed: () {
                  final t = controller.text.trim();
                  controller.dispose();
                  Navigator.pop(ctx, t);
                },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2094F3)),
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
        content: Text(ok ? 'Raporunuz alındı. Teşekkürler.' : 'Rapor gönderilemedi. Giriş yapın veya tekrar deneyin.'),
        backgroundColor: const Color(0xFF374151),
      ),
    );
  }

  Future<void> _blockCommentAuthor(Comment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Kullanıcıyı engelle', style: TextStyle(color: Colors.white)),
        content: Text(
          '${c.userDisplayName} kullanıcısının yorumlarını görmeyeceksiniz.',
          style: const TextStyle(color: Color(0xFFB0B0B0), height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: Color(0xFF2094F3))),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          HeaderBar(
            leading: SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(minimumSize: const Size(24, 24)),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.item.id.startsWith('user_'))
                  IconButton(
                    onPressed: _deleteUserContent,
                    icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 24),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                  ),
                IconButton(
                  onPressed: _toggleSaved,
                  icon: Icon(
                    _saved ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.white,
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                ),
                IconButton(
                  onPressed: () => _shareContent(context),
                  icon: const Icon(Icons.share, color: Colors.white, size: 24),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                ),
              ],
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroImage(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          style: GoogleFonts.newsreader(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.only(top: 4, bottom: 16),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.white, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.category,
                                color: Color(0xFF2094F3),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.item.category ?? 'Günün İçeriği',
                                style: GoogleFonts.notoSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 19 / 14,
                                  color: const Color(0xFF2094F3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Text(
                            widget.item.body,
                            style: GoogleFonts.notoSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                              height: 23 / 17,
                              color: const Color(0xFFB0B0B0),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.only(top: 24, bottom: 24),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.white, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Color(0xFF6B7280),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(widget.item.sentAt),
                                style: GoogleFonts.notoSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 16 / 12,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AddActionCard(
                          quoteId: widget.item.id,
                          quoteTitle: widget.item.title,
                          onActionSaved: _loadMyAction,
                        ),
                        if (_myAction != null) ...[
                          const SizedBox(height: 24),
                          _buildSavedActionCard(),
                        ],
                        const SizedBox(height: 24),
                        _buildCommentsSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedActionCard() {
    final note = (_myAction!['note'] as String?)?.trim() ?? '';
    final rawDate = _myAction!['localDate'] as String?;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2094F3).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF2094F3), size: 22),
              const SizedBox(width: 8),
              Text(
                'Bu sözle yaptığınız',
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
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
                color: const Color(0xFF6B7280),
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
                color: const Color(0xFFB0B0B0),
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
        const SizedBox(height: 8),
        Text(
          'Yorumlar (${_comments.length})',
          style: GoogleFonts.notoSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Yanıt ve tepkiler sosyal puan kazandırır. Uygunsuz yorumları ⋮ menüsünden raporlayabilir veya yazarı engelleyebilirsin.',
          style: GoogleFonts.notoSans(
            fontSize: 12,
            color: const Color(0xFF6B7280),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 16),
        // Yorum listesi - Instagram tarzı
        if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Henüz yorum yok. İlk yorumu siz yapın!',
              style: GoogleFonts.notoSans(
                fontSize: 14,
                color: const Color(0xFF6B7280),
              ),
            ),
          )
        else
          ..._orderedComments().map((c) => _buildCommentItem(c)),
        const SizedBox(height: 24),
        // Yorum input veya giriş prompt
        AuthService.isLoggedIn ? _buildCommentInput() : _buildLoginToCommentPrompt(),
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
            backgroundImage: c.userPhotoUrl != null && c.userPhotoUrl!.isNotEmpty
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
                          foregroundColor: const Color(0xFF2094F3),
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
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF6B7280)),
                        color: const Color(0xFF27272A),
                        onSelected: (v) {
                          if (v == 'report') _reportComment(c);
                          if (v == 'block') _blockCommentAuthor(c);
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'report',
                            child: Text('Raporla', style: GoogleFonts.notoSans(color: Colors.white)),
                          ),
                          PopupMenuItem(
                            value: 'block',
                            child: Text(
                              'Kullanıcıyı engelle',
                              style: GoogleFonts.notoSans(color: Colors.redAccent),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.thumb_up_alt_outlined,
                              size: 16,
                              color: c.myReaction == 1
                                  ? const Color(0xFF2094F3)
                                  : const Color(0xFF6B7280),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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

  Widget _buildCommentInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_replyTo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.reply, size: 18, color: Colors.blue.shade300),
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
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF9CA3AF)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
          radius: 16,
          backgroundColor: const Color(0xFF374151),
          backgroundImage: AuthService.photoUrl != null &&
                  AuthService.photoUrl!.isNotEmpty
              ? CachedNetworkImageProvider(AuthService.photoUrl!)
              : null,
          child: AuthService.photoUrl == null || AuthService.photoUrl!.isEmpty
              ? Text(
                  (AuthService.displayName?.isNotEmpty == true
                          ? AuthService.displayName![0]
                          : '?')
                      .toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _commentController,
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: _replyTo != null ? 'Yanıtını yaz...' : 'Yorum ekle...',
              hintStyle: GoogleFonts.notoSans(
                fontSize: 14,
                color: const Color(0xFF6B7280),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFF374151)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFF374151)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFF2094F3)),
              ),
            ),
            maxLines: 3,
            minLines: 1,
            onSubmitted: (_) => _postComment(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _sendingComment ? null : _postComment,
          icon: _sendingComment
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF2094F3),
                  ),
                )
              : const Icon(Icons.send, color: Color(0xFF2094F3), size: 24),
        ),
      ],
    ),
      ],
    );
  }

  Widget _buildLoginToCommentPrompt() {
    return GestureDetector(
      onTap: _openLogin,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.login, color: const Color(0xFF2094F3), size: 20),
            const SizedBox(width: 12),
            Text(
              'Giriş yaparak yorum yapabilirsiniz',
              style: GoogleFonts.notoSans(
                fontSize: 14,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ],
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

  Widget _buildHeroImage() {
    final item = widget.item;
    return SizedBox(
      width: double.infinity,
      height: 288,
      child: item.imageBase64 != null
          ? Image.memory(
              base64Decode(item.imageBase64!),
              fit: BoxFit.fitHeight,
              width: double.infinity,
              height: 288,
            )
          : (item.displayImageUrl != null && item.displayImageUrl!.isNotEmpty
              ? MotivationCachedImage(
                  imageUrl: item.displayImageUrl!,
                  fit: BoxFit.fitHeight,
                  width: double.infinity,
                  height: 288,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFF27272A),
                    child: const Center(
                      child: CircularProgressIndicator(color: Color(0xFF2094F3)),
                    ),
                  ),
                  error: (_, __, ___) => Container(
                    color: const Color(0xFF27272A),
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Color(0xFF6B7280),
                      size: 48,
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFF27272A),
                  child: const Icon(
                    Icons.image,
                    color: Color(0xFF6B7280),
                    size: 64,
                  ),
                )),
    );
  }

  String _formatDate(String? sentAt) {
    if (sentAt == null || sentAt.isEmpty) return '—';
    try {
      final parsed = DateTime.tryParse(sentAt);
      if (parsed != null) {
        const months = [
          'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
          'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
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
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
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
                  child: const Icon(Icons.chat, color: Colors.white, size: 24),
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
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.share, color: Colors.white, size: 24),
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
