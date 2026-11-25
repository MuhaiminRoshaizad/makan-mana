import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// The Spin button that floats over the wheel and the map. While a spin
/// runs it stays ink but does nothing, so it never flickers grey.
class SpinButton extends StatelessWidget {
  const SpinButton({super.key, required this.onPressed});

  /// Null while a spin is under way, or when there is nothing to spin.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        shape: StadiumBorder(),
        shadows: AppShadows.float,
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
