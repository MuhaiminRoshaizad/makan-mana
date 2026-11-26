import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'glide_back_physics.dart';

/// The only way the app opens a bottom sheet.
///
/// It opens on the root navigator, above the floating tab bar, which would
/// otherwise cover a sheet opened from inside a tab. `showModalBottomSheet`
/// also draws under the system navigation bar, and its `useSafeArea` guards
/// only the top and sides, so the content gets a bottom-only [SafeArea]:
/// the sheet's colour runs behind the bar while its last button ends above
/// it. A sheet is capped at 9/16 of the screen unless [scrollControlled].
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: scrollControlled,
    builder: (BuildContext sheetContext) => _PullToClose(
      child: SafeArea(top: false, child: Builder(builder: builder)),
    ),
  );
}

/// Lets a pull down on a sheet's content close it once the content is at
/// its top, as the shop card does; Flutter's own sheet drag works only on
/// parts that do not scroll. The content keeps its bounce at the bottom but
/// stops at the top, so a pull there moves the sheet instead.
class _PullToClose extends StatefulWidget {
  const _PullToClose({required this.child});

  final Widget child;

  @override
  State<_PullToClose> createState() => _PullToCloseState();
}

class _PullToCloseState extends State<_PullToClose>
    with SingleTickerProviderStateMixin {
  /// How far the sheet has been pulled down, in logical pixels.
  late final AnimationController _down = AnimationController.unbounded(
    vsync: this,
  );
  bool _dragging = false;
  bool _closing = false;

  /// A pull this far, or a flick down this fast, closes the sheet.
  static const double _closesAt = 120;
  static const double _closesFaster = 700;

  @override
  void dispose() {
    _down.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (_closing) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _dragging = true;
      _down.stop();
    } else if (n is OverscrollNotification &&
        _dragging &&
        n.overscroll < 0 &&
        n.metrics.axis == Axis.vertical) {
      _down.value -= n.overscroll;
    } else if (n is ScrollUpdateNotification &&
        _dragging &&
        _down.value > 0 &&
        (n.scrollDelta ?? 0) > 0) {
      // Pushed back up: the sheet rises before the content scrolls.
      final double by = n.scrollDelta!;
      _down.value = math.max(0, _down.value - by);
      final ScrollMetrics m = n.metrics;
      Scrollable.maybeOf(n.context!)?.position.jumpTo(m.minScrollExtent);
    } else if (n is ScrollEndNotification && _dragging) {
      _dragging = false;
      final double v = n.dragDetails?.primaryVelocity ?? 0;
      if (_down.value > _closesAt || (_down.value > 0 && v > _closesFaster)) {
        _closing = true;
        Navigator.of(context).pop();
      } else if (_down.value > 0) {
        _down.animateWith(
          SpringSimulation(AppMotion.spring, _down.value, 0, 0),
        );
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ScrollConfiguration(
        behavior: const _SheetScrollBehavior(),
        child: AnimatedBuilder(
          animation: _down,
          builder: (BuildContext context, Widget? child) => Transform.translate(
            offset: Offset(0, math.max(0, _down.value)),
            child: child,
          ),
          child: widget.child,
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
