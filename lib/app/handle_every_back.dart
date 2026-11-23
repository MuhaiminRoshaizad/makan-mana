import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps Android passing every Back to the app, so Flutter decides what each
/// one does: a pushed page or sheet closes, Map goes to Spin, and Spin asks
/// before leaving (see TabRoot).
///
/// On Android 14 and later the app tells Android in advance whether it
/// handles Back, and Android closes the app itself when the answer is no.
/// Flutter's default relays the answer of whichever navigator changed last;
/// with a navigator per tab plus the root one for sheets, one that cannot
/// pop answers no, and Back on a tab then closes the app without the hint.
/// fotos logged this on a phone on 12/11/2026. When nothing in the app
/// takes a Back, Flutter closes the app itself, so always answering yes
/// loses nothing but Android's back-to-home preview.
bool handleEveryBack(NavigationNotification notification) {
  _tellAndroid();
  return true;
}

void _tellAndroid() {
  final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
  // As Flutter's own relay: the engine isn't ready before the app starts.
  if (state == null || state == AppLifecycleState.detached) return;
  SystemNavigator.setFrameworkHandlesBack(true);
}

/// Says it again each time the app comes to the front: a new Android window
/// for the same app starts without the answer.
class HandleEveryBack extends StatefulWidget {
  const HandleEveryBack({super.key, required this.child});

  final Widget child;

  @override
  State<HandleEveryBack> createState() => _HandleEveryBackState();
}

class _HandleEveryBackState extends State<HandleEveryBack> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: _tellAndroid,
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tellAndroid());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
