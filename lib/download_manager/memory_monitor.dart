import 'dart:async';
import 'dart:io';
import 'dart:isolate';

// 内存监控系统
class MemoryMonitor {
  final int maxAllowedMB;
  final Duration checkInterval;
  Timer? _timer;
  Isolate? _isolate;

  MemoryMonitor({
    required this.maxAllowedMB,
    required this.checkInterval,
  });

  // 开始监控
  void startMonitoring(Isolate isolate) {
    _isolate = isolate;
    _timer = Timer.periodic(checkInterval, (_) => _checkMemory());
  }

  // 检查内存使用情况
  void _checkMemory() {
    final processInfo = ProcessInfo.currentRss;
    final usageMB = processInfo / 1024 / 1024;

    if (usageMB > maxAllowedMB) {
      _isolate?.kill(priority: Isolate.immediate);
      _timer?.cancel();
    }
  }

  // 重置监控
  void reset() {
    _timer?.cancel();
    startMonitoring(_isolate!);
  }
}
