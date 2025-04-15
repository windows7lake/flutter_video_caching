/// Defines an enum representing the status of a download process.
enum DownloadStatus {
  /// The download has not started yet.
  IDLE,

  /// The download is in progress.
  DOWNLOADING,

  /// The download is paused.
  PAUSED,

  /// The download is completed.
  COMPLETED,

  /// The download is finished.
  FINISHED,

  /// The download is cancelled.
  CANCELLED,

  /// The download has failed.
  FAILED
}
