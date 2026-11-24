import 'dart:ui' show Color;

import 'app_tokens.dart';

/// One wedge's fill and the label colour that reads on it.
class WedgeColor {
  const WedgeColor(this.fill, this.label);
  final Color fill;
  final Color label;
}

/// The seven wedge colours, warm to cool: tomato, orange, mustard, leaf
/// green, sky, blue and berry (docs/decisions.md 013). Labels are surface
/// white on the dark four and ink on the light three, all 4.5:1 or better.
const List<WedgeColor> wedgeColors = <WedgeColor>[
  WedgeColor(Color(0xFFC8452A), AppColors.surface),
  WedgeColor(Color(0xFFE07B1F), AppColors.ink),
  WedgeColor(Color(0xFFF0B83C), AppColors.ink),
  WedgeColor(Color(0xFF357A40), AppColors.surface),
  WedgeColor(Color(0xFF8EC3E8), AppColors.ink),
  WedgeColor(Color(0xFF2F6FC9), AppColors.surface),
  WedgeColor(Color(0xFFB23A6B), AppColors.surface),
];

/// The colour of wedge [i] of [n]. When the colours would wrap round so the
/// last wedge matches the first beside it, the last takes green instead.
WedgeColor wedgeColorFor(int i, int n) {
  if (i == n - 1 && n % wedgeColors.length == 1 && n > 1) return wedgeColors[3];
  return wedgeColors[i % wedgeColors.length];
}
