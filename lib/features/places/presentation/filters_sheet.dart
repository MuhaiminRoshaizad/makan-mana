import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../domain/place.dart';
import '../domain/place_filters.dart';
import '../domain/place_kind.dart';
import 'places_providers.dart';

/// The distances offered, in metres, up to the 15 km the places list
/// covers.
const List<int> distanceSteps = <int>[
  500,
  1000,
  2000,
  3000,
  5000,
  10000,
  15000,
];

/// The steps each filter offers, as (label, value).
const List<(String, int?)> placeCountSteps = <(String, int?)>[
  ('5', 5),
  ('10', 10),
  ('20', 20),
  ('All', null),
];
const List<(String, double?)> ratingSteps = <(String, double?)>[
  ('Any', null),
  ('3.5', 3.5),
  ('4.0', 4.0),
  ('4.5', 4.5),
];
const List<(String, int)> reviewSteps = <(String, int)>[
  ('Any', 0),
  ('20+', 20),
  ('50+', 50),
  ('200+', 200),
  ('500+', 500),
];

/// Opens the filters. Changes apply only through the Show button, so a
/// sheet swiped away leaves the wheel as it was.
Future<void> showFiltersSheet(BuildContext context) => showAppSheet<void>(
  context,
  scrollControlled: true,
  builder: (_) => const FiltersSheet(),
);

class FiltersSheet extends ConsumerStatefulWidget {
  const FiltersSheet({super.key});

  @override
  ConsumerState<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<FiltersSheet> {
  late PlaceFilters _draft = ref.read(filtersProvider);

  void _set(PlaceFilters f) => setState(() => _draft = f);

  @override
  Widget build(BuildContext context) {
    final List<Place>? nearby = ref.watch(nearbyPlacesProvider).value;
    final int? passing = nearby?.where(_draft.passes).length;
    final int? max = _draft.maxPlaces;
    final int? matching = passing == null || max == null
        ? passing
        : (passing < max ? passing : max);
    final FiltersNotifier filters = ref.read(filtersProvider.notifier);
    final bool hours = ref.watch(placesRepositoryProvider).knowsOpeningHours;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: _draft == filters.defaults
                    ? null
                    : () => _set(filters.defaults),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Distance(
            metres: _draft.maxDistanceMetres,
            onChanged: (int m) => _set(_draft.copyWith(maxDistanceMetres: m)),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const _Label('Kind of place'),
          _Kinds(
            selected: _draft.kinds,
            onChanged: (Set<PlaceKind> k) => _set(_draft.copyWith(kinds: k)),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const _Label('Minimum rating'),
          _Segments(
            label: 'Minimum rating',
            labels: <String>[for (final (String l, _) in ratingSteps) l],
            selected: ratingSteps.indexWhere(
              ((String, double?) s) => s.$2 == _draft.minRating,
            ),
            onSelect: (int i) =>
                _set(_draft.copyWith(minRating: () => ratingSteps[i].$2)),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const _Label('Minimum number of reviews'),
          _Segments(
            label: 'Minimum number of reviews',
            labels: <String>[for (final (String l, _) in reviewSteps) l],
            selected: reviewSteps.indexWhere(
              ((String, int) s) => s.$2 == _draft.minReviews,
            ),
            onSelect: (int i) =>
                _set(_draft.copyWith(minReviews: reviewSteps[i].$2)),
          ),
          const SizedBox(height: AppSpacing.xxl),
          // Offered only where the places say when they are open.
          if (hours) ...<Widget>[
            // A Material, so the row's press highlight paints on the card.
            Material(
              color: AppColors.background,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: MergeSemantics(
                child: ListTile(
                  minTileHeight: 56,
                  title: const Text(
                    'Open now',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  trailing: CupertinoSwitch(
                    value: _draft.openNow,
                    activeTrackColor: AppColors.ink,
                    onChanged: (bool on) => _set(_draft.copyWith(openNow: on)),
                  ),
                  onTap: () => _set(_draft.copyWith(openNow: !_draft.openNow)),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.xs,
                0,
              ),
              child: Text(
                'Opening hours come from Google Maps and can be out of date. '
                'Places whose hours are not known stay on.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          const _Label('Places on the wheel'),
          _Segments(
            label: 'Places on the wheel',
            labels: <String>[for (final (String l, _) in placeCountSteps) l],
            selected: placeCountSteps.indexWhere(
              ((String, int?) s) => s.$2 == _draft.maxPlaces,
            ),
            onSelect: (int i) =>
                _set(_draft.copyWith(maxPlaces: () => placeCountSteps[i].$2)),
          ),
          if (passing != null && passing > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.xs,
                0,
              ),
              child: Text(
                max != null && passing > max
                    ? 'The nearest $max of the $passing that pass.'
                    : passing == 1
                    ? 'The one place that passes.'
                    : 'All $passing that pass.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.muted,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          if (matching == 0) ...<Widget>[
            const Text(
              'No places pass these filters. Go further, or lower the rating '
              'or the reviews.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          FilledButton(
            onPressed: matching == 0
                ? null
                : () {
                    ref.read(filtersProvider.notifier).set(_draft);
                    Navigator.of(context).pop();
                  },
            child: Text(switch (matching) {
              null => 'Apply',
              0 => 'No matches',
              1 => 'Show 1 place',
              final int n => 'Show $n places',
            }),
          ),
        ],
      ),
    );
  }
}

/// How far to look, from 500 m to 15 km. The Material slider, because it can
/// say "2 km" to a screen reader; CupertinoSlider only says a percentage.
class _Distance extends StatelessWidget {
  const _Distance({required this.metres, required this.onChanged});

  final int metres;
  final ValueChanged<int> onChanged;

  int get _step {
    int best = 0;
    for (int i = 0; i < distanceSteps.length; i++) {
      if ((distanceSteps[i] - metres).abs() <
          (distanceSteps[best] - metres).abs()) {
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Distance',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                Text(
                  formatDistance(metres),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.ink,
            inactiveTrackColor: AppColors.line,
            thumbColor: AppColors.ink,
            overlayColor: AppColors.ink.withValues(alpha: 0.08),
            activeTickMarkColor: AppColors.surface,
            inactiveTickMarkColor: AppColors.muted,
            showValueIndicator: ShowValueIndicator.never,
          ),
          // One node: "Distance, 2 km".
          child: MergeSemantics(
            child: Semantics(
              label: 'Distance',
              child: Slider(
                value: _step.toDouble(),
                max: (distanceSteps.length - 1).toDouble(),
                divisions: distanceSteps.length - 1,
                semanticFormatterCallback: (double v) =>
                    formatDistance(distanceSteps[v.round()]),
                onChanged: (double v) => onChanged(distanceSteps[v.round()]),
              ),
            ),
          ),
        ),
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  formatDistance(distanceSteps.first),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                Text(
                  formatDistance(distanceSteps.last),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
      ),
    ),
  );
}

/// iOS's sliding segmented control, in the app's greys.
class _Segments extends StatelessWidget {
  const _Segments({
    required this.label,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      container: true,
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: selected,
        backgroundColor: AppColors.fill,
        thumbColor: AppColors.surface,
        onValueChanged: (int? i) {
          if (i != null) onSelect(i);
        },
        children: <int, Widget>{
          for (int i = 0; i < labels.length; i++)
            i: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                labels[i],
                maxLines: 1,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: i == selected ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
        },
      ),
    );
  }
}

/// One toggle per kind of place. At least one stays on, or nothing could
/// ever reach the wheel.
class _Kinds extends StatelessWidget {
  const _Kinds({required this.selected, required this.onChanged});

  final Set<PlaceKind> selected;
  final ValueChanged<Set<PlaceKind>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final PlaceKind k in PlaceKind.values)
          _KindToggle(
            label: k.label,
            on: selected.contains(k),
            // The last one on cannot be switched off.
            onTap: selected.contains(k) && selected.length == 1
                ? null
                : () => onChanged(
                    selected.contains(k)
                        ? (Set<PlaceKind>.of(selected)..remove(k))
                        : (Set<PlaceKind>.of(selected)..add(k)),
                  ),
          ),
      ],
    );
  }
}

class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.label, required this.on, this.onTap});

  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.short,
          curve: AppMotion.enter,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: ShapeDecoration(
            color: on ? AppColors.ink : AppColors.surface,
            shape: StadiumBorder(
              side: BorderSide(color: on ? AppColors.ink : AppColors.line),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: on ? AppColors.surface : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
