extension ListString on List<String> {
  /// Returns an iterable of the last [count] elements in the list, in original order.
  /// If [count] is greater than the list length, returns all elements.
  ///
  /// Example:
  ///   final list = ['a', 'b', 'c', 'd'];
  ///   final lastTwo = list.takeLast(2); // ['c', 'd']
  Iterable<String> takeLast(int count) {
    return reversed.take(count).toList().reversed;
  }
}
