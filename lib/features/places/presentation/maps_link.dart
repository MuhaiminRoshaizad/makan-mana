import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/toast.dart';
import '../domain/place.dart';

/// Hands a link to the phone; false when nothing could open it.
typedef OpenLink = Future<bool> Function(Uri uri);

final Provider<OpenLink> openLinkProvider = Provider<OpenLink>(
  (Ref ref) =>
      (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// A Google Maps link to [place], by Google's Maps URLs scheme: it opens the
/// Maps app when installed and the website when not. Made-up demo places
/// have no real place ID, so they are searched for by name only.
Uri mapsLinkFor(Place place) => Uri.https('www.google.com', '/maps/search/', {
  'api': '1',
  'query': place.name,
  if (!place.id.startsWith('demo-')) 'query_place_id': place.id,
});

/// Opens [place] in Google Maps, or says so when the phone cannot.
Future<void> openInMaps(
  BuildContext context,
  WidgetRef ref,
  Place place,
) async {
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  final bool opened = await ref.read(openLinkProvider)(mapsLinkFor(place));
  if (!opened && context.mounted) {
    showToast(
      context,
      "Couldn't open Google Maps",
      failed: true,
      overlay: overlay,
    );
  }
}
