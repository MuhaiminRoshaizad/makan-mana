import 'package:flutter/widgets.dart';

/// Lets something on a tab take Back before the tab does, such as a place
/// card that collapses or closes. The tab's own guard asks it first.
///
/// A second PopScope inside the tab would not do: every PopScope on a route
/// hears the same Back, so the tab would also switch or ask to close.
class TabBack {
  bool Function()? _handler;

  /// While [handler] is set, it gets each Back first; it returns true when
  /// it used it.
  void claim(bool Function() handler) => _handler = handler;

  void release(bool Function() handler) {
    if (identical(_handler, handler)) _handler = null;
  }

  bool handle() => _handler?.call() ?? false;
}

class TabBackScope extends InheritedWidget {
  const TabBackScope({super.key, required this.back, required super.child});

  final TabBack back;

  static TabBack? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TabBackScope>()?.back;

  @override
  bool updateShouldNotify(TabBackScope oldWidget) => back != oldWidget.back;
}
