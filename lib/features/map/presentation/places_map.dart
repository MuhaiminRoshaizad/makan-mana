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
  Size _size = const Size(412, 915);
  Timer? _ring;

  /// Pins springing up or settling back. Flutter draws each one over the
  /// map at its spot, frame by frame, and hands it back to the map once it
  /// is still. Moved inside the map instead, with a GeoJSON update a frame,
  /// a pin showed about ten steps a second on a Pixel 9 Pro.
  late final Ticker _ticker = createTicker(_tick);
  final Map<String, _Float> _floats = <String, _Float>{};

  /// Chosen pins at rest, which the map draws lifted on its chosen layer.
  final Set<String> _raised = <String>{};

  /// How much of the other pins shows while one place is alone: 1 all, 0
  /// none.
  double _others = 1;
  double _othersFrom = 1;
  double _othersTo = 1;
  Duration? _othersStart;
  Duration _now = Duration.zero;

  /// What the map still has to be told. Only one update is in flight at a
  /// time and the next one carries the latest state.
  bool _sending = false;
  bool _sendChosen = false;
  bool _sendPlaces = false;
  bool _sendLayer = false;

  MapProps get _p => widget.props;
  bool get _still => MediaQuery.disableAnimationsOf(context);

  @override
  void dispose() {
    _ring?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  /// Springs [id] up to stand chosen, and lets the pin chosen before settle.
  /// With [cameraMoves], as when closing a winner's card flies the camera
  /// out, the pins skip the spring: Flutter's copy would stay where the pin
  /// stood on screen while the map moved under it.
  Future<void> _choose(
    String? id,
    String? was, {
    bool cameraMoves = false,
  }) async {
    final List<String> moving = <String>[];
    if (was != null && was != id) {
      final bool up = _raised.remove(was) || _floats.containsKey(was);
      if (up) {
        (_floats[was] ??= _Float(1)).aim(0, _now);
        moving.add(was);
      }
    }
    if (id != null) {
      _raised.remove(id);
      (_floats[id] ??= _Float(0)).aim(1, _now);
      moving.add(id);
    }
    if (_still || cameraMoves) {
      _floats.clear();
      if (id != null) _raised.add(id);
      _sendChosen = _sendPlaces = true;
      _flush();
      setState(() {});
      return;
    }
    // Where the pins stand on screen first, so the map hides each one only
    // once Flutter can draw it in its place.
    await _locate(moving);
    if (!mounted) return;
    _sendChosen = _sendPlaces = true;
    _flush();
    if (!_ticker.isActive) _ticker.start();
  }

  Future<void> _locate(List<String> ids) async {
    final MapLibreMapController? map = _map;
    final List<Place> places = <Place>[
      for (final String id in ids) ..._p.places.where((Place p) => p.id == id),
    ];
    if (map == null || places.isEmpty) return;
    final List<Point<num>> at = await map.toScreenLocationBatch(<LatLng>[
      for (final Place p in places) LatLng(p.latitude, p.longitude),
    ]);
    if (!mounted) return;
    setState(() {
      for (final (int i, Place p) in places.indexed) {
        _floats[p.id]?.at = Offset(at[i].x.toDouble(), at[i].y.toDouble());
      }
    });
  }

  /// The camera has started to move: every pin Flutter is drawing goes
  /// straight back to the map in its final pose, so it moves with the map.
  void _settleFloats() {
    if (_floats.isEmpty) return;
    for (final MapEntry<String, _Float> e in _floats.entries) {
      if (e.value.lift.target == 1) {
        _raised.add(e.key);
      } else {
        _raised.remove(e.key);
      }
    }
    setState(_floats.clear);
    _sendChosen = _sendPlaces = true;
    _flush();
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
    if (!_ticker.isActive) _ticker.start();
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
    if (_map == null || !mounted) return;
    bool moving = false;
    for (final MapEntry<String, _Float> e in _floats.entries) {
      final _Float f = e.value;
      if (f.landing) continue;
      f.lift.at(now);
      if (f.lift.done) {
        _rest(e.key, f);
      } else {
        moving = true;
      }
    }
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
    setState(() {});
    if (!moving) _ticker.stop();
  }

  /// A pin that has come to rest goes back to the map. Flutter's copy stays
  /// a moment longer, on top of the map's, so the hand-over shows no gap.
  void _rest(String id, _Float f) {
    f.landing = true;
    if (f.lift.target == 1) _raised.add(id);
    _sendChosen = _sendPlaces = true;
    Timer(const Duration(milliseconds: 220), () {
      if (!mounted || _floats[id] != f || !f.landing) return;
      setState(() => _floats.remove(id));
    });
  }

  @override
  void didUpdateWidget(PlacesMap old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    final MapProps was = old.props;
    final MapLibreMapController map = _map!;
    final bool moved =
        was.latitude != _p.latitude ||
        was.longitude != _p.longitude ||
        was.radiusMetres != _p.radiusMetres;
    if (was.selectedId != _p.selectedId) {
      final String? id = _p.selectedId;
      final String? before = was.selectedId;
      if (was.focusTick != _p.focusTick && !_still) {
        // Flying in, the pin's spot on screen is known once the camera
        // has stopped.
        Timer(const Duration(milliseconds: 1200), () {
          if (mounted && _p.selectedId == id) _choose(id, before);
        });
      } else {
        _choose(id, before, cameraMoves: moved || was.recentre != _p.recentre);
      }
    } else if (was.places != _p.places) {
      map.setGeoJsonSource('places', _placesJson());
      map.setGeoJsonSource('chosen', _chosenJson());
    }
    if (was.aloneId != _p.aloneId) {
      map.setGeoJsonSource('places', _placesJson());
      _hideOthers(_p.aloneId != null);
    }
    if (moved) map.setGeoJsonSource('area', _areaJson());
    // Into Pin mode: the map slides so the spot sits under the centre pin.
    final LatLon? pin = _p.dropPin;
    final bool pinMode = pin != null;
    if (was.dropPin == null && pin != null) {
      map.animateCamera(
        CameraUpdate.newLatLng(LatLng(pin.latitude, pin.longitude)),
        duration: _still ? Duration.zero : AppMotion.long,
      );
    }
    if (was.you != _p.you) _showYou();
    // Other places listed, as after a change of filters: frame them, unless
    // a card is open.
    final bool relisted =
        !_sameIds(was.places, _p.places) &&
        _p.selectedId == null &&
        _p.aloneId == null;
    // In Pin mode the search follows the map, so the camera stays where
    // it was moved to.
    if (((moved || relisted) && !pinMode) || was.recentre != _p.recentre) {
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

  /// Where the camera comes home to: every listed place, and you, inside
  /// the part of the map clear of the buttons over it. With nothing listed,
  /// the search ring instead.
  CameraPosition _home() {
    final List<LatLon> points = <LatLon>[
      for (final Place p in _p.places)
        (latitude: p.latitude, longitude: p.longitude),
      ?_p.you,
    ];
    if (_p.places.isEmpty) {
      return CameraPosition(
        target: LatLng(_p.latitude, _p.longitude),
        zoom: zoomToFit(
          (_p.radiusMetres ?? 2000).toDouble(),
          _p.latitude,
          _size.width,
        ),
        tilt: _p.tilted ? mapTilt : 0,
      );
    }
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final MapView v = frame(
      points,
      _size,
      clear: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        // The filters button and the round buttons beside it.
        safe.top + 150,
        AppSpacing.xl,
        // Spin, and the tab bar under it.
        AppNavMetrics.clearance(safe.bottom) + 56 + AppSpacing.lg,
      ),
    );
    return CameraPosition(
      target: LatLng(v.latitude, v.longitude),
      zoom: v.zoom,
      tilt: _p.tilted ? mapTilt : 0,
    );
  }

  static bool _sameIds(List<Place> a, List<Place> b) =>
      a.length == b.length &&
      a.map((Place p) => p.id).toSet().containsAll(b.map((Place p) => p.id));

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
    await _showYou();
    _others = _othersTo = _p.aloneId == null ? 1 : 0;
    await map.setLayerProperties('place-pins', _pinLayer());
    if (_p.selectedId case final String id) {
      _raised.add(id);
      await map.setGeoJsonSource('places', _placesJson());
      await map.setGeoJsonSource('chosen', _chosenJson());
    }
    // The places usually arrive before the map is ready, when the camera
    // could only frame the search ring: frame them now.
    if (_p.aloneId == null && _p.places.isNotEmpty) {
      await map.moveCamera(CameraUpdate.newCameraPosition(_home()));
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

  /// In Pin mode, once the map has stopped, the spot under the centre pin
  /// becomes where to search.
  Future<void> _readCentre() async {
    final LatLon? pin = _p.dropPin;
    final MapLibreMapController? map = _map;
    if (pin == null || map == null) return;
    final LatLng at = await map.toLatLng(
      Point<double>(_size.width / 2, _size.height / 2),
    );
    if (!mounted || _p.dropPin == null) return;
    // Rounding in the camera moves the centre by a hair; only a real move
    // starts a new search.
    if (distanceMetres(pin.latitude, pin.longitude, at.latitude, at.longitude) <
        2) {
      return;
    }
    _p.onPinDropped(at.latitude, at.longitude);
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
          // A raised pin is drawn on the chosen layer, a springing one by
          // Flutter over the map.
          'raised': _raised.contains(p.id),
          'floating': _floats.containsKey(p.id) && !_raised.contains(p.id),
          'alone': p.id == _p.aloneId,
        },
        p.id,
      ),
  ]);

  /// The chosen pins at rest, which stand lifted.
  Map<String, dynamic> _chosenJson() => _collection(<Map<String, dynamic>>[
    for (final (int i, Place p) in _p.places.indexed)
      if (_raised.contains(p.id))
        _point(
          (latitude: p.latitude, longitude: p.longitude),
          _placeProps(i, p),
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
        <Object>[
          'any',
          <Object>['get', 'raised'],
          <Object>['get', 'floating'],
        ],
        0.0,
        <Object>['get', 'alone'],
        1.0,
        k,
      ],
      textOpacity: <Object>[
        'case',
        <Object>['get', 'raised'],
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

  /// The chosen pins, standing taller and lifted off the map, as Flutter's
  /// copy ends its spring.
  SymbolLayerProperties _chosenLayer() => SymbolLayerProperties(
    iconImage: <Object>['get', 'icon'],
    iconAnchor: 'bottom',
    iconAllowOverlap: true,
    iconIgnorePlacement: true,
    iconSize: _raisedScale,
    iconOffset: <double>[0, -_raisedLift / _raisedScale],
    textField: <Object>['get', 'name'],
    textFont: <String>['Noto Sans Bold'],
    textSize: 12.5,
    textAnchor: 'top',
    textOffset: <double>[0, 0.35],
    textMaxWidth: 9,
    textAllowOverlap: true,
    textColor: _hex(AppColors.ink),
    textHaloColor: _hex(AppColors.surface),
    textHaloWidth: 1.6,
  );

  /// How much taller a chosen pin stands, and how far it lifts, in logical
  /// pixels: the same for the map's copy and Flutter's.
  static const double _raisedScale = 1.25;
  static const double _raisedLift = 7.5;

  /// A springing pin, drawn by Flutter where the map would draw it.
  Widget _floatingPin(String id, _Float f) {
    final Offset? at = f.at;
    final int i = _p.places.indexWhere((Place p) => p.id == id);
    if (at == null || i < 0) return const SizedBox.shrink();
    final Size size = PinImages.placeSize;
    final double v = f.lift.value;
    return Positioned(
      left: at.dx - size.width / 2,
      top: at.dy - size.height,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        child: Transform.translate(
          offset: Offset(0, -_raisedLift * v),
          child: Transform.scale(
            scale: 1 + (_raisedScale - 1) * v,
            alignment: Alignment.bottomCenter,
            child: CustomPaint(
              size: size,
              painter: PinPainter(wedgeColorFor(i, _p.places.length).fill),
            ),
          ),
        ),
      ),
    );
  }

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
        _size = c.biggest;
        final Widget map = MapLibreMap(
          styleString: mapStyleUrl,
          initialCameraPosition: _home(),
          onMapCreated: (MapLibreMapController map) {
            _map = map;
            map.onFeatureTapped.add(_featureTapped);
          },
          onStyleLoadedCallback: _styleLoaded,
          onCameraMoveStarted: (_) => _settleFloats(),
          onCameraIdle: _readCentre,
          onMapClick: (_, _) => _p.onMapTap(),
          compassEnabled: false,
          // MapLibre holds back a single tap until the double-tap timeout,
          // to see whether a second tap makes it a zoom, so every pin tap
          // waited for it. Without double-tap zoom the plugin reports a tap
          // on touch-up (MapLibreMapController.reportsTapsOnTouchUp, and
          // MapLibreMapBuilder applies this on Android despite the web-only
          // note). Pinch still zooms.
          doubleClickZoomEnabled: false,
          // With transitions on, MapLibre places symbols at most once every
          // 300 ms and fades them in. Off, a pin Flutter hands back to the
          // map shows the frame its data arrives, with no fade.
          symbolPlacementTransitionsEnabled: false,
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
        return Stack(
          children: <Widget>[
            Positioned.fill(child: map),
            for (final MapEntry<String, _Float> e in _floats.entries)
              _floatingPin(e.key, e.value),
          ],
        );
      },
    );
  }
}

/// A pin Flutter animates over the map: its spring, and where it stands on
/// screen once known.
class _Float {
  _Float(double from) : lift = _Lift()..settleAt(from);

  final _Lift lift;
  Offset? at;

  /// It has come to rest and is going back to the map.
  bool landing = false;

  void aim(double to, Duration now) {
    landing = false;
    lift.to(to, now);
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
