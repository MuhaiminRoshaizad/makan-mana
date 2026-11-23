import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'handle_every_back.dart';
import 'router.dart';

class MakanManaApp extends ConsumerWidget {
  const MakanManaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Makan Mana',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
      onNavigationNotification: handleEveryBack,
      builder: (BuildContext context, Widget? child) =>
          HandleEveryBack(child: child ?? const SizedBox.shrink()),
    );
  }
}
