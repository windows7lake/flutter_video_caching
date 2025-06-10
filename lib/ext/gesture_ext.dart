import 'dart:async';

class FunctionProxy {
  static final Map<String, Timer> _funcDebounce = {};

  /// The target function to be debounced
  final Function? target;

  /// The debounce timeout in milliseconds
  final int timeout;

  /// Creates a FunctionProxy with the specified target function and timeout.
  FunctionProxy(this.target, {this.timeout = 0});

  /// Factory constructor to create a debounced function.
  factory FunctionProxy.debounce(
    Function target, {
    String? key,
    int timeout = 500,
  }) {
    return FunctionProxy(target, timeout: timeout)..debounce(uniqueKey: key);
  }

  /// Debounce a function call to prevent it from being called too frequently.
  /// Execute immediately for the first time, enter anti shake logic later
  void debounce({String? uniqueKey}) {
    String key = uniqueKey ?? target.hashCode.toString();
    Timer? timer = _funcDebounce[key];
    timer?.cancel();
    timer = Timer(Duration(milliseconds: timeout), () {
      Timer? t = _funcDebounce.remove(key);
      t?.cancel();
      target?.call();
    });
    _funcDebounce[key] = timer;
  }
}
