extension MemoryExt on int {
  String get toMemorySize {
    if (this < 1024) {
      return '${this}B';
    } else if (this < 1024 * 1024) {
      return '${(this / 1024).toStringAsFixed(2)}KB';
    } else if (this < 1024 * 1024 * 1024) {
      return '${(this / (1024 * 1024)).toStringAsFixed(2)}MB';
    } else {
      return '${(this / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
    }
  }
}
