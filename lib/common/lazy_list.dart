import 'package:flutter/widgets.dart';

class LazySeparatedList<T> {
  final List<T> items;
  final Widget separator;
  final Widget Function(BuildContext? context, T item) itemBuilder;

  const LazySeparatedList({
    required this.items,
    required this.separator,
    required this.itemBuilder,
  });

  int get itemCount => items.isEmpty ? 0 : items.length * 2 - 1;

  Widget build(BuildContext? context, int index) {
    if (index.isOdd) {
      return separator;
    }
    return itemBuilder(context, items[index ~/ 2]);
  }
}
