import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../domain/place.dart';
import '../domain/place_filters.dart';
import 'places_providers.dart';

/// The steps each filter offers, as (label, value).
const List<(String, double?)> ratingSteps = <(String, double?)>[
  ('Any', null),
  ('3.5', 3.5),
  ('4.0', 4.0),
  ('4.5', 4.5),
];
const List<(String, int)> reviewSteps = <(String, int)>[
  ('Any', 0),
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
    final int? matching = nearby?.where(_draft.passes).length;
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
          const SizedBox(height: AppSpacing.xl),
          if (matching == 0) ...<Widget>[
            const Text(
              'No places nearby pass these filters. Lower the rating or the '
              'reviews.',
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
