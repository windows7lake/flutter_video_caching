/// Enum representing the types of messages that can be sent between
/// the main isolate and the download isolate.
/// - [sendPort]: Used to send the SendPort for communication.
/// - [task]: Used to send or receive download task information.
/// - [logPrint]: Used to send log messages for debugging or monitoring.
enum IsolateMsgType { sendPort, task, logPrint }

/// Represents a message sent to or from the download isolate.
/// This class encapsulates the message type and the associated data payload,
/// enabling structured communication between isolates during download operations.
class DownloadIsolateMsg {
  /// The type of the message, indicating its purpose or content.
  final IsolateMsgType type;

  /// The data payload of the message, which can be any type depending on the message.
  final dynamic data;

  /// Constructs a [DownloadIsolateMsg] with the specified [type] and [data].
  DownloadIsolateMsg(this.type, this.data);

  /// Returns a string representation of the message, including its type and data.
  @override
  String toString() {
    return 'DownloadIsolateMsg [ type: $type, data: $data ]';
  }
}
