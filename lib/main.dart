import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/system_style.dart';
import 'features/places/data/prefs_filters_store.dart';
import 'features/places/presentation/places_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status and navigation bars; screens handle the insets.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(appSystemStyle);
  final SharedPreferencesWithCache prefs =
      await SharedPreferencesWithCache.create(
        cacheOptions: PrefsFiltersStore.options,
      );
  runApp(
    ProviderScope(
      overrides: [
        filtersStoreProvider.overrideWithValue(PrefsFiltersStore(prefs)),
      ],
      child: const MakanManaApp(opening: true),
    ),
  );
}
