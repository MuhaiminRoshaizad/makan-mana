import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_tokens.dart';
import '../core/widgets/nav_cover.dart';
import '../features/places/presentation/places_providers.dart';
import 'floating_nav.dart';
import 'tab_root.dart';

/// Hosts the two tabs with the floating bar over them. Pages and sheets
/// open on the root navigator, above all of this, so the bar never covers
/// them.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(WidgetRef ref, int i) {
    // A tab change ends a "press back again" that was waiting.
    ref.read(backToCloseProvider).disarm();
    shell.goBranch(i, initialLocation: i == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // See it on the map, from the wheel's result, opens the Map tab.
    ref.listen<String?>(aloneOnMapProvider, (String? _, String? now) {
      if (now != null && shell.currentIndex != 1) _select(ref, 1);
    });
    return Scaffold(
      // The keyboard covers the bar, as on iOS, instead of lifting it.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: shell),
          Positioned(
            left: 0,
            right: 0,
            bottom:
                MediaQuery.paddingOf(context).bottom + AppNavMetrics.bottomGap,
            // A place card growing into its sheet pushes the bar away.
            child: ValueListenableBuilder<double>(
              valueListenable: ref.watch(navCoverProvider),
              builder: (BuildContext context, double cover, Widget? bar) =>
                  IgnorePointer(
                    ignoring: cover > 0.5,
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        cover *
                            (AppNavMetrics.height +
                                AppNavMetrics.bottomGap +
                                MediaQuery.paddingOf(context).bottom +
                                AppSpacing.lg),
                      ),
                      child: bar,
                    ),
                  ),
              child: Center(
                child: FloatingNav(
                  index: shell.currentIndex,
                  onSelect: (int i) => _select(ref, i),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Switches tabs instantly, as iOS does (docs/decisions.md 010). Inactive
/// tabs stay mounted with their tickers paused, so each keeps its state.
class TabBranches extends StatelessWidget {
  const TabBranches({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        for (int i = 0; i < children.length; i++)
          Positioned.fill(
            child: Offstage(
              offstage: i != index,
              child: TickerMode(enabled: i == index, child: children[i]),
            ),
          ),
      ],
    );
  }
}
