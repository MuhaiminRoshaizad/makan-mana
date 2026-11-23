import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import 'filters_sheet.dart';
import 'places_providers.dart';

/// One button for every filter, with a badge counting those in use.
class FiltersButton extends ConsumerWidget {
  const FiltersButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int active = ref.watch(filtersProvider).activeCount;
    return Semantics(
      button: true,
      label: active == 0 ? 'Filters' : 'Filters, $active in use',
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: () => showFiltersSheet(context),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.line),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            0,
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(CupertinoIcons.slider_horizontal_3, size: 18),
            const SizedBox(width: AppSpacing.sm),
            const Text('Filters'),
            if (active > 0) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: const ShapeDecoration(
                  color: AppColors.ink,
                  shape: StadiumBorder(),
                ),
                child: Text(
                  '$active',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.surface,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
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
