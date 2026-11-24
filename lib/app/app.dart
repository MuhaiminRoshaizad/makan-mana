import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'handle_every_back.dart';
import 'opening/opening_overlay.dart';
import 'router.dart';

class MakanManaApp extends ConsumerWidget {
  const MakanManaApp({super.key, this.opening = false});

  /// Plays the opening over the first screen; on when the app starts cold.
  final bool opening;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Makan Mana',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
      onNavigationNotification: handleEveryBack,
      builder: (BuildContext context, Widget? child) => HandleEveryBack(
        child: OpeningOverlay(
          enabled: opening,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
