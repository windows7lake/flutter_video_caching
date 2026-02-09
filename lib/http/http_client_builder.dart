import 'package:dio/dio.dart';

/// An abstract class that defines a builder for creating [Dio] instances.
///
/// Implementations of this class should provide a concrete way to instantiate
/// and configure a [Dio]. This allows for flexible creation of HTTP clients,
/// which can be useful for testing, dependency injection, or customizing client behavior.
abstract class HttpClientBuilder {
  /// Creates and returns a new instance of [Dio].
  ///
  /// Implementations should override this method to provide the desired
  /// configuration for the [Dio] instance.
  Dio create();
}
