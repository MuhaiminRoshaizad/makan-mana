import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'glide_back_physics.dart';

/// The only way the app opens a bottom sheet.
///
/// It opens on the root navigator, above the floating tab bar, which would
/// otherwise cover a sheet opened from inside a tab. The sheet is drawn here
/// rather than by `showModalBottomSheet`, whose surface ignores a drag on
/// content that scrolls and whose backdrop cannot follow one: pulled from
/// the handle or from content at its top, the whole sheet follows the
/// finger and the backdrop lightens with it, as the shop card does.
///
/// The sheet's colour runs behind the system navigation bar while its last
/// button ends above it. A sheet is as tall as its content, capped at 9/16
/// of the screen unless [scrollControlled], and then just below the status
/// bar.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollControlled = false,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    _AppSheetRoute<T>(builder: builder, scrollControlled: scrollControlled),
  );
}

@visibleForTesting
const Key appSheetScrimKey = ValueKey<String>('app-sheet-scrim');

class _AppSheetRoute<T> extends PopupRoute<T> {
  _AppSheetRoute({required this.builder, required this.scrollControlled});

  final WidgetBuilder builder;
  final bool scrollControlled;

  // The backdrop is drawn by the sheet so it can follow a drag; this
  // barrier stays clear and only takes the tap that closes the sheet.
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Close';

  @override
  Duration get transitionDuration => AppMotion.long;

  @override
  Duration get reverseTransitionDuration => AppMotion.medium;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _Sheet(
    route: this,
    child: Builder(builder: builder),
  );
}

class _Sheet extends StatefulWidget {
  const _Sheet({required this.route, required this.child});

  final _AppSheetRoute<dynamic> route;
  final Widget child;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> with SingleTickerProviderStateMixin {
  /// How far the sheet has been pulled down, in logical pixels.
  late final AnimationController _down = AnimationController.unbounded(
    vsync: this,
  );
  late final Animation<double> _open = CurvedAnimation(
    parent: widget.route.animation!,
    curve: AppMotion.enter,
    reverseCurve: AppMotion.exit,
  );
  final GlobalKey _surface = GlobalKey();

  /// The sheet's height, read when a drag starts; the backdrop fades and
  /// the close point is set against it.
  double _height = 1;
  bool _scrollDrag = false;
  bool _closing = false;

  /// A flick this fast settles the sheet whichever way it goes.
  static const double _flick = 900;

  @override
  void dispose() {
    _down.dispose();
    super.dispose();
  }

  void _start() {
    if (_closing) return;
    _down.stop();
    _height = math.max(1, _surface.currentContext?.size?.height ?? 1);
  }

  void _move(double dy) {
    if (_closing) return;
    _down.value = math.max(0, _down.value + dy);
  }

  /// Let go: a quarter of the way down or a flick down closes it, carrying
  /// the flick on; anything else springs it back up.
  void _release(double velocity) {
    if (_closing) return;
    final bool closes =
        velocity > _flick || (velocity > -_flick && _down.value > _height / 4);
    final bool still = MediaQuery.disableAnimationsOf(context);
    if (!closes) {
      if (_down.value <= 0) return;
      if (still) {
        _down.value = 0;
      } else {
        _down.animateWith(
          SpringSimulation(AppMotion.spring, _down.value, 0, velocity),
        );
      }
      return;
    }
    _closing = true;
    final NavigatorState navigator = Navigator.of(context);
    if (still) {
      navigator.pop();
      return;
    }
    _down
        .animateWith(
          GravitySimulation(
            2600,
            _down.value,
            _height,
            math.max(velocity, 1200),
          ),
        )
        .whenComplete(() {
          // Back may already have closed it while it fell.
          if (widget.route.isCurrent) navigator.pop();
        });
  }

  /// A pull on content that scrolls arrives as overscroll at its top.
  bool _onScroll(ScrollNotification n) {
    if (_closing || n.metrics.axis != Axis.vertical) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _scrollDrag = true;
      _start();
    } else if (n is OverscrollNotification && _scrollDrag && n.overscroll < 0) {
      _move(-n.overscroll);
    } else if (n is ScrollUpdateNotification &&
        _scrollDrag &&
        _down.value > 0 &&
        (n.scrollDelta ?? 0) > 0) {
      // Pushed back up: the sheet rises before the content scrolls.
      _move(-n.scrollDelta!);
      Scrollable.maybeOf(
        n.context!,
      )?.position.jumpTo(n.metrics.minScrollExtent);
    } else if (n is ScrollEndNotification && _scrollDrag) {
      _scrollDrag = false;
      _release(n.dragDetails?.primaryVelocity ?? 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints c) {
      final double screen = c.maxHeight;
      return _build(
        widget.route.scrollControlled
            ? screen - MediaQuery.paddingOf(context).top - AppSpacing.sm
            : screen * 9 / 16,
      );
    },
  );

  Widget _build(double tallest) {
    final Widget sheet = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: tallest),
      child: Material(
        key: _surface,
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
        // The handle and any part that does not scroll; content that
        // scrolls wins its own drag and reports through _onScroll.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (_) => _start(),
          onVerticalDragUpdate: (DragUpdateDetails d) => _move(d.delta.dy),
          onVerticalDragEnd: (DragEndDetails d) =>
              _release(d.primaryVelocity ?? 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _Handle(),
              Flexible(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: ScrollConfiguration(
                    behavior: const _SheetScrollBehavior(),
                    child: SafeArea(top: false, child: widget.child),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_open, _down]),
      builder: (BuildContext context, Widget? child) {
        final double down = math.max(0, _down.value);
        final double left = (1 - down / _height).clamp(0.0, 1.0);
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  key: appSheetScrimKey,
                  color: AppColors.ink.withValues(
                    alpha: 0.32 * _open.value * left,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionalTranslation(
                translation: Offset(0, 1 - _open.value),
                child: Transform.translate(
                  offset: Offset(0, down),
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      child: sheet,
    );
  }
}

/// The grab handle. Its whole 48 dp strip drags the sheet, and screen
/// readers get it as a button that closes the sheet.
class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      onTap: () => Navigator.of(context).pop(),
      child: const SizedBox(
        height: 48,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.handle,
              borderRadius: BorderRadius.all(Radius.circular(2.5)),
            ),
            child: SizedBox(width: 36, height: 5),
          ),
        ),
      ),
    );
  }
}

class _SheetScrollBehavior extends AppScrollBehavior {
  const _SheetScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const _StopAtTopPhysics(parent: RangeMaintainingScrollPhysics());
}

/// The app's bounce, except at the top edge, where the content stops and
/// reports the rest of the pull as overscroll for the sheet to take.
class _StopAtTopPhysics extends GlideBackPhysics {
  const _StopAtTopPhysics({super.parent});

  @override
  _StopAtTopPhysics applyTo(ScrollPhysics? ancestor) =>
      _StopAtTopPhysics(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final double min = position.minScrollExtent;
    if (value < position.pixels && position.pixels <= min) {
      return value - position.pixels;
    }
    if (position.pixels > min && value < min) return value - min;
    return super.applyBoundaryConditions(position, value);
  }
}
