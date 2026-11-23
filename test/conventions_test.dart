import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Dart file under lib, as (path with / separators, source).
List<(String, String)> _sources() => <(String, String)>[
  for (final FileSystemEntity f in Directory('lib').listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart'))
      (f.path.replaceAll(r'\', '/'), f.readAsStringSync()),
];

/// Files whose source matches [pattern], other than those ending in one of
/// [allowedIn].
List<String> _offenders(
  Pattern pattern, {
  List<String> allowedIn = const <String>[],
}) => <String>[
  for (final (String path, String source) in _sources())
    if (!allowedIn.any(path.endsWith) && source.contains(pattern)) path,
];

void main() {
  test('bottom sheets open only through showAppSheet', () {
    // showModalBottomSheet draws under the system navigation bar and, from a
    // tab, under the floating bar; the helper fixes both.
    expect(
      _offenders(
        'showModalBottomSheet',
        allowedIn: <String>['core/widgets/app_sheet.dart'],
      ),
      isEmpty,
    );
  });

  test('icons come from CupertinoIcons, never Material Icons', () {
    expect(_offenders(RegExp(r'(?<!Cupertino)\bIcons\.')), isEmpty);
  });

  test('messages use the top toast, never a SnackBar', () {
    expect(_offenders('showSnackBar('), isEmpty);
  });
}
