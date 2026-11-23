import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../core/theme/app_tokens.dart';

class NavDestination {
  const NavDestination(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// The two tabs, in branch order.
const List<NavDestination> navDestinations = <NavDestination>[
  NavDestination(CupertinoIcons.chart_pie, 'Spin'),
  NavDestination(CupertinoIcons.map, 'Map'),
];

/// The capsule that floats over the content (docs/decisions.md 010). The
/// open tab sits on an ink thumb that springs across when another tab is
/// chosen; each tab keeps one glyph and shows its state by colour.
class FloatingNav extends StatefulWidget {
  const FloatingNav({super.key, required this.index, required this.onSelect});

  /// The open tab, as an index into [navDestinations].
  final int index;

  final ValueChanged<int> onSelect;

  @override
  State<FloatingNav> createState() => _FloatingNavState();
}

class _FloatingNavState extends State<FloatingNav>
    with SingleTickerProviderStateMixin {
  /// Where the thumb is, in tabs from the left.
  late final AnimationController _at = AnimationController.unbounded(
    vsync: this,
    value: widget.index.toDouble(),
  );

  @override
  void didUpdateWidget(FloatingNav old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    final double to = widget.index.toDouble();
    if (MediaQuery.disableAnimationsOf(context)) {
      _at.value = to;
    } else {
      _at.animateWith(
        SpringSimulation(
          AppMotion.spring,
          _at.value,
          to,
          _at.velocity,
          snapToEnd: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _at.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(color: Color(0x0F26241F), width: 1),
        ),
        shadows: <BoxShadow>[
          BoxShadow(
            color: Color(0x2E26241F),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppNavMetrics.inset),
        child: SizedBox(
          width: AppNavMetrics.tabWidth * navDestinations.length,
          height: AppNavMetrics.tabHeight,
          child: Stack(
            children: <Widget>[
              AnimatedBuilder(
                animation: _at,
                builder: (BuildContext context, Widget? thumb) => Positioned(
                  left: thumbLeft(_at.value, navDestinations.length),
                  top: 0,
                  width: AppNavMetrics.tabWidth,
                  height: AppNavMetrics.tabHeight,
                  child: thumb!,
                ),
                child: const DecoratedBox(
                  decoration: ShapeDecoration(
                    color: AppColors.ink,
                    shape: StadiumBorder(),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  for (int i = 0; i < navDestinations.length; i++)
                    _NavItem(
                      destination: navDestinations[i],
                      // Colour follows the thumb, so a label turns light as
                      // the thumb arrives under it rather than before.
                      lit: _at,
                      slot: i,
                      selected: i == widget.index,
                      onTap: () => widget.onSelect(i),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Left edge of the thumb [at] tabs from the left. The spring's overshoot
/// is kept inside the capsule rather than carrying the thumb out of it.
double thumbLeft(double at, int tabs) =>
    at.clamp(0.0, tabs - 1.0) * AppNavMetrics.tabWidth;

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.lit,
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final Animation<double> lit;
  final int slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: AppNavMetrics.tabWidth,
          height: AppNavMetrics.tabHeight,
          child: AnimatedBuilder(
            animation: lit,
            builder: (BuildContext context, _) {
              // 1 with the thumb fully under this tab, 0 a tab away.
              final double under = (1 - (lit.value - slot).abs()).clamp(
                0.0,
                1.0,
              );
              final Color color = Color.lerp(
                AppColors.muted,
                AppColors.surface,
                under,
              )!;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(destination.icon, size: AppIconSize.dense, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: MediaQuery.textScalerOf(
                        context,
                      ).clamp(maxScaleFactor: 1.15),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
