import 'dart:async';

import 'package:flutter/foundation.dart';

extension FunctionExtension on Function {
  /// 事件回调防抖
  VoidCallback debounce({int timeout = 500}) {
    return FunctionProxy(this, timeout: timeout).debounce;
  }


  /// 事件回调节流
  VoidCallback throttle({int timeout = 0}) {
    return FunctionProxy(this, timeout: timeout).throttle;
  }
}

class FunctionProxy {
  static final Map<String, Timer> _funcDebounce = {};
  static final Map<String, bool> _funcThrottle = {};
  final Function? target;

  final int timeout;

  FunctionProxy(this.target, {this.timeout = 0});

  factory FunctionProxy.debounce(
    Function target, {
    String? key,
    int timeout = 500,
  }) =>
      FunctionProxy(target, timeout: timeout)..debounce(uniqueKey: key);

  factory FunctionProxy.throttle(
    Function target, {
    String? key,
    int timeout = 500,
  }) =>
      FunctionProxy(target, timeout: timeout)..throttle(uniqueKey: key);

  void debounce({String? uniqueKey}) {
    String key = uniqueKey ?? hashCode.toString();
    Timer? timer = _funcDebounce[key];
    timer?.cancel();
    timer = Timer(Duration(milliseconds: timeout), () {
      Timer? t = _funcDebounce.remove(key);
      t?.cancel();
      target?.call();
    });
    _funcDebounce[key] = timer;
  }

  void throttle({String? uniqueKey}) async {
    String key = uniqueKey ?? hashCode.toString();
    bool enable = _funcThrottle[key] ?? true;
    if (enable) {
      _funcThrottle[key] = false;
      if (timeout == 0) {
        try {
          await target?.call();
        } catch (e) {
          rethrow;
        } finally {
          _funcThrottle.remove(key);
        }
      } else {
        await Future.delayed(Duration(milliseconds: timeout));
        _funcThrottle.remove(key);
        target?.call();
      }
    }
  }
}
