import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/spin_button.dart';
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
import 'wheel_painter.dart';
import 'wheel_readout.dart';

/// The Spin tab: how many places made it onto the wheel, the one under the
/// arrow in large type, and the wheel rising from behind the tab bar with
/// the Spin button over it (docs/decisions.md 021).
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
  bool _spinning = false;
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
    if (!chosen && places is AsyncData<List<Place>>) {
      // Until the filters are chosen the wheel waits, empty.
      return _ArcLayout(
        title: title,
        top: _ChooseFirst(onChoose: () => showFiltersSheet(context)),
        wheel: const _BlankWheel(),
      );
    }
    if (places case AsyncData<List<Place>>(
      value: final List<Place> list,
    ) when list.isNotEmpty) {
      return _ArcLayout(
        title: title,
        top: _readout(list),
        wheel: SpinWheel(
          key: _wheel,
          names: <String>[for (final Place p in list) p.name],
          labelsEndAbove: _ArcLayout.labelsEndAbove(context),
          onLanded: (int i) => _landed(list[i]),
          onCurrent: (int i) => setState(() => _current = i),
          onSpinning: (bool on) => setState(() => _spinning = on),
        ),
        spinButton: SpinButton(
          onPressed: _spinning ? null : () => _wheel.currentState?.spin(),
        ),
      );
    }
    if (places is! AsyncData<List<Place>> &&
        places is! AsyncError<List<Place>>) {
      return _Loading(title: title);
    }
    return _Message(
      title: title,
      child: switch (places) {
        AsyncData<List<Place>>() => StatusMessage(
          title: 'Nothing nearby passes these filters',
          body:
              'Go further, or lower the rating or the number of '
              'reviews, to bring some places back.',
          action: 'Edit filters',
          onAction: () => showFiltersSheet(context),
        ),
        AsyncError<List<Place>>(:final Object error) => _failed(error),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _readout(List<Place> list) {
    final int? at = _current;
    final Place? here = at != null && at < list.length ? list[at] : null;
    final Size screen = MediaQuery.sizeOf(context);
    return WheelReadout(
      count: list.length == 1
          ? '1 place on the wheel'
          : '${list.length} places on the wheel',
      name: here?.name ?? '',
      detail: here == null ? '' : _detail(here),
      align: screen.width > screen.height ? TextAlign.start : TextAlign.center,
    );
  }

  /// "4.9 stars · 120 m away".
  static String _detail(Place p) {
    final double? rating = p.rating;
    final String stars = rating == null
        ? 'No rating yet'
        : '${rating.toStringAsFixed(1)} stars';
    return '$stars · ${formatDistance(p.distanceMetres)} away';
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

/// Lays out the tab around the wheel. Upright, the Filters button and
/// [top] fill the space above the arrow, and the wheel runs from there to
/// the bottom edge, behind the tab bar. On its side, [top] goes down the
/// left and the wheel takes the right half (docs/decisions.md 016). The
/// Spin button floats over the wheel just above the tab bar. The loading
/// skeleton uses the same layout, so nothing moves when the places arrive.
class _ArcLayout extends StatelessWidget {
  const _ArcLayout({
    required this.title,
    required this.top,
    required this.wheel,
    this.spinButton,
  });

  final Widget title;
  final Widget top;
  final Widget wheel;
  final Widget? spinButton;

  /// Upright, the arrow sits this far down the screen.
  static const double _arrowAt = 0.43;

  /// The least room above the arrow for the Filters button and the name.
  static const double _minTextRoom = 220;

  static const double _spinHeight = 56;

  /// How far above the bottom edge the Spin button sits: just above the
  /// tab bar.
  static double spinBottom(BuildContext context) =>
      AppNavMetrics.clearance(MediaQuery.paddingOf(context).bottom);

  /// How far above the bottom edge the wedge names must end: above the
  /// Spin button, with a little room.
  static double labelsEndAbove(BuildContext context) =>
      spinBottom(context) + _spinHeight + AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool wide = c.maxWidth > c.maxHeight;
        final double textTop = pad.top + AppSpacing.lg;
        final Rect wheelBox;
        final Rect textBox;
        if (wide) {
          final double split =
              pad.left + (c.maxWidth - pad.left - pad.right) / 2;
          wheelBox = Rect.fromLTRB(
            split,
            textTop,
            c.maxWidth - pad.right,
            c.maxHeight,
          );
          textBox = Rect.fromLTRB(
            pad.left + AppSpacing.xl,
            textTop,
            split - AppSpacing.xl,
            c.maxHeight - AppNavMetrics.clearance(pad.bottom),
          );
        } else {
          final double arrow = math.max(
            textTop + _minTextRoom,
            c.maxHeight * _arrowAt,
          );
          wheelBox = Rect.fromLTRB(
            0,
            arrow - ArcGeometry.rimTop,
            c.maxWidth,
            c.maxHeight,
          );
          textBox = Rect.fromLTRB(
            pad.left + AppSpacing.xl,
            textTop,
            c.maxWidth - pad.right - AppSpacing.xl,
            wheelBox.top,
          );
        }
        return Stack(
          children: <Widget>[
            Positioned.fromRect(rect: wheelBox, child: wheel),
            Positioned.fromRect(
              rect: textBox,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  title,
                  const SizedBox(height: AppSpacing.md),
                  Expanded(child: top),
                ],
              ),
            ),
            if (spinButton case final Widget button)
              Positioned(
                left: wheelBox.left,
                width: wheelBox.width,
                bottom: spinBottom(context),
                child: Center(child: button),
              ),
          ],
        );
      },
    );
  }
}

/// The states with no wheel: the Filters button and a message below it.
class _Message extends StatelessWidget {
  const _Message({required this.title, required this.child});

  final Widget title;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppNavMetrics.clearance(MediaQuery.paddingOf(context).bottom),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          title,
          const SizedBox(height: AppSpacing.md),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

/// Nothing for the first 300 ms, since a quick answer needs no placeholder,
/// then a skeleton of the count, the name, the rating line and the wheel,
/// each where it will be.
class _Loading extends StatefulWidget {
  const _Loading({required this.title});

  final Widget title;

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
      return _Message(title: widget.title, child: const SizedBox.shrink());
    }
    final bool wide =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    return _ArcLayout(
      title: widget.title,
      top: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: wide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: const <Widget>[
          _Bone(width: 150, height: 14),
          SizedBox(height: AppSpacing.md),
          _Bone(width: 230, height: 32),
          SizedBox(height: AppSpacing.md),
          _Bone(width: 130, height: 14),
        ],
      ),
      wheel: Semantics(
        label: 'Finding places nearby',
        child: const _BlankWheel(dashed: false),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.fill,
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
  );
}

/// Above the blank wheel, before the filters are first chosen: what the
/// wheel is waiting for, and the way to choose.
class _ChooseFirst extends StatelessWidget {
  const _ChooseFirst({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final bool wide =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final TextAlign align = wide ? TextAlign.start : TextAlign.center;
    // Large text can make this taller than the room above the wheel.
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: wide
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              'What are you after today?',
              textAlign: align,
              style: const TextStyle(
                fontSize: 20,
                height: 1.25,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Choose how far to go and how good it should be, and the wheel '
              'fills with places that fit.',
              textAlign: align,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(onPressed: onChoose, child: const Text('Choose')),
          ],
        ),
      ),
    );
  }
}

/// The wheel with no places on it: the same shape, in grey. Dashed, it
/// waits for the filters to be chosen; plain, it stands in while places
/// load.
class _BlankWheel extends StatelessWidget {
  const _BlankWheel({this.dashed = true});

  final bool dashed;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRect(
      child: CustomPaint(
        size: Size.infinite,
        painter: _BlankWheelPainter(dashed: dashed),
      ),
    ),
  );
}

class _BlankWheelPainter extends CustomPainter {
  const _BlankWheelPainter({required this.dashed});

  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final ArcGeometry g = ArcGeometry(size);
    canvas.drawCircle(g.centre, g.radius, Paint()..color = AppColors.fill);
    if (!dashed) return;
    final Paint spoke = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1.5;
    for (int i = -3; i <= 3; i++) {
      final double a = -math.pi / 2 + i * 0.12;
      canvas.drawLine(
        g.centre + Offset(math.cos(a), math.sin(a)) * g.radius * 0.4,
        g.centre + Offset(math.cos(a), math.sin(a)) * (g.radius - 8),
        spoke,
      );
    }
    // A dashed rim: the wheel is there, waiting to be filled.
    final Paint dash = Paint()
      ..color = AppColors.handle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    const int dashes = 240;
    for (int i = 0; i < dashes; i++) {
      final double a = i * 2 * math.pi / dashes;
      canvas.drawArc(g.disc, a, math.pi / dashes, false, dash);
    }
  }

  @override
  bool shouldRepaint(_BlankWheelPainter old) => old.dashed != dashed;
}
