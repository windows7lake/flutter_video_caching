extension ListString on List<String> {
  Iterable<String> takeLast(int count) {
    return reversed.take(count).toList().reversed;
  }
}
