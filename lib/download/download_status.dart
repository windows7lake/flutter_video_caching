/// Defines the possible statuses for a download task.
/// This enum is used to track and manage the state of a download process
/// throughout its lifecycle, from initialization to completion or failure.
enum DownloadStatus {
  /// The download has not started yet.
  IDLE,

  /// The download is currently in progress.
  DOWNLOADING,

  /// The download has been paused by the user or system.
  PAUSED,

  /// The download has completed successfully.
  COMPLETED,

  /// The download has finished all related operations (e.g., post-processing).
  FINISHED,

  /// The download has been cancelled before completion.
  CANCELLED,

  /// The download has failed due to an error.
  FAILED
}
