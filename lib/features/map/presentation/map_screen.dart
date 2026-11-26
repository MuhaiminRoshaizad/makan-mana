import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/spin_button.dart';
import '../../../core/widgets/status_message.dart';
import '../../location/domain/location_repository.dart';
import '../../location/presentation/location_message.dart';
import '../../location/presentation/location_providers.dart';
import '../../places/domain/place.dart';
import '../../places/domain/place_filters.dart';
import '../../places/domain/places_repository.dart';
import '../../places/presentation/filters_button.dart';
import '../../places/presentation/maps_link.dart';
import '../../places/presentation/place_sheet.dart';
import '../../places/presentation/places_providers.dart';
import 'places_map.dart';

/// The Map tab: the places on the wheel, round you or a pin you drop.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.random});

  /// Picks the spin's hops and winner; tests pass a seeded one.
  final math.Random? random;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final math.Random _random = widget.random ?? math.Random();
  String? _selected;

  /// The pin lit up while a spin hops across the map.
  String? _hop;
  bool _spinning = false;

  /// Whether the card shows a spin's winner rather than a tapped pin.
  bool _won = false;
  bool _tilted = true;
  int _recentre = 0;
  LatLon? _focus;
  int _focusTick = 0;
  LatLon? _ringAt;
  int _ringTick = 0;

  /// Location is asked for once, the first time the map opens without it.
  bool _asked = false;

  /// Shown once on entering Pin mode: how to move the pin.
  bool _hint = false;
  Timer? _hintTimer;

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  /// How long each hop of a spin lasts, slowing down, with a last pause
  /// before the winner.
  static const List<int> _hopMs = <int>[90, 110, 140, 190, 260, 620];

  /// Hops across a few pins with the camera still, lands with a ring, flies
  /// in on the winner, and only then shows its card.
  Future<void> _spin(List<Place> list) async {
    if (_spinning || list.isEmpty) return;
    final bool still = MediaQuery.disableAnimationsOf(context);
    setState(() {
      _spinning = true;
      _selected = null;
    });
    Place pick(String? not) {
      while (true) {
        final Place p = list[_random.nextInt(list.length)];
        if (p.id != not || list.length == 1) return p;
      }
    }

    String? last;
    if (!still) {
      for (final int ms in _hopMs) {
        last = pick(last).id;
        setState(() => _hop = last);
        unawaited(HapticFeedback.selectionClick());
        await Future<void>.delayed(Duration(milliseconds: ms));
        if (!mounted) return;
      }
    }
    final Place winner = pick(last);
    final LatLon at = (latitude: winner.latitude, longitude: winner.longitude);
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _hop = winner.id;
      _ringAt = at;
      _ringTick++;
    });
    if (!still) await Future<void>.delayed(const Duration(milliseconds: 640));
    if (!mounted) return;
    setState(() {
      _focus = at;
      _focusTick++;
    });
    if (!still) await Future<void>.delayed(const Duration(milliseconds: 1150));
    if (!mounted) return;
    setState(() {
      _hop = null;
      _spinning = false;
      _selected = winner.id;
      _won = true;
    });
  }

  void _select(String? id) {
    if (_spinning) return;
    setState(() {
      // Putting a winner's card away flies the camera back out.
      if (id == null && _won) _recentre++;
      _selected = id;
      _won = false;
    });
  }

  /// Drops a pin at [at] to search round it, and says how to move it.
  void _dropPin(LatLon at) {
    ref.read(pinProvider.notifier).drop(at.latitude, at.longitude);
    _hintTimer?.cancel();
    setState(() {
      _selected = null;
      _hint = true;
    });
    _hintTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _hint = false);
    });
  }

  /// Back to searching round the phone, asking for location if need be.
  void _useYou() {
    final LocationState? here = ref.read(locationProvider).value;
    setState(() {
      _selected = null;
      _hint = false;
    });
    // The demo searches round its own spot, with no location to wait for.
    if (here is Located || demoMode) {
      ref.read(pinProvider.notifier).clear();
    } else {
      // The pin stays until location comes through.
      ref.read(locationProvider.notifier).ask();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SearchArea> area = ref.watch(searchAreaProvider);
    final AsyncValue<List<Place>> places = ref.watch(wheelPlacesProvider);
    final bool chosen = ref.watch(filtersChosenProvider);
    final PlaceFilters filters = ref.watch(filtersProvider);
    final LatLon? pin = ref.watch(pinProvider);
    final LocationState? location = ref.watch(locationProvider).value;
    final List<Place> list = chosen
        ? places.value ?? const <Place>[]
        : const <Place>[];
    final Place? selected = list
        .where((Place p) => p.id == _selected)
        .firstOrNull;
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double clearance = AppNavMetrics.clearance(safe.bottom);
    final SearchArea? here = area.value;

    // Once location comes through, a pin dropped while waiting for it goes.
    ref.listen(locationProvider, (
      AsyncValue<LocationState>? was,
      AsyncValue<LocationState> now,
    ) {
      if (was?.value is! Located && now.value is Located && pin != null) {
        ref.read(pinProvider.notifier).clear();
      }
    });

    // Without a location, ask once; refused, search round a pin dropped in
    // the middle of the places (docs/decisions.md 003).
    final LocationState? needs = switch (area.error) {
      final Object e => switch (rootCause(e)) {
        NeedsLocation(:final state) => state,
        _ => null,
      },
      null => null,
    };
    final LatLon? start = needs == null
        ? null
        : ref.watch(mapStartProvider).value;
    if (needs != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (needs is CanAsk && !_asked) {
          _asked = true;
          ref.read(locationProvider.notifier).ask();
        } else if (start != null && ref.read(pinProvider) == null) {
          _dropPin(start);
        }
      });
    }

    final Widget? message = here == null && start == null
        ? _message(area, places)
        : null;
    final bool pinMode = pin != null;
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: <Widget>[
          if (here != null)
            Positioned.fill(
              child: ref.watch(mapViewProvider)(
                MapProps(
                  latitude: here.latitude,
                  longitude: here.longitude,
                  radiusMetres: filters.maxDistanceMetres,
                  places: list,
                  selectedId: _hop ?? selected?.id,
                  tilted: _tilted,
                  recentre: _recentre,
                  you: location is Located
                      ? (
                          latitude: location.latitude,
                          longitude: location.longitude,
                        )
                      : null,
                  dropPin: pin,
                  onPinTap: _select,
                  onMapTap: () => _select(null),
                  onPinDropped: (double lat, double lon) =>
                      ref.read(pinProvider.notifier).drop(lat, lon),
                  focus: _focus,
                  focusTick: _focusTick,
                  ringAt: _ringAt,
                  ringTick: _ringTick,
                ),
              ),
            ),
          if (message != null)
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  safe.top + AppSpacing.lg,
                  AppSpacing.xl,
                  clearance,
                ),
                child: message,
              ),
            )
          else ...<Widget>[
            Positioned(
              top: safe.top + AppSpacing.lg,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: FiltersButton(
                        label: _count(places, filters, chosen),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      _RoundButton(
                        label: '3D view',
                        toggled: _tilted,
                        onTap: () => setState(() => _tilted = !_tilted),
                        child: const Text(
                          '3D',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ModePill(
                        pin: pinMode,
                        onYou: _useYou,
                        onPin: () => _dropPin(
                          pin ??
                              (
                                latitude: here?.latitude ?? 0,
                                longitude: here?.longitude ?? 0,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: safe.top + AppSpacing.lg + 48 + AppSpacing.md,
              left: AppSpacing.lg,
              right: 100,
              child: _Hint(
                visible: _hint && pinMode,
                text: 'Drag the pin to where you want to eat',
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: clearance,
              child: _HandOver(
                child: selected != null
                    ? _PlaceCard(
                        key: ValueKey<String>('card ${selected.id} $_won'),
                        place: selected,
                        won: _won,
                        onClose: () => _select(null),
                        onSpinAgain: () {
                          _select(null);
                          _spin(list);
                        },
                      )
                    : list.isEmpty || here == null
                    ? null
                    : SpinButton(
                        key: const ValueKey<String>('spin'),
                        onPressed: _spinning ? null : () => _spin(list),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _count(
    AsyncValue<List<Place>> places,
    PlaceFilters filters,
    bool chosen,
  ) {
    if (!chosen) return "Choose what you're after";
    final String within =
        ' within ${formatDistance(filters.maxDistanceMetres)}';
    return switch (places) {
      AsyncData<List<Place>>(value: final List<Place> l) when l.isEmpty =>
        'No places$within',
      AsyncData<List<Place>>(value: final List<Place> l) =>
        '${l.length} ${l.length == 1 ? 'place' : 'places'}$within',
      _ => 'Finding places',
    };
  }

  /// A message in place of the map, or null when the map can show.
  Widget? _message(
    AsyncValue<SearchArea> area,
    AsyncValue<List<Place>> places,
  ) {
    final Object? error = area.error ?? places.error;
    if (error == null) return null;
    return switch (rootCause(error)) {
      NeedsLocation(:final state) => LocationMessage(state),
      PlacesUnavailable() => const StatusMessage(
        title: 'No places in this build',
        body:
            "Places are added when the app is built on the developer's "
            'computer. The demo build has sample places to try the map with.',
      ),
      _ => StatusMessage(
        title: "Couldn't find places nearby",
        body: 'Check your connection, then try again.',
        action: 'Try again',
        onAction: () => ref.invalidate(nearbyPlacesProvider),
      ),
    };
  }
}

/// You or Pin: search round the phone, or round a pin you drag. One pill
/// with a word under each icon, so it reads as either-or.
class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.pin,
    required this.onYou,
    required this.onPin,
  });

  final bool pin;
  final VoidCallback onYou;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    final Duration d = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return Semantics(
      container: true,
      label: 'Search round',
      child: Container(
        width: 56,
        padding: const EdgeInsets.all(4),
        decoration: const ShapeDecoration(
          color: AppColors.surface,
          shape: StadiumBorder(),
          shadows: AppShadows.float,
        ),
        child: Stack(
          children: <Widget>[
            AnimatedPositioned(
              duration: d,
              curve: const Cubic(0.3, 1.3, 0.5, 1),
              left: 0,
              right: 0,
              top: pin ? 62 : 0,
              height: 62,
              child: const DecoratedBox(
                decoration: ShapeDecoration(
                  color: AppColors.ink,
                  shape: StadiumBorder(),
                ),
              ),
            ),
            Column(
              children: <Widget>[
                _ModeButton(
                  label: 'You',
                  on: !pin,
                  onTap: onYou,
                  icon: CupertinoIcons.location_fill,
                ),
                _ModeButton(
                  label: 'Pin',
                  on: pin,
                  onTap: onPin,
                  icon: CupertinoIcons.map_pin,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.on,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final Color c = on ? AppColors.surface : AppColors.muted;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: on,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 62,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 20, color: c),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: AppMotion.short,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: c,
                  ),
                  child: Text(label, textScaler: TextScaler.noScaling),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A one-line hint that drops in, then leaves by itself.
class _Hint extends StatelessWidget {
  const _Hint({required this.visible, required this.text});

  final bool visible;
  final String text;

  @override
  Widget build(BuildContext context) {
    final Duration d = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.medium;
    return IgnorePointer(
      child: Semantics(
        liveRegion: visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -0.3),
          duration: d,
          curve: AppMotion.enter,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: d,
            child: Align(
              alignment: Alignment.topLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.surface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows one thing at the foot of the map, and hands over to the next only
/// after the first has gone: the card slides away, then Spin pops in, so
/// the two never cross.
class _HandOver extends StatefulWidget {
  const _HandOver({required this.child});

  final Widget? child;

  @override
  State<_HandOver> createState() => _HandOverState();
}

class _HandOverState extends State<_HandOver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a;
  late Widget? _shown = widget.child;

  @override
  void initState() {
    super.initState();
    _a = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 200),
      value: widget.child == null ? 0 : 1,
    );
  }

  @override
  void didUpdateWidget(_HandOver old) {
    super.didUpdateWidget(old);
    final Widget? next = widget.child;
    if (next?.key == _shown?.key) {
      _shown = next;
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _shown = next);
      _a.value = next == null ? 0 : 1;
      return;
    }
    // Out first, then in.
    _a.reverse().then((_) {
      if (!mounted) return;
      setState(() => _shown = widget.child);
      if (widget.child != null) _a.forward();
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget? shown = _shown;
    if (shown == null) return const SizedBox.shrink();
    final bool card = shown is _PlaceCard;
    return AnimatedBuilder(
      animation: _a,
      builder: (BuildContext context, Widget? child) {
        final double t = _a.status == AnimationStatus.reverse
            ? Curves.easeIn.transform(_a.value)
            : (card ? AppMotion.enter : const Cubic(0.3, 1.4, 0.5, 1))
                  .transform(_a.value);
        return Opacity(
          opacity: _a.value.clamp(0, 1),
          child: card
              ? Transform.translate(
                  offset: Offset(0, 40 * (1 - t)),
                  child: child,
                )
              : Transform.scale(scale: 0.8 + 0.2 * t, child: child),
        );
      },
      child: Center(child: shown),
    );
  }
}

/// A round button floating on the map. A toggle keeps its glyph and shows
/// that it is on by turning ink.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.onTap,
    required this.child,
    this.toggled,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final bool on = toggled ?? false;
    return Semantics(
      button: true,
      label: label,
      toggled: toggled,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.short,
        width: 48,
        height: 48,
        decoration: ShapeDecoration(
          color: on ? AppColors.ink : AppColors.surface,
          shape: const CircleBorder(),
          shadows: AppShadows.float,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(
                  color: on ? AppColors.surface : AppColors.ink,
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: on ? AppColors.surface : AppColors.ink,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The chosen place over the map, laid out as the top of its sheet. A tap,
/// or a pull upwards, opens the whole sheet with the reviews; the card
/// follows the finger a little and springs back (docs/decisions.md 022).
class _PlaceCard extends ConsumerStatefulWidget {
  const _PlaceCard({
    super.key,
    required this.place,
    required this.won,
    required this.onClose,
    required this.onSpinAgain,
  });

  final Place place;

  /// A spin's winner, so the card says so and offers another spin.
  final bool won;
  final VoidCallback onClose;
  final VoidCallback onSpinAgain;

  @override
  ConsumerState<_PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends ConsumerState<_PlaceCard>
    with SingleTickerProviderStateMixin {
  /// How far the card has been pulled up, in logical pixels.
  late final AnimationController _pull = AnimationController.unbounded(
    vsync: this,
  );

  /// A pull this far, or a flick upwards, opens the sheet.
  static const double _opensAt = 56;

  @override
  void dispose() {
    _pull.dispose();
    super.dispose();
  }

  void _open() {
    showPlaceSheet(
      context,
      place: widget.place,
      won: widget.won,
      onSpinAgain: widget.won
          ? () {
              Navigator.of(context, rootNavigator: true).pop();
              widget.onSpinAgain();
            }
          : null,
    );
  }

  void _drag(DragUpdateDetails d) {
    // Upwards it follows the finger, slowing as it goes; downwards it
    // barely moves.
    final double up = math.max(0, _pull.value - d.delta.dy);
    _pull.value = up < 40 ? up : 40 + (up - 40) * 0.35;
  }

  void _release(DragEndDetails d) {
    final bool opens =
        _pull.value >= _opensAt * 0.5 || (d.primaryVelocity ?? 0) < -500;
    if (opens) _open();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pull.value = 0;
      return;
    }
    _pull.animateWith(SpringSimulation(AppMotion.spring, _pull.value, 0, 0));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pull,
      builder: (BuildContext context, Widget? child) =>
          Transform.translate(offset: Offset(0, -_pull.value), child: child),
      child: Semantics(
        container: true,
        button: true,
        label: 'Show more about ${widget.place.name}',
        onTap: _open,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _open,
          onVerticalDragUpdate: _drag,
          onVerticalDragEnd: _release,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppShadows.float,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // The handle says the card can be pulled up.
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.handle,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: PlaceSummary(
                            place: widget.place,
                            won: widget.won,
                            compact: true,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onClose,
                        tooltip: 'Close',
                        icon: const Icon(CupertinoIcons.xmark, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: FilledButton(
                      onPressed: () => openInMaps(context, ref, widget.place),
                      child: const Text('Open in Google Maps'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
