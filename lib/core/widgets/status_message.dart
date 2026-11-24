import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A title, a line of help and maybe one action, centred: for empty, error
/// and permission states.
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.otherAction,
    this.onOtherAction,
  });

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  /// A quieter second choice under the first.
  final String? otherAction;
  final VoidCallback? onOtherAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                height: 1.25,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                height: 1.45,
                color: AppColors.muted,
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xxl),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
            if (otherAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: onOtherAction, child: Text(otherAction!)),
            ],
          ],
        ),
      ),
    );
  }
}
