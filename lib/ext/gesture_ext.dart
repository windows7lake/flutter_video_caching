import 'dart:async';

/// A proxy class that provides debouncing functionality for functions.
///
/// This class allows you to wrap a function and ensure that it is not called
/// too frequently. When the debounced function is invoked repeatedly within
/// a short period, only the last invocation will be executed after the specified
/// timeout.
class FunctionProxy {
  /// A static map to keep track of active debounce timers for each unique key.
  static final Map<String, Timer> _funcDebounce = {};

  /// The target function to be debounced.
  final Function? target;

  /// The debounce timeout in milliseconds.
  final int timeout;

  /// Creates a [FunctionProxy] with the specified [target] function and [timeout].
  ///
  /// [timeout] defaults to 0 milliseconds if not specified.
  FunctionProxy(this.target, {this.timeout = 0});

  /// Factory constructor to create a debounced function proxy.
  ///
  /// [target]: The function to debounce.
  /// [key]: An optional unique key to identify the debounced function.
  /// [timeout]: The debounce duration in milliseconds (default is 500).
  ///
  /// Returns a [FunctionProxy] instance and immediately applies the debounce logic.
  factory FunctionProxy.debounce(
    Function target, {
    String? key,
    int timeout = 500,
  }) {
    return FunctionProxy(target, timeout: timeout)..debounce(uniqueKey: key);
  }

  /// Debounce the function call to prevent it from being called too frequently.
  ///
  /// If called multiple times within the [timeout] period, only the last call
  /// will be executed after the timeout. The first call executes immediately,
  /// and subsequent calls within the debounce period are ignored until the
  /// timeout expires.
  ///
  /// [uniqueKey]: An optional key to uniquely identify the debounced function.
  void debounce({String? uniqueKey}) {
    // Use the provided uniqueKey or fallback to the hash code of the target function.
    String key = uniqueKey ?? target.hashCode.toString();
    // Cancel any existing timer for this key.
    Timer? timer = _funcDebounce[key];
    timer?.cancel();
    // Start a new timer for the debounce period.
    timer = Timer(Duration(milliseconds: timeout), () {
      // Remove and cancel the timer when the timeout completes.
      Timer? t = _funcDebounce.remove(key);
      t?.cancel();
      // Call the target function.
      target?.call();
    });
    // Store the new timer in the map.
    _funcDebounce[key] = timer;
  }
}
