import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/wedge_colors.dart';
import '../../places/domain/place.dart';
import 'map_geometry.dart';

/// Everything the map shows, so the screen can say what it wants and the
/// map works out what to change.
class MapProps {
  const MapProps({
    required this.latitude,
    required this.longitude,
    required this.radiusMetres,
    required this.places,
    required this.selectedId,
    required this.tilted,
    required this.recentre,
    required this.bottomInset,
    required this.onPinTap,
    required this.onMapTap,
    required this.onMoved,
  });

  /// The search centre, or while choosing a spot, where the map starts.
  final double latitude;
  final double longitude;

  /// Null while choosing a spot: there is no area to draw yet.
  final int? radiusMetres;

  /// The places on the wheel, in wheel order, so each pin takes its wedge's
  /// colour.
  final List<Place> places;
  final String? selectedId;

  /// Whether the map leans back to show buildings in 3D.
  final bool tilted;

  /// Goes up by one each time the camera should return to the centre.
  final int recentre;

  /// How much of the map's foot the floating bar covers, so the attribution
  /// stays clear of it.
  final double bottomInset;

  final ValueChanged<String> onPinTap;
  final VoidCallback onMapTap;

  /// Where the middle of the map came to rest after a move.
  final void Function(double latitude, double longitude) onMoved;
}

typedef MapViewBuilder = Widget Function(MapProps props);

/// Builds the map. Widget tests swap in a stand-in, since MapLibre draws in
/// a native view that tests cannot host.
final Provider<MapViewBuilder> mapViewProvider = Provider<MapViewBuilder>(
  (Ref ref) =>
      (MapProps props) => PlacesMap(props: props),
);

/// OpenFreeMap's Liberty style: free, without a key, with 3D buildings from
/// zoom 14 (docs/decisions.md 018).
const String mapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

/// The angle the map leans back to in 3D, in degrees.
const double mapTilt = 50;

/// Liberty's own restaurant and shop icons, hidden so they do not compete
/// with the places on the wheel.
const List<String> _styleLayersToHide = <String>['poi_r1', 'poi_r7', 'poi_r20'];

/// The map of the places on the wheel, drawn by MapLibre.
class PlacesMap extends StatefulWidget {
  const PlacesMap({super.key, required this.props});

  final MapProps props;

  @override
  State<PlacesMap> createState() => _PlacesMapState();
}

class _PlacesMapState extends State<PlacesMap> {
  MapLibreMapController? _map;
  bool _ready = false;
  double _width = 400;

  MapProps get _p => widget.props;

  @override
  void didUpdateWidget(PlacesMap old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    final MapProps was = old.props;
    if (was.places != _p.places || was.selectedId != _p.selectedId) {
      _map!.setGeoJsonSource('places', _placesJson());
    }
    final bool moved =
        was.latitude != _p.latitude ||
        was.longitude != _p.longitude ||
        was.radiusMetres != _p.radiusMetres;
    if (moved) {
      _map!.setGeoJsonSource('area', _areaJson());
      _map!.setGeoJsonSource('you', _youJson());
    }
    if (moved || was.recentre != _p.recentre) {
      _map!.animateCamera(
        CameraUpdate.newCameraPosition(_home()),
        duration: AppMotion.long * 2,
      );
    } else if (was.tilted != _p.tilted) {
      _map!.animateCamera(
        CameraUpdate.tiltTo(_p.tilted ? mapTilt : 0),
        duration: AppMotion.long,
      );
    }
  }

  /// Choosing a spot starts at the zoom a 2 km area would have.
  CameraPosition _home() => CameraPosition(
    target: LatLng(_p.latitude, _p.longitude),
    zoom: zoomToFit((_p.radiusMetres ?? 2000).toDouble(), _p.latitude, _width),
    tilt: _p.tilted ? mapTilt : 0,
  );

  void _idle() {
    final LatLng? at = _map?.cameraPosition?.target;
    if (at != null) _p.onMoved(at.latitude, at.longitude);
  }

  Future<void> _styleLoaded() async {
    final MapLibreMapController map = _map!;
    for (final String id in _styleLayersToHide) {
      try {
        await map.setLayerVisibility(id, false);
      } on Object catch (_) {
        // A newer Liberty without that layer: nothing to hide.
      }
    }
    await map.addGeoJsonSource('area', _areaJson());
    await map.addFillLayer(
      'area',
      'area-fill',
      FillLayerProperties(fillColor: _hex(AppColors.ink), fillOpacity: 0.05),
      enableInteraction: false,
    );
    await map.addLineLayer(
      'area',
      'area-line',
      LineLayerProperties(lineColor: _hex(AppColors.ink), lineWidth: 2.5),
      enableInteraction: false,
    );
    await map.addGeoJsonSource('you', _youJson());
    await map.addCircleLayer(
      'you',
      'you-dot',
      CircleLayerProperties(
        circleRadius: 8,
        circleColor: _hex(AppColors.ink),
        circleStrokeColor: _hex(AppColors.surface),
        circleStrokeWidth: 4,
        circlePitchAlignment: 'map',
      ),
      enableInteraction: false,
    );
    await map.addGeoJsonSource('places', _placesJson(), promoteId: 'id');
    await map.addCircleLayer(
      'places',
      'place-dots',
      CircleLayerProperties(
        circleRadius: <Object>[
          'case',
          <Object>['get', 'selected'],
          12,
          9,
        ],
        circleColor: <Object>['get', 'color'],
        circleStrokeColor: _hex(AppColors.surface),
        circleStrokeWidth: 3,
      ),
    );
    await map.addSymbolLayer(
      'places',
      'place-names',
      SymbolLayerProperties(
        textField: <Object>['get', 'name'],
        textFont: <String>['Noto Sans Bold'],
        textSize: 13,
        textAnchor: 'top',
        textOffset: <double>[0, 1.1],
        textMaxWidth: 9,
        textColor: _hex(AppColors.ink),
        textHaloColor: _hex(AppColors.surface),
        textHaloWidth: 1.6,
        // The chosen place's name wins when labels collide.
        symbolSortKey: <Object>[
          'case',
          <Object>['get', 'selected'],
          0,
          1,
        ],
      ),
    );
    if (mounted) setState(() => _ready = true);
  }

  void _featureTapped(
    Point<double> point,
    LatLng at,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId == 'place-dots' || layerId == 'place-names') _p.onPinTap(id);
  }

  Map<String, dynamic> _areaJson() => <String, dynamic>{
    'type': 'FeatureCollection',
    'features': <Map<String, dynamic>>[
      if (_p.radiusMetres case final int radius)
        <String, dynamic>{
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': <String, dynamic>{
            'type': 'Polygon',
            'coordinates': <List<List<double>>>[
              circleRing(_p.latitude, _p.longitude, radius.toDouble()),
            ],
          },
        },
    ],
  };

  Map<String, dynamic> _youJson() => <String, dynamic>{
    'type': 'FeatureCollection',
    'features': <Map<String, dynamic>>[
      if (_p.radiusMetres != null)
        <String, dynamic>{
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': <String, dynamic>{
            'type': 'Point',
            'coordinates': <double>[_p.longitude, _p.latitude],
          },
        },
    ],
  };

  Map<String, dynamic> _placesJson() {
    final int n = _p.places.length;
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[
        for (final (int i, Place p) in _p.places.indexed)
          <String, dynamic>{
            'type': 'Feature',
            // Android and iOS take the id from here; the web from promoteId.
            'id': p.id,
            'properties': <String, dynamic>{
              'id': p.id,
              'name': p.name,
              'color': _hex(wedgeColorFor(i, n).fill),
              'selected': p.id == _p.selectedId,
            },
            'geometry': <String, dynamic>{
              'type': 'Point',
              'coordinates': <double>[p.longitude, p.latitude],
            },
          },
      ],
    };
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        _width = c.maxWidth;
        return MapLibreMap(
          styleString: mapStyleUrl,
          initialCameraPosition: _home(),
          onMapCreated: (MapLibreMapController map) {
            _map = map;
            map.onFeatureTapped.add(_featureTapped);
          },
          onStyleLoadedCallback: _styleLoaded,
          onMapClick: (_, _) => _p.onMapTap(),
          trackCameraPosition: true,
          onCameraIdle: _idle,
          compassEnabled: false,
          attributionButtonPosition: AttributionButtonPosition.bottomLeft,
          attributionButtonMargins: Point<double>(
            AppSpacing.md,
            _p.bottomInset,
          ),
        );
      },
    );
  }
}
