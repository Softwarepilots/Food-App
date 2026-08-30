import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fires whenever the network layer detects the session is no longer valid
/// (refresh token missing/expired). Kept here, in core, so the network layer
/// doesn't need to depend on the auth feature directly — the auth feature
/// listens to this provider and reacts by clearing its own state.
class SessionExpiredNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void notify() => state++;
}

final sessionExpiredProvider = NotifierProvider<SessionExpiredNotifier, int>(SessionExpiredNotifier.new);
