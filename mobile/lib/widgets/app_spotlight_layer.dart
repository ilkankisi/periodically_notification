import 'dart:async';

import 'package:flutter/material.dart';

/// [AppSpotlightLayer.show] kapanış nedeni.
enum AppSpotlightReason {
  skipped,
  targetTapped,
  captionNext,
}

/// [GlobalKey] hedefinin ekrandaki dikdörtgeni (padding ile genişletilmiş).
Rect? appSpotlightTargetRect(
  GlobalKey key, {
  EdgeInsets padding = EdgeInsets.zero,
}) {
  final ctx = key.currentContext;
  if (ctx == null) return null;
  final ro = ctx.findRenderObject();
  if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
  final topLeft = ro.localToGlobal(Offset.zero);
  return padding.inflateRect(topLeft & ro.size);
}

/// `tutorial_coach_mark` yerine: dört bölgeli gölgü + yuvarlak delik + isteğe bağlı delik tıklaması.
class AppSpotlightLayer {
  AppSpotlightLayer._();

  static OverlayEntry? _entry;
  static void Function(AppSpotlightReason reason)? _onClosed;

  static bool get isShowing => _entry != null;

  static void _finish(AppSpotlightReason reason) {
    final cb = _onClosed;
    _onClosed = null;
    _entry?.remove();
    _entry = null;
    cb?.call(reason);
  }

  static void dismiss() {
    _entry?.remove();
    _entry = null;
    _onClosed = null;
  }

  /// Delik alanı gerçek widget tarafından kullanıldı (ör. Keşfet kartına dokunma).
  static void completeTargetTap() {
    if (_entry == null || _onClosed == null) return;
    _finish(AppSpotlightReason.targetTapped);
  }

  /// Bilgi kartındaki "Tamam" / "Sonraki" gibi.
  static void completeCaptionStep() {
    if (_entry == null || _onClosed == null) return;
    _finish(AppSpotlightReason.captionNext);
  }

  static void removeOverlayEntry() => dismiss();

  static void show({
    required BuildContext context,
    required GlobalKey targetKey,
    required Widget caption,
    EdgeInsets holePadding = const EdgeInsets.all(6),
    double holeBorderRadius = 12,
    Color scrim = const Color(0xC7000000),
    Color borderColor = const Color(0x400095FF),
    double borderWidth = 1.5,
    Alignment skipAlignment = Alignment.topRight,
    String skipLabel = 'Geç',
    TextStyle? skipTextStyle,
    Alignment captionAlignment = const Alignment(0, -0.72),
    EdgeInsets captionMargin = const EdgeInsets.symmetric(horizontal: 18),
    Future<void> Function()? beforeShow,
    /// Null iken delikteki dokunuş alttaki gerçek widget’a gider (ör. Keşfet kartı).
    VoidCallback? onHoleTap,
    required void Function(AppSpotlightReason reason) onClosed,
  }) {
    dismiss();
    _onClosed = onClosed;
    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return _SpotlightOverlay(
          targetKey: targetKey,
          holePadding: holePadding,
          holeBorderRadius: holeBorderRadius,
          scrim: scrim,
          borderColor: borderColor,
          borderWidth: borderWidth,
          skipAlignment: skipAlignment,
          skipLabel: skipLabel,
          skipTextStyle: skipTextStyle,
          caption: caption,
          captionAlignment: captionAlignment,
          captionMargin: captionMargin,
          beforeShow: beforeShow,
          onHoleTap: onHoleTap,
          onSkip: () => _finish(AppSpotlightReason.skipped),
          onHoleConfirm: onHoleTap == null
              ? null
              : () {
                  onHoleTap();
                  _finish(AppSpotlightReason.targetTapped);
                },
          onMounted: () {
            _entry = entry;
          },
        );
      },
    );
    overlay.insert(entry);
  }

  /// Ardışık adımlar; [onStepResult] her adımın kapanışında (hedef, geç).
  static Future<void> showSequence({
    required BuildContext context,
    required List<AppSpotlightSequenceStep> steps,
    Future<void> Function(int index)? beforeStep,
    void Function(bool skippedSequence)? onSequenceEnd,
  }) async {
    var skippedSeq = false;
    for (var i = 0; i < steps.length; i++) {
      if (skippedSeq) break;
      final step = steps[i];
      if (beforeStep != null) await beforeStep(i);
      final done = Completer<void>();
      show(
        context: context,
        targetKey: step.targetKey,
        caption: step.caption,
        holePadding: step.holePadding,
        holeBorderRadius: step.holeBorderRadius,
        scrim: step.scrim,
        borderColor: step.borderColor,
        borderWidth: step.borderWidth,
        skipAlignment: step.skipAlignment,
        skipLabel: step.skipLabel,
        skipTextStyle: step.skipTextStyle,
        captionAlignment: step.captionAlignment,
        captionMargin: step.captionMargin,
        beforeShow: step.beforeShow,
        onHoleTap: step.onHoleTap,
        onClosed: (AppSpotlightReason reason) {
          step.onStepClose?.call(reason);
          if (reason == AppSpotlightReason.skipped) skippedSeq = true;
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future;
      dismiss();
    }
    onSequenceEnd?.call(skippedSeq);
  }
}

class AppSpotlightSequenceStep {
  const AppSpotlightSequenceStep({
    required this.targetKey,
    required this.caption,
    this.holePadding = const EdgeInsets.all(8),
    this.holeBorderRadius = 12,
    this.scrim = const Color(0xC7000000),
    this.borderColor = const Color(0x400095FF),
    this.borderWidth = 1.5,
    this.skipAlignment = Alignment.topRight,
    this.skipLabel = 'Geç',
    this.skipTextStyle,
    this.captionAlignment = const Alignment(0, -0.72),
    this.captionMargin = const EdgeInsets.symmetric(horizontal: 18),
    this.beforeShow,
    this.onHoleTap,
    this.onStepClose,
  });

  final GlobalKey targetKey;
  final Widget caption;
  final EdgeInsets holePadding;
  final double holeBorderRadius;
  final Color scrim;
  final Color borderColor;
  final double borderWidth;
  final Alignment skipAlignment;
  final String skipLabel;
  final TextStyle? skipTextStyle;
  final Alignment captionAlignment;
  final EdgeInsets captionMargin;
  final Future<void> Function()? beforeShow;
  final VoidCallback? onHoleTap;
  final void Function(AppSpotlightReason reason)? onStepClose;
}

class _SpotlightOverlay extends StatefulWidget {
  const _SpotlightOverlay({
    required this.targetKey,
    required this.holePadding,
    required this.holeBorderRadius,
    required this.scrim,
    required this.borderColor,
    required this.borderWidth,
    required this.skipAlignment,
    required this.skipLabel,
    required this.skipTextStyle,
    required this.caption,
    required this.captionAlignment,
    required this.captionMargin,
    this.beforeShow,
    this.onHoleTap,
    required this.onSkip,
    required this.onHoleConfirm,
    required this.onMounted,
  });

  final GlobalKey targetKey;
  final EdgeInsets holePadding;
  final double holeBorderRadius;
  final Color scrim;
  final Color borderColor;
  final double borderWidth;
  final Alignment skipAlignment;
  final String skipLabel;
  final TextStyle? skipTextStyle;
  final Widget caption;
  final Alignment captionAlignment;
  final EdgeInsets captionMargin;
  final Future<void> Function()? beforeShow;
  final VoidCallback? onHoleTap;
  final VoidCallback onSkip;
  final VoidCallback? onHoleConfirm;
  final VoidCallback onMounted;

  @override
  State<_SpotlightOverlay> createState() => _SpotlightOverlayState();
}

class _SpotlightOverlayState extends State<_SpotlightOverlay> {
  Rect? _hole;
  Size _screen = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      widget.onMounted();
      if (widget.beforeShow != null) {
        await widget.beforeShow!();
      }
      if (mounted) _syncHole();
    });
  }

  void _syncHole() {
    final media = MediaQuery.sizeOf(context);
    _screen = media;
    final r = appSpotlightTargetRect(
      widget.targetKey,
      padding: widget.holePadding,
    );
    setState(() => _hole = r);
  }

  List<Widget> _dimming(Rect hole) {
    final w = _screen.width;
    final h = _screen.height;
    final t = hole.top.clamp(0.0, h);
    final l = hole.left.clamp(0.0, w);
    final r = hole.right.clamp(0.0, w);
    final b = hole.bottom.clamp(0.0, h);
    final c = widget.scrim;
    return [
      Positioned(left: 0, right: 0, top: 0, height: t, child: ColoredBox(color: c)),
      Positioned(left: 0, right: 0, top: b, bottom: 0, child: ColoredBox(color: c)),
      Positioned(left: 0, width: l, top: t, height: b - t, child: ColoredBox(color: c)),
      Positioned(left: r, right: 0, top: t, height: b - t, child: ColoredBox(color: c)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncHole());
    final hole = _hole;
    if (hole == null || _screen == Size.zero) {
      return const SizedBox.shrink();
    }
    final radius = widget.holeBorderRadius;
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: widget.borderColor, width: widget.borderWidth),
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ..._dimming(hole),
          Positioned.fromRect(
            rect: hole,
            child: IgnorePointer(
              ignoring: widget.onHoleConfirm == null,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onHoleConfirm,
                  borderRadius: BorderRadius.circular(radius),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(shape: border),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: widget.skipAlignment,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: TextButton(
                  onPressed: widget.onSkip,
                  child: Text(
                    widget.skipLabel,
                    style: widget.skipTextStyle ??
                        const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: widget.captionAlignment,
            child: SafeArea(
              child: Padding(
                padding: widget.captionMargin,
                child: widget.caption,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
