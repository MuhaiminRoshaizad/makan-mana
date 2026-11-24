import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/status_message.dart';
import '../domain/location_repository.dart';
import 'location_providers.dart';

/// What to do while there is no position to search round, for each reason.
class LocationMessage extends ConsumerWidget {
  const LocationMessage(this.state, {super.key});

  final LocationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LocationNotifier location = ref.read(locationProvider.notifier);
    return switch (state) {
      RefusedForGood() => StatusMessage(
        title: 'Location is off for Makan Mana',
        body:
            'Allow it in Settings, under Location, to find places to eat near '
            'you.',
        action: 'Open Settings',
        onAction: location.ask,
      ),
      LocationOff() => StatusMessage(
        title: 'Location is turned off',
        body: 'Turn on location to find places to eat near you.',
        action: 'Turn on location',
        onAction: location.ask,
      ),
      PositionUnavailable() => StatusMessage(
        title: "Couldn't tell where you are",
        body: 'Move somewhere with a clearer view of the sky, then try again.',
        action: 'Try again',
        onAction: location.recheck,
      ),
      _ => StatusMessage(
        title: 'Find places near you',
        body:
            'Makan Mana uses where you are to fill the wheel with places '
            'nearby. Your location stays on your phone.',
        action: 'Use my location',
        onAction: location.ask,
      ),
    };
  }
}
