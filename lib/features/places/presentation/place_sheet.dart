import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../domain/place.dart';
import '../domain/review.dart';
import 'hours_text.dart';
import 'maps_link.dart';
import 'places_providers.dart';

/// Opens [PlaceSheet] for [place]. It may grow past the usual 9/16 cap
/// and scrolls, so large system text never cuts off its buttons.
Future<void> showPlaceSheet(
  BuildContext context, {
  required Place place,
  bool won = true,
  VoidCallback? onSeeOnMap,
  VoidCallback? onSpinAgain,
}) => showAppSheet<void>(
  context,
  scrollControlled: true,
  builder: (_) => PlaceSheet(
    place: place,
    won: won,
    onSeeOnMap: onSeeOnMap,
    onSpinAgain: onSpinAgain,
  ),
);

/// A place in full, on the wheel's result and on the map alike: what it
/// is, how it rates, how far it is and when it opens, the ways onward, and
/// its reviews.
class PlaceSheet extends ConsumerWidget {
  const PlaceSheet({
    super.key,
    required this.place,
    this.won = true,
    this.onSeeOnMap,
    this.onSpinAgain,
  });

  final Place place;

  /// A spin's winner, so the sheet says so.
  final bool won;

  /// Shows the place alone on the map; null leaves the button out.
  final VoidCallback? onSeeOnMap;

  /// Null leaves Spin again out.
  final VoidCallback? onSpinAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VoidCallback? seeOnMap = onSeeOnMap;
    final VoidCallback? spinAgain = onSpinAgain;
    return SingleChildScrollView(
      child: Padding(
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
            PlaceSummary(place: place, won: won),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: () => openInMaps(context, ref, place),
              child: const Text('Open in Google Maps'),
            ),
            if (seeOnMap != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: seeOnMap,
                child: const Text('See it on the map'),
              ),
            ],
            if (spinAgain != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              if (seeOnMap != null)
                TextButton(
                  onPressed: spinAgain,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  child: const Text('Spin again'),
                )
              else
                OutlinedButton(
                  onPressed: spinAgain,
                  child: const Text('Spin again'),
                ),
            ],
            PlaceReviews(place: place),
          ],
        ),
      ),
    );
  }
}

/// The top of a place's card and sheet: a spin's winner says so, then the
/// name, three figures and the hours. [compact] is the card over the map.
class PlaceSummary extends ConsumerWidget {
  const PlaceSummary({
    super.key,
    required this.place,
    required this.won,
    this.compact = false,
  });

  final Place place;
  final bool won;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double? rating = place.rating;
    final DateTime now = ref.read(clockProvider)();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (won) ...<Widget>[
          Text(
            'Today you are eating at',
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Semantics(
          header: true,
          child: Text(
            place.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 21 : 28,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: compact ? -0.2 : -0.4,
              color: AppColors.ink,
            ),
          ),
        ),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
        _Stats(
          cells: <(String, String, bool)>[
            (
              rating == null ? 'None' : rating.toStringAsFixed(1),
              'Rating',
              rating != null,
            ),
            (formatCount(place.reviewCount), 'Reviews', false),
            (formatDistance(place.distanceMetres), 'Away', false),
          ],
        ),
        if (place.hours case final hours?) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              const Icon(
                CupertinoIcons.clock,
                size: 17,
                color: AppColors.muted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  hoursLine(hours, now),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A place's kept reviews, a link to the rest on Google Maps, and the
/// credit Google asks for.
class PlaceReviews extends ConsumerWidget {
  const PlaceReviews({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.read(clockProvider)();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (place.reviews.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xxl),
          Semantics(
            header: true,
            child: const Text(
              'Reviews',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppColors.ink,
              ),
            ),
          ),
          for (final Review r in place.reviews)
            _ReviewTile(
              review: r,
              now: now,
              onReadMore: () => openInMaps(context, ref, place),
            ),
        ],
        // The list keeps a few reviews; Google Maps has them all, in
        // any order, newest first included.
        if (place.reviewCount > place.reviews.length) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => openInMaps(context, ref, place),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 48),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
              child: Text(
                place.reviewCount == 1
                    ? 'Read the review on Google Maps'
                    : 'Read all ${formatCount(place.reviewCount)} reviews on Google Maps',
              ),
            ),
          ),
        ],
        // Places from Google must say so; the demo's are made up.
        if (!demoMode) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Google Maps',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}

/// Three figures side by side in a hairline card, each over its label.
class _Stats extends StatelessWidget {
  const _Stats({required this.cells});

  /// Value, label, and whether the value gets a star before it.
  final List<(String, String, bool)> cells;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: <Widget>[
            for (int i = 0; i < cells.length; i++) ...<Widget>[
              if (i > 0) const VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          if (cells[i].$3) ...<Widget>[
                            const Icon(
                              CupertinoIcons.star_fill,
                              size: 15,
                              color: AppColors.ink,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Flexible(
                            child: Text(
                              cells[i].$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                fontFeatures: <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cells[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One review: its stars, how long ago, and what it says. A review longer
/// than six lines, or cut short in the places list, ends with a link to
/// read the rest on Google Maps.
class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.review,
    required this.now,
    required this.onReadMore,
  });

  final Review review;
  final DateTime now;
  final VoidCallback onReadMore;

  static const int _maxLines = 6;
  static const TextStyle _textStyle = TextStyle(
    fontSize: 15,
    height: 1.45,
    color: AppColors.ink,
  );

  bool _overflows(BuildContext context, double width) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: review.text,
        style: DefaultTextStyle.of(context).style.merge(_textStyle),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: _maxLines,
    )..layout(maxWidth: width);
    final bool cut = tp.didExceedMaxLines;
    tp.dispose();
    return cut;
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? month = review.month;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Semantics(
                  label: '${review.rating} out of 5 stars',
                  child: ExcludeSemantics(
                    child: Row(
                      children: <Widget>[
                        for (int i = 1; i <= 5; i++)
                          Icon(
                            i <= review.rating
                                ? CupertinoIcons.star_fill
                                : CupertinoIcons.star,
                            size: 14,
                            color: AppColors.ink,
                          ),
                      ],
                    ),
                  ),
                ),
                if (month != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      monthsAgo(month, now),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final bool cut =
                    review.mayBeCut || _overflows(context, c.maxWidth);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      review.text,
                      maxLines: _maxLines,
                      overflow: TextOverflow.ellipsis,
                      style: _textStyle,
                    ),
                    if (cut)
                      TextButton(
                        onPressed: onReadMore,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 44),
                          alignment: Alignment.centerLeft,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        child: const Text(
                          'Read the full review on Google Maps',
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
