# Makan Mana

A lunch picker for an office that can never decide where to eat. It fills a
wheel with the restaurants around you from Google Places, keeps the ones that
pass your filters, and one spin settles it.

There is no account and no server. The app asks Google for nearby places with
its own restricted key, and uses your location only while it is open.

## What it does

- **Spin** a wheel of every nearby place that passes the filters, up to 20.
  Throw it with a finger or tap Spin. It slows peg by peg and can bounce back
  off the arrow at the last moment. The place it lands on opens with its
  rating, reviews, distance and closing time, and a button to Open in Google
  Maps.
- **Filters** keep places by minimum rating, minimum number of reviews, and
  whether they are open now.
- **Map** shows the same places as pins in their wheel colours on a Google
  map, with the search radius drawn as a circle you can widen up to 50 km.
- **Location** is your live position, asked for the first time you search. If
  you would rather not share it, drop a pin on the map instead.

## Status

In development. The repository holds the Flutter template with the app's real
ids; the screens are being built.

## Documentation

| Doc                             | Covers                              |
|---------------------------------|-------------------------------------|
| [Decisions](docs/decisions.md)  | Why the app is built the way it is  |

## Getting started

Requires Flutter 3.44 or later. Runs on Android and iOS.

```bash
flutter pub get
flutter run
```

Before committing:

```bash
flutter analyze
flutter test
```
