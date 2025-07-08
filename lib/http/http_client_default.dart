import 'dart:io';

import 'http_client_builder.dart';

/// A default implementation of the [HttpClientBuilder] abstract class.
///
/// This class provides a concrete implementation of the [create] method,
/// which simply returns a new instance of [HttpClient] with default settings.
/// It can be used wherever a basic HTTP client is needed without any custom configuration.
///
/// Example usage:
/// ```dart
/// final clientBuilder = HttpClientDefault();
/// final httpClient = clientBuilder.create();
/// ```
class HttpClientDefault extends HttpClientBuilder {
  /// Creates and returns a new [HttpClient] instance with default configuration.
  ///
  /// This method overrides the abstract [create] method from [HttpClientBuilder].
  /// The returned [HttpClient] can be used to perform HTTP requests.
  @override
  HttpClient create() {
    return HttpClient();
  }
}
