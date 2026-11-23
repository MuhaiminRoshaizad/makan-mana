import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

OverlayEntry? _showing;

/// A short message in an ink pill that drops from the top of the screen,
/// with an optional action such as Undo. It sits above every page and
/// sheet, so it never covers the tab bar or the Spin button. A new toast
/// replaces the last one.
///
/// [failed] marks a message about something that did not work. A message
/// that reports nothing done, such as a hint, passes its own [icon] in
/// place of the tick, or [plain] for none at all.
///
/// [duration] overrides how long it stays (3 s, or 5 s with an action);
/// [countdown] draws a bar along its foot that drains over that time, for a
/// message that stops applying when it goes. [onHidden] is called once,
/// the moment it stops showing for any reason: its time ran out, it was
/// flicked away, or another toast replaced it.
///
/// [overlay], taken from [context] earlier, is for a caller whose widget may
/// be gone by the time it reports; [context] is then not used.
void showToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  bool failed = false,
  IconData? icon,
  bool plain = false,
  Duration? duration,
  bool countdown = false,
  VoidCallback? onHidden,
  OverlayState? overlay,
}) {
  final OverlayState into = overlay ?? Overlay.of(context, rootOverlay: true);
  _dismiss(_showing);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      failed: failed,
      icon: icon,
      plain: plain,
      duration: duration ?? Duration(seconds: actionLabel == null ? 3 : 5),
      countdown: countdown,
      onHidden: onHidden,
      onGone: () => _dismiss(entry),
    ),
  );
  _showing = entry;
  into.insert(entry);
}

/// Takes down the toast showing, if any, at once.
void hideToast() => _dismiss(_showing);

void _dismiss(OverlayEntry? entry) {
  if (entry == null) return;
  if (identical(_showing, entry)) _showing = null;
  if (entry.mounted) entry.remove();
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.failed,
    required this.icon,
    required this.plain,
    required this.duration,
    required this.countdown,
    required this.onHidden,
    required this.onGone,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool failed;
  final IconData? icon;
  final bool plain;
  final Duration duration;
  final bool countdown;
  final VoidCallback? onHidden;
  final VoidCallback onGone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.long,
    reverseDuration: AppMotion.short,
  );

  /// The countdown bar: full at 1, empty at 0 when the time is up.
  late final AnimationController _left = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  Timer? _timer;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    // Long enough to read, and to reach Undo when there is one.
    _timer = Timer(widget.duration, _go);
    if (widget.countdown) _left.animateTo(0, curve: Curves.linear);
  }

  void _hide() {
    if (_hidden) return;
    _hidden = true;
    widget.onHidden?.call();
  }

  Future<void> _go() async {
    _timer?.cancel();
    if (!mounted) return;
    // It no longer applies from the moment it starts to leave.
    _hide();
    await _c.reverse();
    if (mounted) widget.onGone();
  }

  @override
  void dispose() {
    _hide();
    _timer?.cancel();
    _c.dispose();
    _left.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.disableAnimationsOf(context);
    final Animation<double> t = CurvedAnimation(
      parent: _c,
      curve: still ? Curves.linear : Curves.easeOutBack,
      reverseCurve: AppMotion.exit,
    );
    final Widget pill = Container(
      constraints: const BoxConstraints(minHeight: 52, maxWidth: 420),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x4026241F),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!widget.plain) ...<Widget>[
            Icon(
              widget.icon ??
                  (widget.failed
                      ? CupertinoIcons.exclamationmark_triangle
                      : CupertinoIcons.checkmark_alt),
              size: AppIconSize.dense,
              color: AppColors.surface,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Flexible(
            child: Text(
              widget.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: AppColors.surface,
              ),
            ),
          ),
          if (widget.actionLabel != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.ink,
                shape: const StadiumBorder(),
                minimumSize: const Size(48, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () {
                widget.onAction?.call();
                _go();
              },
              child: Text(widget.actionLabel!),
            ),
          ],
        ],
      ),
    );
    return Positioned(
      top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedBuilder(
          animation: t,
          builder: (BuildContext context, Widget? child) => Opacity(
            opacity: _c.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, still ? 0 : -72 * (1 - t.value)),
              child: child,
            ),
          ),
          child: GestureDetector(
            // Flick it away upwards.
            onVerticalDragEnd: (DragEndDetails d) {
              if ((d.primaryVelocity ?? 0) < 0) _go();
            },
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Material(
                type: MaterialType.transparency,
                child: widget.countdown
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          children: <Widget>[
                            pill,
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 3,
                              child: _Countdown(left: _left),
                            ),
                          ],
                        ),
                      )
                    : pill,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin bar along the foot that empties as the toast's time runs out.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.left});

  final Animation<double> left;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: left,
      builder: (BuildContext context, _) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: left.value.clamp(0.0, 1.0),
        child: const ColoredBox(color: AppColors.surface),
      ),
    );
  }
}
