import 'package:fl_clash/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('group type wire names are cached', () {
    final first = GroupTypeExtension.valueList;
    final second = GroupTypeExtension.valueList;

    expect(first, ['Selector', 'URLTest', 'Fallback', 'LoadBalance', 'Relay']);
    expect(identical(first, second), isTrue);
  });
}
