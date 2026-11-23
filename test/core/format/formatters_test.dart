import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/core/format/formatters.dart';

void main() {
  test('distances read in metres under a kilometre, then kilometres', () {
    expect(formatDistance(0), '0 m');
    expect(formatDistance(350), '350 m');
    expect(formatDistance(999), '999 m');
    expect(formatDistance(1000), '1 km');
    expect(formatDistance(1100), '1.1 km');
    expect(formatDistance(1960), '2 km');
    expect(formatDistance(12345), '12.3 km');
  });

  test('counts get a thousands separator', () {
    expect(formatCount(0), '0');
    expect(formatCount(420), '420');
    expect(formatCount(5420), '5,420');
    expect(formatCount(1234567), '1,234,567');
    expect(formatCount(-1200), '-1,200');
  });
}
