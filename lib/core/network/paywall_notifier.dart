import 'package:flutter/foundation.dart';

/// Fires whenever the backend returns HTTP 402 (out of AI credits), mirroring
/// the web app's global `credits-depleted` event. The app shell listens and
/// shows the paywall, so individual features don't each need to handle it.
class PaywallNotifier extends ChangeNotifier {
  int _ticks = 0;
  int get ticks => _ticks;

  void trigger() {
    _ticks++;
    notifyListeners();
  }
}
