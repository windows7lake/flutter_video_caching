/// An abstract class that defines the contract for a Least Recently Used (LRU) cache.
///
/// This cache stores key-value pairs and evicts the least recently accessed items
/// when the cache exceeds its maximum size. The interface is asynchronous, allowing
/// for implementations that may involve I/O operations (e.g., disk or network).
///
/// Type Parameters:
///   - K: The type of keys maintained by this cache.
///   - V: The type of mapped values.
abstract class LruCache<K, V> {
  /// Returns the value associated with the given [key], or `null` if the key is not present.
  ///
  /// Accessing a key should update its usage status in the LRU order.
  Future<V?> get(K key);

  /// Inserts or updates the value for the given [key] in the cache.
  ///
  /// Returns the previous value associated with the [key], or `null` if there was none.
  /// Inserting a new value may trigger eviction if the cache exceeds its maximum size.
  Future<V?> put(K key, V value);

  /// Removes the entry for the specified [key] from the cache, if it exists.
  ///
  /// Returns the value that was removed, or `null` if the key was not present.
  Future<V?> remove(K key);

  /// Removes all entries from the cache.
  ///
  /// After this operation, the cache will be empty.
  Future<void> clear();

  /// Trims the cache so that its size does not exceed [maxSize].
  ///
  /// Evicts least recently used entries until the cache size is less than or equal to [maxSize].
  Future<void> trimToSize(int maxSize);

  /// Resizes the cache to the new [maxSize].
  ///
  /// If the current size exceeds [maxSize], evicts entries as needed.
  Future<void> resize(int maxSize);
}
