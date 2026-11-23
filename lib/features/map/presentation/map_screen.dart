import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// The Map tab. It holds the title until the map lands here.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          0,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            'Map',
            style: TextStyle(
              fontSize: 34,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
