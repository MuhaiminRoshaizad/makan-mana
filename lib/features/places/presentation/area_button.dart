import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import 'places_providers.dart';
import 'search_area_sheet.dart';

/// "Within 2 km of you", opening the search area.
class AreaButton extends ConsumerWidget {
  const AreaButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String radius = formatDistance(ref.watch(radiusProvider));
    // The demo searches round Dataran Merdeka, not round the phone.
    final String label = ref.watch(pinProvider) != null
        ? 'Within $radius of your pin'
        : demoMode
        ? 'Within $radius of Dataran Merdeka'
        : 'Within $radius of you';
    return Semantics(
      button: true,
      label: 'Search area, $label',
      excludeSemantics: true,
      child: TextButton(
        onPressed: () => showSearchAreaSheet(context),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.muted,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.fromLTRB(0, 0, AppSpacing.xs, 0),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(CupertinoIcons.location, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Flexible(child: Text(label)),
            const SizedBox(width: AppSpacing.xs),
            const Icon(CupertinoIcons.chevron_right, size: 16),
          ],
        ),
      ),
    );
  }
}
