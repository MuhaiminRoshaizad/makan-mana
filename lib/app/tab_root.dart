import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/tab_back.dart';
import '../core/widgets/toast.dart';

/// Wraps each tab's first page, so Back there follows Android's rule for
/// bottom tabs: Map goes back to Spin, and only Spin leaves the app, after
/// a "press back again" hint so a stray swipe doesn't close it mid-decision
/// (docs/decisions.md 012).
///
/// It sits on the tab's page, not on the shell around the tabs: on Android
/// 14 and later each tab's navigator tells Android for itself whether it
/// handles Back, and a guard on the shell is outvoted.
class TabRoot extends ConsumerStatefulWidget {
  const TabRoot({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TabRoot> createState() => _TabRootState();
}

class _TabRootState extends ConsumerState<TabRoot> {
  /// Something on the tab, such as a place card, may take Back first.
  final TabBack _back = TabBack();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop || _back.handle()) return;
        final StatefulNavigationShellState? shell =
            StatefulNavigationShell.maybeOf(context);
        if (shell == null) return;
        ref
            .read(backToCloseProvider)
            .back(context, current: shell.currentIndex, goTo: shell.goBranch);
      },
      child: TabBackScope(back: _back, child: widget.child),
    );
  }
}

/// Whether Back has just asked to be pressed again. It is armed exactly
/// while that hint shows: the hint's own leaving, for any reason, disarms
/// it, so a Back after it has gone asks again.
class BackToClose {
  /// How long the hint shows, and so how long a second Back closes the app:
  /// Android's short toast.
  static const Duration window = Duration(seconds: 2);

  static const String hint = 'Press back again to close Makan Mana';

  bool _armed = false;

  void back(
    BuildContext context, {
    required int current,
    required ValueChanged<int> goTo,
  }) {
    if (current != 0) {
      disarm();
      goTo(0);
      return;
    }
    if (_armed) {
      _armed = false;
      SystemNavigator.pop();
      return;
    }
    _armed = true;
    // Plain: a tick would read as if something had been done.
    showToast(
      context,
      hint,
      plain: true,
      duration: window,
      countdown: true,
      onHidden: () => _armed = false,
    );
  }

  /// Takes the hint down if it is showing, as when the other tab is opened.
  void disarm() {
    if (!_armed) return;
    hideToast();
    _armed = false;
  }
}

final Provider<BackToClose> backToCloseProvider = Provider<BackToClose>(
  (Ref ref) => BackToClose(),
);
