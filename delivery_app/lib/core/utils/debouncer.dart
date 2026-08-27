import 'dart:async';

/// Delays invoking [action] until [delay] has passed without a new call —
/// used to avoid firing a network request on every keystroke in search boxes.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
