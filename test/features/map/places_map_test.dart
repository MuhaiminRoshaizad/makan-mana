import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/features/map/presentation/places_map.dart';

void main() {
  test('only the pin alone on the map, a spin winner, shows its name', () {
    // A MapLibre expression: the name when the feature is alone, otherwise
    // nothing, so a tapped pin or a pin at rest has no name under it.
    expect(pinNameField, <Object>[
      'case',
      <Object>['get', 'alone'],
      <Object>['get', 'name'],
      '',
    ]);
  });
}
