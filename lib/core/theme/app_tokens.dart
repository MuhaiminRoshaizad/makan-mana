import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart' show BoxShadow, Offset;

/// The app's colours. Everything outside the wheel is ink on soft white, so
/// the wheel's wedges are the only colour on screen (docs/decisions.md 013).
abstract final class AppColors {
  /// The screen behind everything.
  static const Color background = Color(0xFFF6F6F3);

  /// Cards, sheets, the tab bar and outlined buttons.
  static const Color surface = Color(0xFFFDFDFB);

  /// Text, icons and filled buttons.
  static const Color ink = Color(0xFF26241F);

  /// Secondary text and inactive tabs: 5.2:1 on [background]. Under 4.5:1
  /// on [fill], so never put it there.
  static const Color muted = Color(0xFF6B675F);

  /// Hairline borders and dividers.
  static const Color line = Color(0xFFE3E1DC);

  /// Quiet buttons and tracks.
  static const Color fill = Color(0xFFE6E4DF);

  /// The sheet handle.
  static const Color handle = Color(0xFFD6D3CC);
}

/// Spacing on a 4pt scale. Widgets use these, never ad-hoc numbers.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Actions are pills, cards 16 and sheets 28.
abstract final class AppRadii {
  static const double sm = 10;
  static const double card = 16;
  static const double sheet = 28;
  static const double pill = 999;
}

/// The one shadow for controls that float over the map or the wheel.
abstract final class AppShadows {
  static const List<BoxShadow> float = <BoxShadow>[
    BoxShadow(color: Color(0x2926241F), blurRadius: 8, offset: Offset(0, 2)),
  ];
}

abstract final class AppIconSize {
  static const double dense = 20;
  static const double standard = 24;
}

/// One rhythm for every animation in the app.
abstract final class AppMotion {
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration long = Duration(milliseconds: 400);

  /// A strong ease-out for anything arriving.
  static const Curve enter = Cubic(0.23, 1, 0.32, 1);

  /// A quick ease-in for anything leaving.
  static const Curve exit = Cubic(0.4, 0, 1, 1);

  /// For things that follow a finger or a tab change: slightly
  /// under-damped, so they pass their target a little and settle.
  static final SpringDescription spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 180,
    ratio: 0.6,
  );
}

/// Geometry of the floating tab bar, shared by everything that must clear
/// it.
abstract final class AppNavMetrics {
  /// One tab, and the dark thumb behind the open one.
  static const double tabWidth = 104;
  static const double tabHeight = 48;

  /// Room between the tabs and the bar's edge.
  static const double inset = 6;

  static const double height = tabHeight + inset * 2;

  /// Gap between the bar and the system navigation bar.
  static const double bottomGap = 12;

  /// Space a page under the bar leaves below its last row, so the row
  /// ends above the bar and the system navigation bar.
  static double clearance(double systemBottomInset) =>
      height + bottomGap + systemBottomInset + AppSpacing.lg;
}
