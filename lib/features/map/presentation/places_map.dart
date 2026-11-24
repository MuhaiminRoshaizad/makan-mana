import 'dart:async';
import 'dart:math' show Point;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/wedge_colors.dart';
import '../../places/domain/place.dart';
import '../../places/domain/places_repository.dart';
import 'map_geometry.dart';
import 'pin_images.dart';

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
    required this.you,
    required this.dropPin,
    required this.onPinTap,
    required this.onMapTap,
    required this.onPinDropped,
    this.focus,
    this.focusTick = 0,
    this.ringAt,
    this.ringTick = 0,
  });

  /// The search centre: where the camera comes home to.
  final double latitude;
  final double longitude;

  /// The ring round the search centre; null draws none.
  final int? radiusMetres;

  /// The places on the wheel, in wheel order, so each pin takes its wedge's
  /// colour.
  final List<Place> places;

  /// The place whose pin stands taller: tapped, or lit by a spin.
  final String? selectedId;

  /// Whether the map leans back to show buildings in 3D.
  final bool tilted;

  /// Goes up by one each time the camera should come home.
  final int recentre;

  /// Where the phone is, shown as the blue dot; null hides it.
  final LatLon? you;

  /// The pin dropped to search somewhere else, which can be dragged; null
  /// while searching round the phone.
  final LatLon? dropPin;

  final ValueChanged<String> onPinTap;
  final VoidCallback onMapTap;

  /// Where the dropped pin was let go after a drag.
  final void Function(double latitude, double longitude) onPinDropped;

  /// A place to fly in on, such as a spin's winner, each time [focusTick]
  /// goes up.
  final LatLon? focus;
  final int focusTick;

  /// Where to send out a ring, as on a spin's landing, each time [ringTick]
  /// goes up.
  final LatLon? ringAt;
  final int ringTick;
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

/// How much closer than the whole area the camera goes to show a winner.
const double focusZoomIn = 1.6;

/// Liberty's own restaurant and shop icons, hidden so they do not compete
/// with the places on the wheel.
const List<String> _styleLayersToHide = <String>['poi_r1', 'poi_r7', 'poi_r20'];

/// The blue of the dot that marks the phone, as on every map app.
const Color _youBlue = Color(0xFF2F6FC9);

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
  Timer? _ring;
  Timer? _bounce;

  MapProps get _p => widget.props;
  bool get _still => MediaQuery.disableAnimationsOf(context);

  @override
  void dispose() {
    _ring?.cancel();
    _bounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(PlacesMap old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    final MapProps was = old.props;
    final MapLibreMapController map = _map!;
    if (was.places != _p.places || was.selectedId != _p.selectedId) {
      map.setGeoJsonSource('places', _placesJson());
    }
    final bool moved =
        was.latitude != _p.latitude ||
        was.longitude != _p.longitude ||
        was.radiusMetres != _p.radiusMetres;
    if (moved) map.setGeoJsonSource('area', _areaJson());
    if (was.dropPin != _p.dropPin) {
      map.setGeoJsonSource('drop', _dropJson(_p.dropPin, 0));
    }
    if (was.you != _p.you) _showYou();
    if (moved || was.recentre != _p.recentre) {
      map.animateCamera(
        CameraUpdate.newCameraPosition(_home()),
        duration: _still ? Duration.zero : const Duration(milliseconds: 750),
      );
    } else if (was.tilted != _p.tilted) {
      map.animateCamera(
        CameraUpdate.tiltTo(_p.tilted ? mapTilt : 0),
        duration: _still ? Duration.zero : AppMotion.long,
      );
    }
    if (was.ringTick != _p.ringTick && _p.ringAt != null) _sendRing(_p.ringAt!);
    if (was.focusTick != _p.focusTick && _p.focus != null) {
      final LatLon f = _p.focus!;
      map.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(f.latitude, f.longitude),
            zoom: _home().zoom + focusZoomIn,
            tilt: _p.tilted ? mapTilt : 0,
          ),
        ),
        duration: _still ? Duration.zero : const Duration(milliseconds: 1150),
      );
    }
  }

  CameraPosition _home() => CameraPosition(
    target: LatLng(_p.latitude, _p.longitude),
    zoom: zoomToFit((_p.radiusMetres ?? 2000).toDouble(), _p.latitude, _width),
    tilt: _p.tilted ? mapTilt : 0,
  );

  Future<void> _styleLoaded() async {
    final MapLibreMapController map = _map!;
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    for (final String id in _styleLayersToHide) {
      try {
        await map.setLayerVisibility(id, false);
      } on Object catch (_) {
        // A newer Liberty without that layer: nothing to hide.
      }
    }
    for (int i = 0; i < wedgeColors.length; i++) {
      await _addPin('pin-$i', wedgeColors[i].fill, PinImages.placeSize, dpr);
    }
    await _addPin('pin-drop', AppColors.ink, PinImages.dropSize, dpr);
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
    await map.addGeoJsonSource('places', _placesJson(), promoteId: 'id');
    await map.addSymbolLayer(
      'places',
      'place-pins',
      SymbolLayerProperties(
        iconImage: <Object>['get', 'icon'],
        iconAnchor: 'bottom',
        iconAllowOverlap: true,
        // The chosen place stands taller and lifts off the map.
        iconSize: <Object>[
          'case',
          <Object>['get', 'selected'],
          1.25,
          1.0,
        ],
        iconOffset: <Object>[
          'case',
          <Object>['get', 'selected'],
          <Object>[
            'literal',
            <double>[0, -6],
          ],
          <Object>[
            'literal',
            <double>[0, 0],
          ],
        ],
        textField: <Object>['get', 'name'],
        textFont: <String>['Noto Sans Bold'],
        textSize: 12.5,
        textAnchor: 'top',
        textOffset: <double>[0, 0.35],
        textMaxWidth: 9,
        textOptional: true,
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
    await map.addGeoJsonSource('land', _ringJson(null, 0, 0));
    await map.addCircleLayer(
      'land',
      'land-ring',
      CircleLayerProperties(
        circleRadius: <Object>['get', 'r'],
        circleOpacity: 0,
        circleStrokeColor: _hex(AppColors.ink),
        circleStrokeWidth: 2.5,
        circleStrokeOpacity: <Object>['get', 'o'],
        circlePitchAlignment: 'map',
      ),
      enableInteraction: false,
    );
    await map.addGeoJsonSource('drop', _dropJson(_p.dropPin, 0));
    await map.addSymbolLayer(
      'drop',
      'drop-pin',
      SymbolLayerProperties(
        iconImage: 'pin-drop',
        iconAnchor: 'bottom',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        // Lifted while dragged, then down past the ground and back: the
        // drop's one small bounce.
        iconOffset: <Object>[
          'match',
          <Object>['get', 'stage'],
          1,
          <Object>[
            'literal',
            <double>[0, -14],
          ],
          2,
          <Object>[
            'literal',
            <double>[0, 3],
          ],
          <Object>[
            'literal',
            <double>[0, 0],
          ],
        ],
      ),
    );
    await _showYou();
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _addPin(String name, Color head, Size size, double dpr) async {
    final Uint8List png = await PinImages.draw(
      head: head,
      size: size,
      pixelRatio: dpr,
    );
    await _map!.addImage(name, png, false, dpr);
  }

  Future<void> _showYou() async {
    final LatLon? you = _p.you;
    if (you == null) return;
    await _map?.updateManualLocation(
      ManualLocationUpdate(target: LatLng(you.latitude, you.longitude)),
    );
  }

  void _featureTapped(
    Point<double> point,
    LatLng at,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId == 'place-pins') _p.onPinTap(id);
  }

  void _featureDragged(
    Point<double> point,
    LatLng origin,
    LatLng current,
    LatLng delta,
    String id,
    Annotation? annotation,
    DragEventType type,
  ) {
    if (id != 'drop') return;
    final LatLon at = (
      latitude: current.latitude,
      longitude: current.longitude,
    );
    switch (type) {
      case DragEventType.start:
      case DragEventType.drag:
        _bounce?.cancel();
        _map!.setGeoJsonSource('drop', _dropJson(at, 1));
      case DragEventType.end:
        _p.onPinDropped(at.latitude, at.longitude);
        _land(at);
    }
  }

  /// The dropped pin comes down past the ground, settles, and sends out a
  /// ring where it lands.
  void _land(LatLon at) {
    final MapLibreMapController map = _map!;
    if (_still) {
      map.setGeoJsonSource('drop', _dropJson(at, 0));
      return;
    }
    int step = 0;
    const List<int> stages = <int>[2, 2, 0];
    _bounce?.cancel();
    _bounce = Timer.periodic(const Duration(milliseconds: 90), (Timer t) {
      if (!mounted || step >= stages.length) {
        t.cancel();
        return;
      }
      map.setGeoJsonSource('drop', _dropJson(at, stages[step++]));
    });
    _sendRing(at);
  }

  /// A ring spreading out from [at] and fading, over 700 ms.
  void _sendRing(LatLon at) {
    final MapLibreMapController map = _map!;
    if (_still) return;
    const int frames = 18;
    int frame = 0;
    _ring?.cancel();
    _ring = Timer.periodic(const Duration(milliseconds: 40), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final double k = frame / frames;
      map.setGeoJsonSource(
        'land',
        frame >= frames
            ? _ringJson(null, 0, 0)
            : _ringJson(at, 6 + 34 * k, 0.9 * (1 - k)),
      );
      if (frame++ >= frames) t.cancel();
    });
  }

  Map<String, dynamic> _collection(List<Map<String, dynamic>> features) =>
      <String, dynamic>{'type': 'FeatureCollection', 'features': features};

  Map<String, dynamic> _point(
    LatLon at,
    Map<String, dynamic> props, [
    String? id,
  ]) => <String, dynamic>{
    'type': 'Feature',
    'id': ?id,
    'properties': props,
    'geometry': <String, dynamic>{
      'type': 'Point',
      'coordinates': <double>[at.longitude, at.latitude],
    },
  };

  Map<String, dynamic> _areaJson() => _collection(<Map<String, dynamic>>[
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
  ]);

  Map<String, dynamic> _placesJson() {
    final int n = _p.places.length;
    return _collection(<Map<String, dynamic>>[
      for (final (int i, Place p) in _p.places.indexed)
        // Android and iOS take the id from the feature; the web from
        // promoteId.
        _point(
          (latitude: p.latitude, longitude: p.longitude),
          <String, dynamic>{
            'id': p.id,
            'name': p.name,
            'icon': 'pin-${wedgeColors.indexOf(wedgeColorFor(i, n))}',
            'selected': p.id == _p.selectedId,
          },
          p.id,
        ),
    ]);
  }

  /// The dropped pin at [at], at a [stage] of its drop: 0 resting, 1 lifted,
  /// 2 just past the ground.
  Map<String, dynamic> _dropJson(LatLon? at, int stage) =>
      _collection(<Map<String, dynamic>>[
        if (at != null)
          _point(at, <String, dynamic>{
            'draggable': true,
            'stage': stage,
          }, 'drop'),
      ]);

  Map<String, dynamic> _ringJson(LatLon? at, double radius, double opacity) =>
      _collection(<Map<String, dynamic>>[
        if (at != null)
          _point(at, <String, dynamic>{'r': radius, 'o': opacity}),
      ]);

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
            map.onFeatureDrag.add(_featureDragged);
          },
          onStyleLoadedCallback: _styleLoaded,
          onMapClick: (_, _) => _p.onMapTap(),
          compassEnabled: false,
          // The credit OpenStreetMap asks for when others see the map; the
          // app is for its owner alone (docs/decisions.md 018).
          attributionEnabled: false,
          logoEnabled: false,
          myLocationEnabled: _p.you != null,
          locationSource: const ManualLocationSource(),
          myLocationStyle: const MyLocationStyle(
            fillColor: _youBlue,
            accuracyCircleEnabled: false,
            pulseEnabled: true,
            pulseColor: _youBlue,
          ),
        );
      },
    );
  }
}
