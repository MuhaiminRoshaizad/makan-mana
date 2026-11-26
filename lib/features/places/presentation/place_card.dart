import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/nav_cover.dart';
import '../../../core/widgets/tab_back.dart';
import '../domain/place.dart';
import 'place_sheet.dart';

/// A place as a card over its tab, which grows into the full sheet: pulled
/// up, or tapped, it widens to the screen's edges and rises to the top, and
/// the tab bar slides away under it (docs/decisions.md 022). Pulled down it
/// shrinks back to the card, and further down it goes.
///
/// Put it in a [Stack] filling the tab. A new [place] swaps what the card
/// shows in place; null sends the card away. Back collapses the sheet, then
/// closes the card.
class PlaceCardHost extends ConsumerStatefulWidget {
  const PlaceCardHost({
    super.key,
    required this.place,
    required this.won,
    required this.onClose,
    this.onSeeOnMap,
    this.onSpinAgain,
    this.onGone,
  });

  final Place? place;

  /// A spin's winner, so the card says so.
  final bool won;

  /// The card was closed from inside it: its Close, a pull down or Back.
  final VoidCallback onClose;

  final VoidCallback? onSeeOnMap;
  final VoidCallback? onSpinAgain;

  /// The card has finished leaving.
  final VoidCallback? onGone;

  @override
  ConsumerState<PlaceCardHost> createState() => _PlaceCardHostState();
}

class _PlaceCardHostState extends ConsumerState<PlaceCardHost>
    with TickerProviderStateMixin {
  /// 0 the card, 1 the full sheet; a spring passes either a little.
  late final AnimationController _grow = AnimationController.unbounded(
    vsync: this,
  );

  /// 0 gone below the screen, 1 in place.
  late final AnimationController _shown = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    reverseDuration: AppMotion.medium,
  );

  final ScrollController _scroll = ScrollController();
  double _peekHeight = 260;
  late Place? _place = widget.place;
  TabBack? _back;
  late final ValueNotifier<double> _cover;

  bool get _still => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _cover = ref.read(navCoverProvider);
    _grow.addListener(_tellCover);
    _shown.addListener(_tellCover);
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (_place != null) _enter();
    }
    final TabBack? back = TabBackScope.maybeOf(context);
    if (back != _back) {
      _back?.release(_onBack);
      _back = back;
      if (_place != null) _back?.claim(_onBack);
    }
  }

  @override
  void didUpdateWidget(PlaceCardHost old) {
    super.didUpdateWidget(old);
    final Place? next = widget.place;
    if (next == null) {
      if (_place != null) _leave();
    } else if (next.id != _place?.id ||
        _shown.status == AnimationStatus.reverse) {
      final bool wasShown = _place != null && _shown.value > 0;
      setState(() => _place = next);
      if (_scroll.hasClients) _scroll.jumpTo(0);
      if (!wasShown || _shown.status == AnimationStatus.reverse) {
        _enter();
      } else {
        // Another place: the card stays and only what it shows changes.
        _settle(0);
      }
    }
  }

  @override
  void dispose() {
    _back?.release(_onBack);
    // The tab bar comes back whatever happens to the card.
    _cover.value = 0;
    _grow.dispose();
    _shown.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _tellCover() {
    _cover.value = (_grow.value.clamp(0.0, 1.0)) * _shown.value;
  }

  void _enter() {
    _grow.value = 0;
    _back?.claim(_onBack);
    if (_still) {
      _shown.value = 1;
    } else {
      _shown.forward(from: _shown.value);
    }
  }

  Future<void> _leave() async {
    _back?.release(_onBack);
    if (_still) {
      _shown.value = 0;
    } else {
      await _shown.reverse();
    }
    if (!mounted || widget.place != null) return;
    setState(() => _place = null);
    _grow.value = 0;
    widget.onGone?.call();
  }

  void _close() {
    widget.onClose();
    // The parent drops the place, and didUpdateWidget sends the card away;
    // leave now too, in case it keeps the place.
    if (widget.place != null) _leave();
  }

  bool _onBack() {
    if (_place == null) return false;
    if (_grow.value > 0.5) {
      _settle(0);
    } else {
      _close();
    }
    return true;
  }

  /// The card is as tall as the place's summary and buttons, with the
  /// handle above and the padding below.
  void _measured(Size size) {
    final double h = size.height + 26 + AppSpacing.lg;
    if ((h - _peekHeight).abs() <= 0.5) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _peekHeight = h);
    });
  }

  void _settle(double to, [double velocity = 0]) {
    if (_still) {
      _grow.value = to;
      return;
    }
    _grow
        .animateWith(
          SpringSimulation(AppMotion.spring, _grow.value, to, velocity),
        )
        // The spring stops a hair short; land exactly.
        .then((_) {
          if (mounted) _grow.value = to;
        });
  }

  // Dragging: the card follows the finger, in the units of _grow.
  double _span = 1;

  /// Where the card was when the finger came down: a quarter of the way
  /// from there is enough to go on to the other end.
  double _dragFrom = 0;

  void _dragStart(DragStartDetails d) {
    _grow.stop();
    _dragFrom = _grow.value > 0.5 ? 1 : 0;
  }

  void _drag(DragUpdateDetails d) {
    _grow.stop();
    _grow.value -= d.delta.dy / _span;
  }

  void _release(DragEndDetails d) {
    final double v = -(d.primaryVelocity ?? 0) / _span;
    final double at = _grow.value;
    // Pulled well below the card, or flicked down from it: it goes.
    if (at < -0.18 || (at < 0.15 && v < -2.5)) {
      _close();
      return;
    }
    final double to = v > 1.5
        ? 1
        : v < -1.5
        ? 0
        : _dragFrom == 0
        ? (at > 0.25 ? 1 : 0)
        : (at < 0.75 ? 0 : 1);
    _settle(to, v);
  }

  /// A finger is dragging the full sheet's content. The content stays
  /// scrollable to the end of that drag, even once the sheet has started
  /// to shrink: switching it off mid-drag would cancel the drag.
  bool _contentDrag = false;

  /// A pull down on the full sheet's content, once it is scrolled to the
  /// top, shrinks the sheet; pushed back up in the same drag, the sheet
  /// grows again before the content scrolls.
  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      setState(() => _contentDrag = true);
      _dragFrom = 1;
    } else if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0) {
      _grow.stop();
      _grow.value += n.overscroll / _span;
    } else if (n is ScrollUpdateNotification &&
        n.dragDetails != null &&
        _grow.value < 1 &&
        (n.scrollDelta ?? 0) > 0) {
      _grow.value = math.min(1, _grow.value + n.scrollDelta! / _span);
      _scroll.jumpTo(0);
    } else if (n is ScrollEndNotification && _contentDrag) {
      setState(() => _contentDrag = false);
      if (_grow.value < 0.999) {
        _release(n.dragDetails ?? DragEndDetails(primaryVelocity: 0));
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final Place? place = _place;
    if (place == null) return const SizedBox.shrink();
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double gap = AppNavMetrics.clearance(safe.bottom);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double fullHeight = c.maxHeight - safe.top - AppSpacing.sm;
        _span = math.max(1, fullHeight - _peekHeight);
        return AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_grow, _shown]),
          builder: (BuildContext context, Widget? child) {
            final double g = _grow.value;
            final double k = g.clamp(0.0, 1.0);
            final double shown = _shown.value;
            final double rise = _shown.status == AnimationStatus.reverse
                ? Curves.easeIn.transform(1 - shown)
                : 1 - const Cubic(0.3, 1.4, 0.5, 1).transform(shown);
            final double height = math.max(
              _peekHeight * 0.6,
              lerpDouble(_peekHeight, fullHeight, g)!,
            );
            final double side = lerpDouble(AppSpacing.lg, 0, k)!;
            final double bottom = lerpDouble(gap, 0, k)!;
            final double top = lerpDouble(20, AppRadii.sheet, k)!;
            final double foot = lerpDouble(20, 0, k)!;
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: k < 0.05,
                    child: GestureDetector(
                      onTap: () => _settle(0),
                      child: ColoredBox(
                        color: AppColors.ink.withValues(
                          alpha: 0.32 * k * shown,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: side,
                  right: side,
                  bottom: bottom,
                  height: height,
                  child: Transform.translate(
                    offset: Offset(0, rise * (height + bottom + 24)),
                    child: Opacity(
                      opacity: shown.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(top),
                            bottom: Radius.circular(foot),
                          ),
                          boxShadow: AppShadows.float,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(top),
                            bottom: Radius.circular(foot),
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: _content(place, safe.bottom),
        );
      },
    );
  }

  Widget _content(Place place, double systemBottom) {
    return Semantics(
      container: true,
      label: 'Show more about ${place.name}',
      onTap: () => _settle(1),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_grow.value < 0.5) _settle(1);
        },
        onVerticalDragStart: _dragStart,
        onVerticalDragUpdate: _drag,
        onVerticalDragEnd: _release,
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // The handle says the card can be pulled.
                SizedBox(
                  height: 26,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.handle,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: AnimatedBuilder(
                      animation: _grow,
                      builder: (BuildContext context, Widget? child) =>
                          SingleChildScrollView(
                            controller: _scroll,
                            // Only the full sheet scrolls; the card's drags
                            // move the card.
                            physics: _grow.value >= 0.999 || _contentDrag
                                ? const ClampingScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              0,
                              AppSpacing.lg,
                              AppSpacing.lg + systemBottom,
                            ),
                            child: child,
                          ),
                      child: AnimatedSwitcher(
                        duration: AppMotion.short,
                        layoutBuilder:
                            (Widget? current, List<Widget> previous) => Stack(
                              alignment: Alignment.topCenter,
                              children: <Widget>[...previous, ?current],
                            ),
                        child: Column(
                          key: ValueKey<String>(place.id),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _ReportSize(
                              onSize: _measured,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  PlaceSummary(
                                    place: place,
                                    won: widget.won,
                                    compact: true,
                                    // Room for Close at the top right.
                                    nameEndGap: 40,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  PlaceActions(
                                    place: place,
                                    onSeeOnMap: widget.onSeeOnMap,
                                    onSpinAgain: widget.onSpinAgain,
                                  ),
                                ],
                              ),
                            ),
                            PlaceReviews(place: place),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.xs,
              child: IconButton(
                onPressed: _close,
                tooltip: 'Close',
                icon: const Icon(CupertinoIcons.xmark, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tells [onSize] its child's size after each layout.
class _ReportSize extends SingleChildRenderObjectWidget {
  const _ReportSize({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportSize(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderReportSize render) {
    render.onSize = onSize;
  }
}

class _RenderReportSize extends RenderProxyBox {
  _RenderReportSize(this.onSize);

  ValueChanged<Size> onSize;

  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
  }
}
