import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fixed list version changes on copy and mutations', () {
    final list = FixedList<int>(2);
    final initialVersion = list.version;

    final copy = list.copyWith();
    expect(copy.version, greaterThan(initialVersion));

    copy.add(1);
    expect(copy.version, greaterThan(initialVersion + 1));
    expect(list.version, initialVersion);

    copy.clear();
    expect(copy.version, greaterThan(initialVersion + 2));
  });

  test('fixed list enforces its maximum length', () {
    final list = FixedList<int>(2)..addAll([1, 2, 3]);

    expect(list.list, [2, 3]);
    expect(list.length, 2);
  });

  test('fixed list batch append changes the version once', () {
    final list = FixedList<int>(5);
    final version = list.version;

    list.addAll([1, 2, 3]);

    expect(list.version, version + 1);
    expect(list.list, [1, 2, 3]);
  });
}
