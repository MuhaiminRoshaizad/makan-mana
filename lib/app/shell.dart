import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_tokens.dart';
import 'floating_nav.dart';

/// Hosts the two tabs with the floating bar over them. Pages and sheets
/// open on the root navigator, above all of this, so the bar never covers
/// them.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
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
            child: Center(
              child: FloatingNav(index: shell.currentIndex, onSelect: _select),
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
