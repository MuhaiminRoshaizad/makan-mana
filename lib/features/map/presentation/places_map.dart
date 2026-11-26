import 'dart:async';
import 'dart:math' show Point;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
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
    this.aloneId,
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

  /// The one place left on the map, as when a wheel's winner is seen on
  /// it; the other pins shrink away. Null shows them all.
  final String? aloneId;
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

class _PlacesMapState extends State<PlacesMap>
    with SingleTickerProviderStateMixin {
  MapLibreMapController? _map;
  bool _ready = false;
  double _width = 400;
  Timer? _ring;
  Timer? _bounce;

  /// Pins on the move: the chosen one springs up on the app's spring and
  /// the one it replaced settles back. They are drawn on their own layer,
  /// so each frame sends one or two points rather than every place.
  late final Ticker _ticker = createTicker(_tick);
  final Map<String, _Lift> _lifts = <String, _Lift>{};

  /// How much of the other pins shows while one place is alone: 1 all, 0
  /// none.
  double _others = 1;
  double _othersFrom = 1;
  double _othersTo = 1;
  Duration? _othersStart;
  Duration _now = Duration.zero;

  /// What the map still has to be told. Only one update is in flight at a
  /// time and the next one carries the latest state, so a slow map skips
  /// frames instead of queueing them behind a tap.
  bool _sending = false;
  bool _sendChosen = false;
  bool _sendPlaces = false;
  bool _sendLayer = false;

  MapProps get _p => widget.props;
  bool get _still => MediaQuery.disableAnimationsOf(context);

  @override
  void dispose() {
    _ring?.cancel();
    _bounce?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  /// Springs [id] up to stand chosen, and lets the pin chosen before settle.
  void _choose(String? id, String? was) {
    if (was != null && was != id) {
      final _Lift? old = _lifts[was];
      if (old != null) old.to(0, _now);
    }
    if (id != null) {
      (_lifts[id] ??= _Lift()).to(1, _now);
    }
    if (_still) {
      _lifts.removeWhere((String _, _Lift l) => l.target == 0);
      for (final _Lift l in _lifts.values) {
        l.settle();
      }
    }
    _sendMoving();
  }

  void _hideOthers(bool hide) {
    final double to = hide ? 0 : 1;
    if (_othersTo == to) return;
    _othersFrom = _others;
    _othersTo = to;
    _othersStart = null;
    if (_still) {
      _others = to;
      _sendLayer = true;
      _flush();
      return;
    }
    _sendMoving();
  }

  void _sendMoving() {
    final bool moving =
        _lifts.values.any((_Lift l) => !l.done) || _others != _othersTo;
    if (moving && !_ticker.isActive) _ticker.start();
    _sendChosen = true;
    _sendPlaces = true;
    _flush();
  }

  Future<void> _flush() async {
    final MapLibreMapController? map = _map;
    if (map == null || _sending) return;
    _sending = true;
    try {
      while (mounted && (_sendChosen || _sendPlaces || _sendLayer)) {
        final bool chosen = _sendChosen;
        final bool places = _sendPlaces;
        final bool layer = _sendLayer;
        _sendChosen = _sendPlaces = _sendLayer = false;
        await Future.wait(<Future<void>>[
          if (chosen) map.setGeoJsonSource('chosen', _chosenJson()),
          if (places) map.setGeoJsonSource('places', _placesJson()),
          if (layer) map.setLayerProperties('place-pins', _pinLayer()),
        ]);
      }
    } finally {
      _sending = false;
    }
  }

  void _tick(Duration now) {
    _now = now;
    final MapLibreMapController? map = _map;
    if (map == null || !mounted) return;
    bool moving = false;
    for (final _Lift l in _lifts.values) {
      l.at(now);
      moving |= !l.done;
    }
    // Settled pins that went back to rest return to the main layer.
    final int before = _lifts.length;
    _lifts.removeWhere((String _, _Lift l) => l.done && l.target == 0);
    _sendChosen = true;
    if (_lifts.length != before) _sendPlaces = true;
    if (_others != _othersTo) {
      final Duration start = _othersStart ??= now;
      final double t = ((now - start).inMicroseconds / 320000).clamp(0, 1);
      final Curve curve = _othersTo < _othersFrom
          ? AppMotion.exit
          : AppMotion.enter;
      _others = _othersFrom + (_othersTo - _othersFrom) * curve.transform(t);
      if (t >= 1) _others = _othersTo;
      _sendLayer = true;
      moving |= _others != _othersTo;
    }
    _flush();
    if (!moving) _ticker.stop();
  }

  @override
  void didUpdateWidget(PlacesMap old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    final MapProps was = old.props;
    final MapLibreMapController map = _map!;
    if (was.selectedId != _p.selectedId) {
      _choose(_p.selectedId, was.selectedId);
    } else if (was.places != _p.places) {
      map.setGeoJsonSource('places', _placesJson());
      map.setGeoJsonSource('chosen', _chosenJson());
    }
    if (was.aloneId != _p.aloneId) {
      map.setGeoJsonSource('places', _placesJson());
      _hideOthers(_p.aloneId != null);
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
    if (was.focusTick != _p.focusTick && _p.focus != null) _flyIn(_p.focus!);
  }

  void _flyIn(LatLon f) {
    _map?.animateCamera(
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
    await map.addSymbolLayer('places', 'place-pins', _pinLayer());
    await map.addGeoJsonSource('chosen', _chosenJson());
    await map.addSymbolLayer('chosen', 'chosen-pins', _chosenLayer());
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
    _others = _othersTo = _p.aloneId == null ? 1 : 0;
    await map.setLayerProperties('place-pins', _pinLayer());
    if (_p.selectedId case final String id) {
      _lifts[id] = _Lift()..settleAt(1);
      await map.setGeoJsonSource('places', _placesJson());
      await map.setGeoJsonSource('chosen', _chosenJson());
    }
    // A place sent from the wheel can arrive before the map is ready, as
    // when it opens the Map tab for the first time: fly in on it now.
    if (_p.aloneId != null) {
      if (_p.focus case final LatLon f) _flyIn(f);
      if (_p.ringAt case final LatLon at) _sendRing(at);
    }
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

  Map<String, dynamic> _placeProps(int i, Place p) => <String, dynamic>{
    'id': p.id,
    'name': p.name,
    'icon': 'pin-${wedgeColors.indexOf(wedgeColorFor(i, _p.places.length))}',
  };

  Map<String, dynamic> _placesJson() => _collection(<Map<String, dynamic>>[
    for (final (int i, Place p) in _p.places.indexed)
      // Android and iOS take the id from the feature; the web from
      // promoteId.
      _point(
        (latitude: p.latitude, longitude: p.longitude),
        <String, dynamic>{
          ..._placeProps(i, p),
          // A pin on the move is drawn on the chosen layer instead.
          'moving': _lifts.containsKey(p.id),
          'alone': p.id == _p.aloneId,
        },
        p.id,
      ),
  ]);

  /// The pins on the move, each with how far it stands up: 0 at rest, 1
  /// chosen, a little past 1 as the spring overshoots.
  Map<String, dynamic> _chosenJson() => _collection(<Map<String, dynamic>>[
    for (final (int i, Place p) in _p.places.indexed)
      if (_lifts[p.id] case final _Lift lift)
        _point(
          (latitude: p.latitude, longitude: p.longitude),
          <String, dynamic>{
            ..._placeProps(i, p),
            'lift': lift.value,
            'rising': lift.target == 1,
          },
          p.id,
        ),
  ]);

  /// The pins at rest. While one place is alone the others shrink and fade
  /// by [_others].
  SymbolLayerProperties _pinLayer() {
    final double k = _others;
    return SymbolLayerProperties(
      iconImage: <Object>['get', 'icon'],
      iconAnchor: 'bottom',
      iconAllowOverlap: true,
      iconSize: <Object>[
        'case',
        <Object>['get', 'alone'],
        1.0,
        0.4 + 0.6 * k,
      ],
      iconOpacity: <Object>[
        'case',
        <Object>['get', 'moving'],
        0.0,
        <Object>['get', 'alone'],
        1.0,
        k,
      ],
      textOpacity: <Object>[
        'case',
        <Object>['get', 'moving'],
        0.0,
        <Object>['get', 'alone'],
        1.0,
        k,
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
    );
  }

  /// The pins on the move, standing taller and lifted off the map by their
  /// spring. A rising pin keeps its name in full; a pin settling back fades
  /// its name with its height, so it does not cover the rising one's.
  SymbolLayerProperties _chosenLayer() => SymbolLayerProperties(
    iconImage: <Object>['get', 'icon'],
    iconAnchor: 'bottom',
    iconAllowOverlap: true,
    iconIgnorePlacement: true,
    iconSize: <Object>[
      'interpolate',
      <Object>['linear'],
      <Object>['get', 'lift'],
      0,
      1.0,
      1.5,
      1.375,
    ],
    iconOffset: <Object>[
      'interpolate',
      <Object>['linear'],
      <Object>['get', 'lift'],
      0,
      <Object>[
        'literal',
        <double>[0, 0],
      ],
      1.5,
      <Object>[
        'literal',
        <double>[0, -9],
      ],
    ],
    textField: <Object>['get', 'name'],
    textFont: <String>['Noto Sans Bold'],
    textSize: 12.5,
    textAnchor: 'top',
    textOffset: <double>[0, 0.35],
    textMaxWidth: 9,
    textAllowOverlap: true,
    textOpacity: <Object>[
      'case',
      <Object>['get', 'rising'],
      1.0,
      <Object>[
        'interpolate',
        <Object>['linear'],
        <Object>['get', 'lift'],
        0.3,
        0.0,
        0.8,
        1.0,
      ],
    ],
    textColor: _hex(AppColors.ink),
    textHaloColor: _hex(AppColors.surface),
    textHaloWidth: 1.6,
  );

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

/// One pin's spring, on [AppMotion.spring]: slightly under-damped, so a
/// chosen pin passes its height a little and settles.
class _Lift {
  double value = 0;
  double target = 0;
  SpringSimulation? _sim;
  Duration? _start;
  Duration _from = Duration.zero;
  bool done = true;

  void to(double next, Duration now) {
    target = next;
    _sim = SpringSimulation(
      AppMotion.spring,
      value,
      next,
      _sim?.dx(_seconds(now)) ?? 0,
    );
    _from = now;
    _start = null;
    done = false;
  }

  void settle() => settleAt(target);

  void settleAt(double v) {
    value = target = v;
    _sim = null;
    done = true;
  }

  double _seconds(Duration now) =>
      (now - (_start ?? _from)).inMicroseconds / 1e6;

  void at(Duration now) {
    final SpringSimulation? sim = _sim;
    if (sim == null) return;
    _start ??= now;
    final double t = _seconds(now);
    value = sim.x(t);
    if (sim.isDone(t)) settleAt(target);
  }
}
