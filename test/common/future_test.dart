import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forEachBounded keeps at most the configured tasks running', () async {
    const taskCount = 30;
    const concurrencyLimit = 6;
    var activeCount = 0;
    var maxActiveCount = 0;
    var startedCount = 0;

    await forEachBounded(List.generate(taskCount, (index) => index), (_) async {
      startedCount++;
      activeCount++;
      maxActiveCount = maxActiveCount < activeCount
          ? activeCount
          : maxActiveCount;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      activeCount--;
    }, concurrencyLimit: concurrencyLimit);

    expect(startedCount, taskCount);
    expect(maxActiveCount, lessThanOrEqualTo(concurrencyLimit));
  });
}
