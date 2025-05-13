abstract class LruCache<K, V> {
  /// Returns the value for the specified key if it exists.
  Future<V?> get(K key);

  /// Puts the value in the cache and returns the previous value if it exists.
  Future<V?> put(K key, V value);

  /// Removes the entry for the specified key if it exists.
  Future<V?> remove(K key);

  /// Removes all entries from the cache.
  Future<void> clear();

  /// Trims the cache to the specified maximum size.
  Future<void> trimToSize(int maxSize);

  /// Resizes the cache to the specified maximum size.
  Future<void> resize(int maxSize);
}
