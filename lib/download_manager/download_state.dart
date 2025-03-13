// 下载状态枚举
enum DownloadState {
  queued,
  preparing,
  downloading,
  paused,
  canceled,
  completed,
  error
}