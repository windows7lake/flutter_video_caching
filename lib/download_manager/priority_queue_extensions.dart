import 'package:collection/collection.dart';

// 为 PriorityQueue 添加扩展方法
extension PriorityQueueExtensions<E> on PriorityQueue<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final element in this.unorderedElements) {
      if (test(element)) return element;
    }
    return null;
  }
}