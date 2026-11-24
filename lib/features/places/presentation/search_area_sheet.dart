import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../location/domain/location_repository.dart';
import '../../location/presentation/location_providers.dart';
import 'places_providers.dart';

/// The radii offered, in metres. 15 km is as far as the places list reaches
/// (docs/decisions.md 017).
const List<int> radiusSteps = <int>[500, 1000, 2000, 3000, 5000, 10000, 15000];

/// Opens the search area. Like the filters, nothing changes until Search
/// this area is pressed.
Future<void> showSearchAreaSheet(BuildContext context) => showAppSheet<void>(
  context,
  scrollControlled: true,
  builder: (_) => const SearchAreaSheet(),
);

class SearchAreaSheet extends ConsumerStatefulWidget {
  const SearchAreaSheet({super.key});

  @override
  ConsumerState<SearchAreaSheet> createState() => _SearchAreaSheetState();
}

class _SearchAreaSheetState extends ConsumerState<SearchAreaSheet> {
  late int _step = _nearestStep(ref.read(radiusProvider));

  static int _nearestStep(int metres) {
    int best = 0;
    for (int i = 0; i < radiusSteps.length; i++) {
      if ((radiusSteps[i] - metres).abs() <
          (radiusSteps[best] - metres).abs()) {
        best = i;
      }
    }
    return best;
  }

  void _search() {
    ref.read(radiusProvider.notifier).set(radiusSteps[_step]);
    // Read the position again too, in case the phone has moved since.
    if (ref.read(locationProvider).value is Located) {
      ref.read(locationProvider.notifier).recheck();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final String radius = formatDistance(radiusSteps[_step]);
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
          Semantics(
            header: true,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'Search area',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ExcludeSemantics(
                    child: Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Radius',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          radius,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            fontFeatures: <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The Material slider, because it can say "2 km" to a
                  // screen reader; CupertinoSlider only says a percentage.
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
                    // One node: "Radius, 2 km".
                    child: MergeSemantics(
                      child: Semantics(
                        label: 'Radius',
                        child: Slider(
                          value: _step.toDouble(),
                          max: (radiusSteps.length - 1).toDouble(),
                          divisions: radiusSteps.length - 1,
                          semanticFormatterCallback: (double v) =>
                              formatDistance(radiusSteps[v.round()]),
                          onChanged: (double v) =>
                              setState(() => _step = v.round()),
                        ),
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          formatDistance(radiusSteps.first),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          formatDistance(radiusSteps.last),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
              'Your location is read when you search, and only while the app '
              'is open.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _search,
            child: const Text('Search this area'),
          ),
        ],
      ),
    );
  }
}
