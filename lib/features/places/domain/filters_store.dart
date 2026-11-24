import 'place_filters.dart';

/// Keeps the filters between launches, so the wheel opens as it was left.
abstract interface class FiltersStore {
  /// Whether the filters have ever been chosen. Until then the wheel stays
  /// empty and asks what the person is after.
  bool get chosen;

  /// The filters last chosen, or null before the first choice.
  PlaceFilters? load();

  Future<void> save(PlaceFilters filters);
}

/// Filters kept only while the app runs.
class MemoryFiltersStore implements FiltersStore {
  MemoryFiltersStore({this.chosen = false, this.saved});

  @override
  bool chosen;
  PlaceFilters? saved;

  @override
  PlaceFilters? load() => saved;

  @override
  Future<void> save(PlaceFilters filters) async {
    saved = filters;
    chosen = true;
  }
}
