import 'package:flutter/material.dart';

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
    builder: (BuildContext sheetContext) =>
        SafeArea(top: false, child: Builder(builder: builder)),
  );
}
