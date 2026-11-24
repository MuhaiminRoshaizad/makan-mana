import 'package:flutter/services.dart';

/// The status and navigation bars over the app's light screens: drawn
/// behind the bars, with dark icons.
const SystemUiOverlayStyle appSystemStyle = SystemUiOverlayStyle(
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Color(0x00000000),
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

/// The same over the ink opening: light icons.
final SystemUiOverlayStyle openingSystemStyle = appSystemStyle.copyWith(
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarIconBrightness: Brightness.light,
);
