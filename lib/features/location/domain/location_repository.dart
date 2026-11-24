/// Where the phone is, or why the app cannot tell.
sealed class LocationState {
  const LocationState();
}

/// The phone's position.
class Located extends LocationState {
  const Located(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// Location may be asked for: not asked yet, or refused once. Android
/// reports both the same way, so the app treats them alike.
class CanAsk extends LocationState {
  const CanAsk();
}

/// Refused for good: only the phone's Settings can allow it now.
class RefusedForGood extends LocationState {
  const RefusedForGood();
}

/// Allowed, but location is switched off for the whole phone.
class LocationOff extends LocationState {
  const LocationOff();
}

/// Allowed and on, but no position came: no signal, or it took too long.
class PositionUnavailable extends LocationState {
  const PositionUnavailable();
}

abstract interface class LocationRepository {
  /// The current state, without asking the person anything.
  Future<LocationState> current();

  /// Shows the phone's permission prompt, then reports the state.
  Future<LocationState> ask();

  /// Opens this app's page in the phone's Settings.
  Future<void> openAppSettings();

  /// Opens the phone's location settings.
  Future<void> openLocationSettings();
}
