import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoPageTransitionsBuilder, CupertinoThemeData;
import 'package:flutter/material.dart';

import '../widgets/glide_back_physics.dart';
import 'app_tokens.dart';

const String _font = 'PlusJakartaSans';

/// The one theme: light only (docs/decisions.md 006), iOS in behaviour on
/// both platforms (009).
ThemeData buildAppTheme() {
  final ColorScheme scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.ink,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.ink,
        onPrimary: AppColors.surface,
        surface: AppColors.background,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.muted,
        surfaceContainerLowest: AppColors.surface,
        surfaceContainerLow: AppColors.surface,
        surfaceContainer: AppColors.fill,
        outline: AppColors.line,
        outlineVariant: AppColors.line,
      );

  const TextStyle buttonText = TextStyle(
    fontFamily: _font,
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: _font,
    scaffoldBackgroundColor: AppColors.background,
    cupertinoOverrideTheme: const CupertinoThemeData(
      primaryColor: AppColors.ink,
      scaffoldBackgroundColor: AppColors.background,
    ),
    // iOS dims what you press; it never ripples.
    splashFactory: NoSplash.splashFactory,
    highlightColor: AppColors.ink.withValues(alpha: 0.06),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (BuildContext context) =>
          const Icon(CupertinoIcons.chevron_back),
    ),
    // Pages slide in from the side with the old page drifting behind.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: _font,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
    // A filled ink pill for the main action, a grey pill for the second.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.surface,
        shape: const StadiumBorder(),
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.fill,
        foregroundColor: AppColors.ink,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleSize: Size(36, 5),
      dragHandleColor: AppColors.handle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
  );
}

/// Rubber-band scrolling everywhere, as on iOS, with no Android stretch or
/// glow at the ends.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const GlideBackPhysics(parent: RangeMaintainingScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
