import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/status_message.dart';
import '../../location/presentation/location_message.dart';
import '../../places/domain/place.dart';
import '../../places/domain/places_repository.dart';
import '../../places/presentation/filters_button.dart';
import '../../places/presentation/hours_text.dart';
import '../../places/presentation/maps_link.dart';
import '../../places/presentation/places_providers.dart';
import 'places_map.dart';

/// The Map tab: the places on the wheel, round the search centre.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  String? _selected;
  bool _tilted = true;
  int _recentre = 0;

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
    final Widget? message = _message(area, places);
    final SearchArea? here = area.value;
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
                  radiusMetres: here.radiusMetres,
                  places: list,
                  selectedId: selected?.id,
                  tilted: _tilted,
                  recentre: _recentre,
                  bottomInset: clearance,
                  onPinTap: (String id) => setState(() => _selected = id),
                  onMapTap: () => setState(() => _selected = null),
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
                  Flexible(child: _CountPill(text: _count(places, here))),
                  const SizedBox(width: AppSpacing.sm),
                  const Spacer(),
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
                        onTap: () => setState(() => _recentre++),
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
                child: selected == null
                    ? const SizedBox.shrink()
                    : _PinCard(
                        key: ValueKey<String>(selected.id),
                        place: selected,
                        onClose: () => setState(() => _selected = null),
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
        : ' within ${formatDistance(here.radiusMetres)}';
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
  const _PinCard({super.key, required this.place, required this.onClose});

  final Place place;
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
