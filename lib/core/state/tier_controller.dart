import 'package:flutter/foundation.dart';

import '../models/tier.dart';
import '../platform/channels.dart';

/// FR-TIER-1..3 — resolves and republishes the current access tier.
class TierController extends ChangeNotifier {
  TierController(this._bridge);

  final DevAccessBridge _bridge;

  TierStatus _status = TierStatus.unknown;
  bool _loading = false;

  TierStatus get status => _status;

  AccessTier get tier => _status.tier;

  bool get loading => _loading;

  Future<void> refresh({bool probeRoot = false}) async {
    _loading = true;
    notifyListeners();
    final raw = await _bridge.tierStatus(probeRoot: probeRoot);
    if (raw.isNotEmpty) _status = TierStatus.fromMap(raw);
    _loading = false;
    notifyListeners();
  }

  /// Probing root spawns `su`; the user asks for it explicitly from the tier screen.
  Future<void> probeRoot() async {
    await _bridge.resetRootProbe();
    await refresh(probeRoot: true);
  }

  /// T1 — sends the user to the "Modify system settings" special-access screen (C3).
  Future<void> requestWriteSettings() async {
    await _bridge.requestWriteSettings();
  }

  /// FR-TIER-2 — after the user runs the adb command, verify the grant landed.
  Future<bool> verifySecureGrant() async {
    await refresh();
    return _status.canWriteSecure;
  }
}
