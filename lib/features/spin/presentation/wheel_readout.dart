import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Above the wheel: how many places are on it, the name of the one under
/// the arrow, and that place's rating and distance. The count and the
/// rating line never move; the name has three lines' room between them and
/// gets smaller rather than push either line, so nothing jumps as the
/// wheel turns (docs/decisions.md 021). The block sits in the middle of the
/// space it is given.
class WheelReadout extends StatelessWidget {
  const WheelReadout({
    super.key,
    required this.count,
    required this.name,
    required this.detail,
    this.align = TextAlign.center,
  });

  final String count;
  final String name;
  final String detail;
  final TextAlign align;

  /// The small lines grow with system text only so far, like other fixed
  /// chrome, so they always keep to one line.
  static const double _smallMaxScale = 1.6;
  static const double _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final TextScaler small = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: _smallMaxScale);
    final double lineRoom = small.scale(_Type.smallSize) * _Type.smallHeight;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double nameRoom = FittedName.threeLines(context);
        final double block = math.min(
          c.maxHeight,
          2 * lineRoom + 2 * _gap + nameRoom,
        );
        final CrossAxisAlignment cross = align == TextAlign.center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start;
        return Center(
          child: SizedBox(
            height: block,
            width: c.maxWidth,
            child: Column(
              crossAxisAlignment: cross,
              children: <Widget>[
                _line(count, small, lineRoom),
                const SizedBox(height: _gap),
                Expanded(
                  child: FittedName(name: name, align: align),
                ),
                const SizedBox(height: _gap),
                _line(detail, small, lineRoom),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _line(String text, TextScaler scaler, double room) => SizedBox(
    height: room,
    child: Text(
      text,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textScaler: scaler,
      style: _Type.small,
    ),
  );
}

/// A name that fills the room it is given: as large as [maxSize] while it
/// fits, smaller down to [minSize] when it does not, and only past that cut
/// with an ellipsis. It sits in the middle of its room, so a name that
/// wraps grows both ways.
class FittedName extends StatefulWidget {
  const FittedName({super.key, required this.name, required this.align});

  final String name;
  final TextAlign align;

  static const double maxSize = 36;
  static const double minSize = 22;
  static const double lineHeight = 1.1;

  /// The room three lines take at full size and the current text size.
  static double threeLines(BuildContext context) =>
      3 * MediaQuery.textScalerOf(context).scale(maxSize) * lineHeight;

  @override
  State<FittedName> createState() => _FittedNameState();
}

class _FittedNameState extends State<FittedName> {
  /// Sizes already worked out for this room, by name, since the wheel
  /// shows the same few names over and over while it spins.
  final Map<String, ({double size, int? lines})> _fits =
      <String, ({double size, int? lines})>{};
  Object? _room;

  ({double size, int? lines}) _fit(
    BoxConstraints c,
    TextStyle base,
    TextScaler scaler,
  ) {
    final Object room = (c.maxWidth, c.maxHeight, scaler, base);
    if (room != _room) {
      _fits.clear();
      _room = room;
    }
    return _fits.putIfAbsent(widget.name, () {
      for (
        double size = FittedName.maxSize;
        size >= FittedName.minSize;
        size -= 1
      ) {
        final TextPainter tp = TextPainter(
          text: TextSpan(text: widget.name, style: _style(base, size)),
          textScaler: scaler,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: c.maxWidth);
        final bool fits = tp.height <= c.maxHeight;
        tp.dispose();
        if (fits) return (size: size, lines: null);
      }
      final double line =
          scaler.scale(FittedName.minSize) * FittedName.lineHeight;
      return (
        size: FittedName.minSize,
        lines: math.max(1, (c.maxHeight / line).floor()),
      );
    });
  }

  TextStyle _style(TextStyle base, double size) => base.merge(
    TextStyle(
      fontSize: size,
      height: FittedName.lineHeight,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: AppColors.ink,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final TextStyle base = DefaultTextStyle.of(context).style;
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final ({double size, int? lines}) fit = _fit(c, base, scaler);
        return Align(
          alignment: widget.align == TextAlign.center
              ? Alignment.center
              : Alignment.centerLeft,
          child: Text(
            widget.name,
            textAlign: widget.align,
            maxLines: fit.lines,
            overflow: fit.lines == null ? null : TextOverflow.ellipsis,
            style: _style(base, fit.size),
          ),
        );
      },
    );
  }
}

abstract final class _Type {
  static const double smallSize = 15;
  static const double smallHeight = 1.35;

  static const TextStyle small = TextStyle(
    fontSize: smallSize,
    height: smallHeight,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );
}
