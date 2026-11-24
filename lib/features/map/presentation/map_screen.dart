import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/size_reporter.dart';
import '../../../core/widgets/status_message.dart';
import '../../location/domain/location_repository.dart';
import '../../location/presentation/location_message.dart';
import '../../location/presentation/location_providers.dart';
import '../../places/domain/place.dart';
import '../../places/domain/place_filters.dart';
import '../../places/domain/places_repository.dart';
import '../../places/presentation/filters_button.dart';
import '../../places/presentation/hours_text.dart';
import '../../places/presentation/maps_link.dart';
import '../../places/presentation/places_providers.dart';
import 'places_map.dart';

/// The Map tab: the places on the wheel, round the search centre.
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
  LatLon? _focus;
  int _focusTick = 0;

  /// The height of the card or panel at the foot of the map, which the
  /// map's attribution must stay above to remain visible.
  double _panel = 0;

  void _panelSize(Size size) {
    if (mounted && size.height != _panel) setState(() => _panel = size.height);
  }

  /// How long each hop of a spin lasts, slowing down, with a last pause
  /// before the winner.
  static const List<int> _hopMs = <int>[90, 110, 140, 190, 260, 620];

  /// Picks a place by hopping across a few pins, then flies to the winner.
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
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _hop = null;
      _spinning = false;
      _selected = winner.id;
      _won = true;
      _focus = (latitude: winner.latitude, longitude: winner.longitude);
      _focusTick++;
    });
  }

  void _select(String? id) {
    if (_spinning) return;
    setState(() {
      _selected = id;
      _won = false;
    });
  }

  bool _tilted = true;
  int _recentre = 0;

  /// Where the middle of the map last came to rest, if it has moved.
  LatLon? _target;

  void _moved(double latitude, double longitude) =>
      setState(() => _target = (latitude: latitude, longitude: longitude));

  /// Searches round the middle of the map, or round [fallback] when the map
  /// has not moved yet.
  void _searchHere(LatLon fallback) {
    final LatLon at = _target ?? fallback;
    ref.read(pinProvider.notifier).drop(at.latitude, at.longitude);
    setState(() {
      _target = null;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SearchArea> area = ref.watch(searchAreaProvider);
    final AsyncValue<List<Place>> places = ref.watch(wheelPlacesProvider);
    final List<Place> list = places.value ?? const <Place>[];
    final Place? selected = list
        .where((Place p) => p.id == _selected)
        .firstOrNull;
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double clearance = AppNavMetrics.clearance(safe.bottom);
    final SearchArea? here = area.value;
    final PlaceFilters filters = ref.watch(filtersProvider);
    // Without a location, the person can still choose a spot on the map,
    // starting from the middle of the places (docs/decisions.md 003).
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
    final bool choosing = needs != null && start != null;
    final Widget? message = choosing ? null : _message(area, places);
    final bool showMap = here != null || choosing;
    final double latitude = here?.latitude ?? start?.latitude ?? 0;
    final double longitude = here?.longitude ?? start?.longitude ?? 0;
    // Search this area is offered once the middle of the map leaves the
    // ring. A flight to a spin's winner stays inside it, so never does.
    final bool strayed =
        here != null &&
        _target != null &&
        distanceMetres(
              here.latitude,
              here.longitude,
              _target!.latitude,
              _target!.longitude,
            ) >
            filters.maxDistanceMetres;
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: <Widget>[
          if (showMap)
            Positioned.fill(
              child: ref.watch(mapViewProvider)(
                MapProps(
                  latitude: latitude,
                  longitude: longitude,
                  radiusMetres: here == null ? null : filters.maxDistanceMetres,
                  places: here == null ? const <Place>[] : list,
                  selectedId: _hop ?? selected?.id,
                  tilted: _tilted,
                  recentre: _recentre,
                  bottomInset:
                      clearance + (_panel > 0 ? _panel + AppSpacing.sm : 0),
                  onPinTap: _select,
                  onMapTap: () => _select(null),
                  onMoved: _moved,
                  focus: _focus,
                  focusTick: _focusTick,
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
          else if (choosing) ...<Widget>[
            // The spot to search round is under the tip of this pin.
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(
                      CupertinoIcons.location_solid,
                      size: 40,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: clearance,
              child: SizeReporter(
                onSize: _panelSize,
                child: _ChooseSpot(
                  state: needs,
                  onSearch: () => _searchHere(start),
                ),
              ),
            ),
          ] else ...<Widget>[
            Positioned(
              top: safe.top + AppSpacing.lg,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _CountPill(text: _count(places, here)),
                        const SizedBox(height: AppSpacing.md),
                        _Appear(
                          visible: strayed,
                          child: _SearchHerePill(
                            onTap: () => _searchHere((
                              latitude: latitude,
                              longitude: longitude,
                            )),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      const FiltersButton(),
                      const SizedBox(height: AppSpacing.md),
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
                      _RoundButton(
                        label: 'Back to the search area',
                        onTap: () => setState(() {
                          _recentre++;
                          _target = null;
                        }),
                        child: const Icon(CupertinoIcons.scope, size: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: clearance,
              child: SizeReporter(
                onSize: _panelSize,
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : AppMotion.medium,
                  switchInCurve: AppMotion.enter,
                  switchOutCurve: AppMotion.exit,
                  transitionBuilder: (Widget child, Animation<double> a) =>
                      FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.15),
                            end: Offset.zero,
                          ).animate(a),
                          child: child,
                        ),
                      ),
                  child: selected != null
                      ? _PinCard(
                          key: ValueKey<String>(selected.id),
                          place: selected,
                          won: _won,
                          onClose: () => _select(null),
                        )
                      : list.isEmpty || here == null
                      ? const SizedBox.shrink()
                      : Center(
                          key: const ValueKey<String>('spin'),
                          child: _SpinButton(
                            onPressed: _spinning ? null : () => _spin(list),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _count(AsyncValue<List<Place>> places, SearchArea? here) {
    final String within = here == null
        ? ''
        : ' within ${formatDistance(ref.read(filtersProvider).maxDistanceMetres)}';
    return switch (places) {
      AsyncData<List<Place>>(value: final List<Place> l) when l.isEmpty =>
        'No places pass these filters',
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

class _CountPill extends StatelessWidget {
  const _CountPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: const ShapeDecoration(
          color: AppColors.surface,
          shape: StadiumBorder(),
          shadows: _floatShadow,
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.short,
          child: Text(
            text,
            key: ValueKey<String>(text),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
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
          shadows: _floatShadow,
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

/// The tapped place: what it is, whether it is open, and the way there.
class _PinCard extends ConsumerWidget {
  const _PinCard({
    super.key,
    required this.place,
    required this.won,
    required this.onClose,
  });

  final Place place;

  /// A spin's winner, so the card says so.
  final bool won;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double? rating = place.rating;
    final String reviews = place.reviewCount == 1
        ? '1 review'
        : '${formatCount(place.reviewCount)} reviews';
    final String meta = <String>[
      rating == null ? 'No rating yet' : '${rating.toStringAsFixed(1)} stars',
      reviews,
      '${formatDistance(place.distanceMetres)} away',
    ].join(', ');
    final DateTime now = ref.read(clockProvider)();
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _floatShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (won)
                            const Padding(
                              padding: EdgeInsets.only(bottom: AppSpacing.xs),
                              child: Text(
                                'Today you are eating at',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          Text(
                            place.name,
                            style: const TextStyle(
                              fontSize: 19,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            meta,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.muted,
                            ),
                          ),
                          if (place.hours case final hours?) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              hoursLine(hours, now),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Close',
                    icon: const Icon(CupertinoIcons.xmark, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: FilledButton(
                  onPressed: () => openInMaps(context, ref, place),
                  child: const Text('Open in Google Maps'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const List<BoxShadow> _floatShadow = <BoxShadow>[
  BoxShadow(color: Color(0x2926241F), blurRadius: 8, offset: Offset(0, 2)),
];

/// Choosing a spot on the map while location is not shared, with the way
/// to share it beside.
class _ChooseSpot extends ConsumerWidget {
  const _ChooseSpot({required this.state, required this.onSearch});

  final LocationState state;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LocationNotifier location = ref.read(locationProvider.notifier);
    final (String other, VoidCallback onOther) = switch (state) {
      RefusedForGood() => ('Open Settings', location.ask),
      LocationOff() => ('Turn on location', location.ask),
      PositionUnavailable() => ('Try my location again', location.recheck),
      _ => ('Use my location', location.ask),
    };
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _floatShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: const Text(
                  'Choose where to eat',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Move the map until the pin is where you want to eat, then '
                'search there.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: onSearch,
                child: const Text('Search here'),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(onPressed: onOther, child: Text(other)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Offered once the map has moved away from the search area.
class _SearchHerePill extends StatelessWidget {
  const _SearchHerePill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        shape: StadiumBorder(),
        shadows: _floatShadow,
      ),
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: const Text('Search this area'),
      ),
    );
  }
}

/// Fades and drops [child] in when [visible], and back out when not.
class _Appear extends StatelessWidget {
  const _Appear({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Duration d = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.medium;
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -0.3),
          duration: d,
          curve: AppMotion.enter,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: d,
            curve: AppMotion.enter,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Spins from the map: hops across the pins and lands on one.
class _SpinButton extends StatelessWidget {
  const _SpinButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        shape: StadiumBorder(),
        shadows: _floatShadow,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(140, 56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          disabledBackgroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.surface,
        ),
        child: const Text('Spin'),
      ),
    );
  }
}
