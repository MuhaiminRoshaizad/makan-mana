import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/toast.dart';
import '../../places/domain/place.dart';
import '../../places/domain/review.dart';
import '../../places/presentation/hours_text.dart';
import '../../places/presentation/places_providers.dart';

/// Hands a link to the phone; false when nothing could open it.
typedef OpenLink = Future<bool> Function(Uri uri);

final Provider<OpenLink> openLinkProvider = Provider<OpenLink>(
  (Ref ref) =>
      (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// A Google Maps link to [place], by Google's Maps URLs scheme: it opens the
/// Maps app when installed and the website when not. Made-up demo places
/// have no real place ID, so they are searched for by name only.
Uri mapsLinkFor(Place place) => Uri.https('www.google.com', '/maps/search/', {
  'api': '1',
  'query': place.name,
  if (!place.id.startsWith('demo-')) 'query_place_id': place.id,
});

/// Opens [ResultSheet] for [place]. It may grow past the usual 9/16 cap
/// and scrolls, so large system text never cuts off its buttons.
Future<void> showResultSheet(
  BuildContext context, {
  required Place place,
  required VoidCallback onSpinAgain,
}) => showAppSheet<void>(
  context,
  scrollControlled: true,
  builder: (_) => ResultSheet(place: place, onSpinAgain: onSpinAgain),
);

/// Where the wheel landed: the place, how it rates and how far it is, with
/// a way to get there and a way to spin again.
class ResultSheet extends ConsumerWidget {
  const ResultSheet({
    super.key,
    required this.place,
    required this.onSpinAgain,
  });

  final Place place;
  final VoidCallback onSpinAgain;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    final bool opened = await ref.read(openLinkProvider)(mapsLinkFor(place));
    if (!opened && context.mounted) {
      showToast(
        context,
        "Couldn't open Google Maps",
        failed: true,
        overlay: overlay,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double? rating = place.rating;
    final DateTime now = ref.read(clockProvider)();
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
            const Text(
              'Today you are eating at',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              header: true,
              child: Text(
                place.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
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
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: () => _open(context, ref),
              child: const Text('Open in Google Maps'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: onSpinAgain,
              child: const Text('Spin again'),
            ),
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
                _ReviewTile(review: r, now: now),
            ],
            // The list keeps a few reviews; Google Maps has them all, in
            // any order, newest first included.
            if (place.reviewCount > place.reviews.length) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _open(context, ref),
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
        ),
      ),
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

/// One review: its stars, how long ago, and what it says.
class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.now});

  final Review review;
  final DateTime now;

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
            Text(
              review.text,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
