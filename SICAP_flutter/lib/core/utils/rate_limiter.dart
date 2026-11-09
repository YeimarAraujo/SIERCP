import 'dart:async';

class RateLimiter {
  final int milliseconds;
  Timer? _timer;

  RateLimiter({required this.milliseconds});

  /// Debounce: Executes the function after a delay, resets if called again.
  void debounce(void Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  /// Throttle: Executes the function once and ignores subsequent calls during the interval.
  bool _isThrottling = false;
  void throttle(void Function() action) {
    if (_isThrottling) return;
    
    action();
    _isThrottling = true;
    Timer(Duration(milliseconds: milliseconds), () {
      _isThrottling = false;
    });
  }
}

/// Global instance for common UI actions (e.g., prevent double submit)
final submitRateLimiter = RateLimiter(milliseconds: 1000);
