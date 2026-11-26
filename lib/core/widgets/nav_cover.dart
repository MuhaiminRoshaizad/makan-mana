import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How far a place card covers the screen, from 0 (a card over the tab) to
/// 1 (the full sheet). The floating tab bar slides away by as much, so the
/// card can grow over the place where the bar sits.
final Provider<ValueNotifier<double>> navCoverProvider =
    Provider<ValueNotifier<double>>((Ref ref) {
      final ValueNotifier<double> cover = ValueNotifier<double>(0);
      ref.onDispose(cover.dispose);
      return cover;
    });
