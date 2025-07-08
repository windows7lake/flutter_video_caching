import 'dart:io';

/// An abstract class that defines a builder for creating [HttpClient] instances.
///
/// Implementations of this class should provide a concrete way to instantiate
/// and configure a [HttpClient]. This allows for flexible creation of HTTP clients,
/// which can be useful for testing, dependency injection, or customizing client behavior.
abstract class HttpClientBuilder {
  /// Creates and returns a new instance of [HttpClient].
  ///
  /// Implementations should override this method to provide the desired
  /// configuration for the [HttpClient] instance.
  HttpClient create();
}
