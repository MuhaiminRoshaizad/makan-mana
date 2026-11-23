import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../places/domain/place.dart';
import '../../places/presentation/places_providers.dart';
import 'spin_wheel.dart';

/// The Spin tab: how many places made it onto the wheel, the one under the
/// arrow in large type, and the wheel.
class SpinScreen extends ConsumerStatefulWidget {
  const SpinScreen({super.key});

  @override
  ConsumerState<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends ConsumerState<SpinScreen> {
  int? _current;
  bool _spunOnce = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Place>> places = ref.watch(wheelPlacesProvider);
    final double clearance = AppNavMetrics.clearance(
      MediaQuery.paddingOf(context).bottom,
    );
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          clearance,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Makan Mana', style: _Type.title(context)),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: switch (places) {
                AsyncData<List<Place>>(value: final List<Place> list)
                    when list.isEmpty =>
                  const _Message(
                    title: 'Nothing nearby passes these filters',
                    body:
                        'Lower the rating or the number of reviews to bring '
                        'some places back.',
                  ),
                AsyncData<List<Place>>(value: final List<Place> list) => _live(
                  list,
                ),
                AsyncError<List<Place>>(:final Object error) => _failed(error),
                _ => const _Loading(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _live(List<Place> list) {
    final List<String> names = <String>[for (final Place p in list) p.name];
    final int? at = _current;
    final String current = at != null && at < names.length ? names[at] : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          list.length == 1
              ? '1 place on the wheel'
              : '${list.length} places on the wheel',
          textAlign: TextAlign.center,
          style: _Type.count(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          current,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _Type.readout(context),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final double diameter = _diameter(context, c);
              return Column(
                children: <Widget>[
                  const SizedBox(height: _wheelGap),
                  SpinWheel(
                    names: names,
                    diameter: diameter,
                    onCurrent: (int i) => setState(() => _current = i),
                    onSpinning: (bool on) {
                      if (on && !_spunOnce) setState(() => _spunOnce = true);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedOpacity(
                    opacity: _spunOnce ? 0 : 1,
                    duration: AppMotion.long,
                    child: Text(
                      'Throw the wheel, or tap Spin',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textScaler: MediaQuery.textScalerOf(
                        context,
                      ).clamp(maxScaleFactor: _hintMaxScale),
                      style: _Type.hint(context),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _failed(Object error) {
    if (error is PlacesUnavailable) {
      return const _Message(
        title: 'Finding places is not set up yet',
        body:
            'This build cannot search Google for places. Run the demo build '
            'to try the wheel with sample places.',
      );
    }
    return _Message(
      title: "Couldn't find places nearby",
      body: 'Check your connection, then try again.',
      action: 'Try again',
      onAction: () => ref.invalidate(nearbyPlacesProvider),
    );
  }
}

/// Space between the name above the wheel and the top of the arrow.
const double _wheelGap = AppSpacing.lg;

/// The hint keeps to two lines and grows with system text only so far.
const double _hintMaxScale = 1.6;
const double _hintSize = 14;
const double _hintLineHeight = 1.35;

/// The wheel's size: as wide as the screen allows, as tall as leaves room
/// for the arrow and two lines of hint at the current text size, and no
/// larger than 420.
double _diameter(BuildContext context, BoxConstraints c) {
  final double line =
      MediaQuery.textScalerOf(
        context,
      ).clamp(maxScaleFactor: _hintMaxScale).scale(_hintSize) *
      _hintLineHeight;
  final double hintRoom = AppSpacing.lg + 2 * line;
  return math.max(
    120,
    math.min(
      420,
      math.min(
        c.maxWidth,
        c.maxHeight - _wheelGap - SpinWheel.arrowRoom - hintRoom,
      ),
    ),
  );
}

abstract final class _Type {
  static TextStyle title(BuildContext context) => const TextStyle(
    fontSize: 34,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.ink,
  );

  static TextStyle count(BuildContext context) => const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );

  static TextStyle readout(BuildContext context) => const TextStyle(
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );

  static TextStyle hint(BuildContext context) => const TextStyle(
    fontSize: _hintSize,
    height: _hintLineHeight,
    color: AppColors.muted,
  );
}

/// Nothing for the first 300 ms, since a quick answer needs no placeholder,
/// then a skeleton of the count, the name and the wheel in their places.
class _Loading extends StatefulWidget {
  const _Loading();

  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading> {
  late final Timer _wait = Timer(
    const Duration(milliseconds: 300),
    () => setState(() => _show = true),
  );
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _wait;
  }

  @override
  void dispose() {
    _wait.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.expand();
    return Semantics(
      label: 'Finding places nearby',
      child: Column(
        children: <Widget>[
          const _Bone(width: 150, height: 14),
          const SizedBox(height: AppSpacing.sm),
          const _Bone(width: 210, height: 28),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final double d = _diameter(context, c);
                return Column(
                  children: <Widget>[
                    const SizedBox(height: _wheelGap + SpinWheel.arrowRoom),
                    _Bone(width: d, height: d, round: true),
                    const SizedBox(height: AppSpacing.lg + 18),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({required this.width, required this.height, this.round = false});

  final double width;
  final double height;
  final bool round;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.fill,
      shape: round ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: round ? null : BorderRadius.circular(AppRadii.sm),
    ),
  );
}

/// A centred title, a line of help and an optional action, for when there
/// is no wheel to show.
class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                height: 1.25,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                height: 1.45,
                color: AppColors.muted,
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xxl),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
