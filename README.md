# Makan Mana

A lunch picker for an office that can never decide where to eat. It fills a
wheel with the restaurants around you, keeps the ones that pass your filters,
and one spin settles it.

There is no account and no server. The places, with their ratings and review
counts, come from a list built into the app, and your location is used only
while it is open.

## What it does

- **Spin** a wheel of every nearby place that passes the filters, up to 20.
  Throw it with a finger or tap Spin. It slows peg by peg and can bounce back
  off the arrow at the last moment. The place it lands on opens with its
  rating, reviews and distance, and a button to Open in Google Maps.
- **Filters** keep places by minimum rating and minimum number of reviews,
  and by whether they are open now where the places list knows.
- **Map** shows the same places as pins in their wheel colours, with the
  search radius drawn as a circle you can widen up to 50 km.
- **Location** is your live position, asked for the first time you search. If
  you would rather not share it, drop a pin on the map instead.

## Status

In development. The Spin tab works, with its filters and result; location
and the map are being built.

## Documentation

| Doc                             | Covers                              |
|---------------------------------|-------------------------------------|
| [Decisions](docs/decisions.md)  | Why the app is built the way it is  |

## Getting started

Requires Flutter 3.44.6 (pinned in `pubspec.yaml`). Runs on Android and iOS.

```bash
flutter pub get
flutter run --dart-define=MAKAN_MANA_DEMO=true
```

The demo build fills the wheel with 20 made-up places. A normal build reads
the places list from `assets/places/places.private.json`, which is prepared
on the developer's computer and never committed, so a build without it says
it has no places.

Before committing:

```bash
dart format lib test
flutter analyze
flutter test
```

GitHub Actions runs the same checks and a debug Android build on every push
to `main` and every pull request, and builds the iOS app on macOS
(`.github/workflows/ci.yml`).

## Credits

The idea came from [MARUTSU](https://github.com/Ikmal1270), who suggested
putting the places to eat on a wheel and spinning it to decide where to have
lunch. Designed and built by
[Muhaimin Roshaizad](https://github.com/MuhaiminRoshaizad).
