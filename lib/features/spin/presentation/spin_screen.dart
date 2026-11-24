import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/status_message.dart';
import '../../location/domain/location_repository.dart';
import '../../location/presentation/location_message.dart';
import '../../location/presentation/location_providers.dart';
import '../../places/domain/place.dart';
import '../../places/domain/place_filters.dart';
import '../../places/presentation/filters_button.dart';
import '../../places/presentation/filters_sheet.dart';
import '../../places/presentation/places_providers.dart';
import 'result_sheet.dart';
import 'spin_wheel.dart';

/// The Spin tab: how many places made it onto the wheel, the one under the
/// arrow in large type, and the wheel.
class SpinScreen extends ConsumerStatefulWidget {
  const SpinScreen({super.key});

  @override
  ConsumerState<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends ConsumerState<SpinScreen> {
  /// Coming back from Settings may have changed the answer: check again
  /// unless the wheel already knows where it is.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () {
      if (ref.read(locationProvider).value is! Located) {
        ref.read(locationProvider.notifier).recheck();
      }
    },
  );

  int? _current;
  bool _spunOnce = false;
  final GlobalKey<SpinWheelState> _wheel = GlobalKey<SpinWheelState>();

  /// The result waits while the winning wedge flashes.
  Timer? _result;

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _result?.cancel();
    super.dispose();
  }

  void _landed(Place place) {
    _result?.cancel();
    final Duration flash = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 650);
    _result = Timer(flash, () {
      if (!mounted) return;
      showResultSheet(
        context,
        place: place,
        onSpinAgain: () {
          Navigator.of(context, rootNavigator: true).pop();
          _wheel.currentState?.spin();
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Place>> places = ref.watch(wheelPlacesProvider);
    final double clearance = AppNavMetrics.clearance(
      MediaQuery.paddingOf(context).bottom,
    );
    // One button for the distance and every filter, since both open the
    // same sheet. The tab needs no title: the tab bar names it.
    final PlaceFilters filters = ref.watch(filtersProvider);
    final bool chosen = ref.watch(filtersChosenProvider);
    final String around = ref.watch(pinProvider) != null
        ? 'your pin'
        : demoMode
        ? 'Dataran Merdeka'
        : 'you';
    final Widget title = Align(
      alignment: Alignment.topLeft,
      child: FiltersButton(
        label: 'Within ${formatDistance(filters.maxDistanceMetres)} of $around',
      ),
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
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            // On its side the phone is too short for the text above the
            // wheel, so the two sit side by side (docs/decisions.md 016).
            final bool wide = c.maxWidth > c.maxHeight;
            // Until the filters are chosen the wheel waits, empty.
            if (!chosen && places is AsyncData<List<Place>>) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  title,
                  Expanded(
                    child: _ChooseFirst(
                      wide: wide,
                      onChoose: () => showFiltersSheet(context),
                    ),
                  ),
                ],
              );
            }
            if (places case AsyncData<List<Place>>(
              value: final List<Place> list,
            ) when list.isNotEmpty) {
              return wide ? _wideLive(title, list) : _tallLive(title, list);
            }
            if (places is! AsyncData<List<Place>> &&
                places is! AsyncError<List<Place>>) {
              return _Loading(title: title, wide: wide);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                title,
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: switch (places) {
                    AsyncData<List<Place>>() => StatusMessage(
                      title: 'Nothing nearby passes these filters',
                      body:
                          'Go further, or lower the rating or the number of '
                          'reviews, to bring some places back.',
                      action: 'Edit filters',
                      onAction: () => showFiltersSheet(context),
                    ),
                    AsyncError<List<Place>>(:final Object error) => _failed(
                      error,
                    ),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _countText(List<Place> list) => list.length == 1
      ? '1 place on the wheel'
      : '${list.length} places on the wheel';

  String _currentName(List<Place> list) {
    final int? at = _current;
    return at != null && at < list.length ? list[at].name : '';
  }

  Widget _wheelOf(List<Place> list, double diameter) => SpinWheel(
    key: _wheel,
    names: <String>[for (final Place p in list) p.name],
    diameter: diameter,
    onLanded: (int i) => _landed(list[i]),
    onCurrent: (int i) => setState(() => _current = i),
    onSpinning: (bool on) {
      if (on && !_spunOnce) setState(() => _spunOnce = true);
    },
  );

  Widget _hint(TextAlign align) => AnimatedOpacity(
    opacity: _spunOnce ? 0 : 1,
    duration: AppMotion.long,
    child: Text(
      'Throw the wheel, or tap Spin',
      textAlign: align,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textScaler: MediaQuery.textScalerOf(
        context,
      ).clamp(maxScaleFactor: _hintMaxScale),
      style: _Type.hint(context),
    ),
  );

  /// Upright: the title, the count and the name above the wheel.
  Widget _tallLive(Widget title, List<Place> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        title,
        const SizedBox(height: AppSpacing.md),
        Text(
          _countText(list),
          textAlign: TextAlign.center,
          style: _Type.count(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _currentName(list),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _Type.readout(context),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) => Column(
              children: <Widget>[
                const SizedBox(height: _wheelGap),
                _wheelOf(list, _diameter(context, c)),
                const SizedBox(height: AppSpacing.lg),
                // Takes only what is left, so rounding in the size budget
                // can never push it past the bottom.
                Flexible(child: _hint(TextAlign.center)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// On its side: the title, count, name and hint down the left, the wheel
  /// on the right, as tall as the screen allows.
  Widget _wideLive(Widget title, List<Place> list) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double diameter = _wideDiameter(c);
        return Row(
          // The text starts at the top, as it does upright.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    title,
                    const SizedBox(height: AppSpacing.md),
                    Text(_countText(list), style: _Type.count(context)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _currentName(list),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _Type.readout(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _hint(TextAlign.start),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xxl),
            Align(
              alignment: Alignment.bottomCenter,
              child: _wheelOf(list, diameter),
            ),
          ],
        );
      },
    );
  }

  Widget _failed(Object raw) {
    final Object error = rootCause(raw);
    if (error is NeedsLocation) {
      return LocationMessage(
        error.state,
        onChooseSpot: () => context.go('/map'),
      );
    }
    if (error is PlacesUnavailable) {
      return const StatusMessage(
        title: 'No places in this build',
        body:
            "Places are added when the app is built on the developer's "
            'computer. The demo build has sample places to try the wheel '
            'with.',
      );
    }
    return StatusMessage(
      title: "Couldn't find places nearby",
      body: 'Check your connection, then try again.',
      action: 'Try again',
      onAction: () => ref.invalidate(nearbyPlacesProvider),
    );
  }
}

/// The wheel on its side: as tall as the screen allows, and at most a
/// little over half its width, leaving the rest for the text.
double _wideDiameter(BoxConstraints c) => math.max(
  120,
  math.min(420, math.min(c.maxHeight - SpinWheel.arrowRoom, c.maxWidth * 0.55)),
);

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
  const _Loading({required this.title, required this.wide});

  final Widget title;
  final bool wide;

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
    if (!_show) {
      return Align(alignment: Alignment.topLeft, child: widget.title);
    }
    return widget.wide ? _wide() : _tall();
  }

  Widget _tall() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      widget.title,
      const SizedBox(height: AppSpacing.md),
      const Center(child: _Bone(width: 150, height: 14)),
      const SizedBox(height: AppSpacing.sm),
      const Center(child: _Bone(width: 210, height: 28)),
      Expanded(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final double d = _diameter(context, c);
            return Column(
              children: <Widget>[
                const SizedBox(height: _wheelGap + SpinWheel.arrowRoom),
                _WheelBone(diameter: d),
              ],
            );
          },
        ),
      ),
    ],
  );

  Widget _wide() => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints c) {
      final double d = _wideDiameter(c);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                widget.title,
                const SizedBox(height: AppSpacing.md),
                const _Bone(width: 150, height: 14),
                const SizedBox(height: AppSpacing.sm),
                const _Bone(width: 210, height: 28),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xxl),
          Align(
            alignment: Alignment.bottomCenter,
            child: _WheelBone(diameter: d),
          ),
        ],
      );
    },
  );
}

/// The wheel's placeholder, which also tells a screen reader why the
/// screen is waiting.
class _WheelBone extends StatelessWidget {
  const _WheelBone({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Finding places nearby',
    child: _Bone(width: diameter, height: diameter, round: true),
  );
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

/// The wheel before the filters are first chosen: blank, asking what the
/// person is after.
class _ChooseFirst extends StatelessWidget {
  const _ChooseFirst({required this.wide, required this.onChoose});

  final bool wide;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    const Widget copy = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'What are you after today?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Text(
          'Choose how far to go and how good it should be, and the wheel '
          'fills with places that fit.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.45, color: AppColors.muted),
        ),
      ],
    );
    final Widget action = FilledButton(
      onPressed: onChoose,
      child: const Text('Choose'),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (wide) {
          final double d = math.min(c.maxHeight, c.maxWidth * 0.45);
          return Row(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      copy,
                      const SizedBox(height: AppSpacing.xl),
                      action,
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              _BlankWheel(diameter: d),
            ],
          );
        }
        final double d = math.min(c.maxWidth, c.maxHeight * 0.5);
        return SingleChildScrollView(
          child: Column(
            children: <Widget>[
              const SizedBox(height: AppSpacing.xxl),
              _BlankWheel(diameter: d),
              const SizedBox(height: AppSpacing.xxl),
              copy,
              const SizedBox(height: AppSpacing.xl),
              action,
            ],
          ),
        );
      },
    );
  }
}

/// A wheel with no places yet: a dashed rim, faint spokes and a grey hub.
class _BlankWheel extends StatelessWidget {
  const _BlankWheel({required this.diameter});
  final double diameter;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: diameter,
      child: CustomPaint(
        painter: const _BlankWheelPainter(),
        child: Center(
          child: Container(
            width: diameter * 0.25,
            height: diameter * 0.25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.fill,
              border: Border.all(color: AppColors.surface, width: 5),
            ),
            child: const Text(
              'Spin',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BlankWheelPainter extends CustomPainter {
  const _BlankWheelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.shortestSide / 2 - 2;
    canvas.drawCircle(c, r, Paint()..color = AppColors.fill);
    final Paint spoke = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1.5;
    for (int i = 0; i < 8; i++) {
      final double a = i * math.pi / 4;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * r * 0.16,
        c + Offset(math.cos(a), math.sin(a)) * (r - 6),
        spoke,
      );
    }
    // A dashed rim: the wheel is there, waiting to be filled.
    final Paint dash = Paint()
      ..color = AppColors.handle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    const int dashes = 48;
    for (int i = 0; i < dashes; i++) {
      final double a = i * 2 * math.pi / dashes;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a,
        math.pi / dashes,
        false,
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(_BlankWheelPainter old) => false;
}
