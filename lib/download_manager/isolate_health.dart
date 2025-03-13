import 'dart:core';

// 健康监控系统
class IsolateHealth {
  DateTime _lastActivity = DateTime.now();
  int _errorCount = 0;
  bool _isKilled = false;

  bool get isHealthy =>
      !_isKilled &&
      _errorCount < 3 &&
      DateTime.now().difference(_lastActivity) < Duration(minutes: 5);

  // 记录活动时间
  void recordActivity() {
    _lastActivity = DateTime.now();
  }

  // 记录错误次数
  void recordError() {
    _errorCount++;
    if (_errorCount >= 3) {
      _isKilled = true;
    }
  }
}
