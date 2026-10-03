import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lazy separated list only builds requested items', (
    tester,
  ) async {
    var builtValues = <int>[];
    final list = LazySeparatedList<int>(
      items: List.generate(1000, (index) => index),
      separator: const Divider(height: 0),
      itemBuilder: (context, value) {
        builtValues.add(value);
        return Text('$value');
      },
    );

    expect(list.itemCount, 1999);
    expect(list.build(null, 0), isA<Text>());
    expect(list.build(null, 1), isA<Divider>());
    expect(list.build(null, 1998), isA<Text>());
    expect(builtValues, [0, 999]);
  });
}
