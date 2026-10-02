import 'dart:async';

import 'package:fake_async/fake_async.dart';
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

  testWidgets('withTimeout cancels last cleanup after completion', (
    tester,
  ) async {
    final completer = Completer<int>();
    var lastCleanupCount = 0;
    final future = completer.future.withTimeout(
      timeout: const Duration(milliseconds: 20),
      onLast: () {
        lastCleanupCount++;
      },
      onTimeout: () => 0,
    );

    completer.complete(1);
    expect(await future, 1);
    await tester.pump(const Duration(milliseconds: 400));

    expect(lastCleanupCount, 0);
  });

  test('withTimeout creates only timeout timer without onLast', () {
    fakeAsync((async) {
      final completer = Completer<int>();
      final future = completer.future.withTimeout(
        timeout: const Duration(milliseconds: 20),
        onTimeout: () => 0,
      );
      Object? result;
      future.then((value) => result = value);

      expect(async.nonPeriodicTimerCount, 1);
      completer.complete(1);
      async.flushMicrotasks();

      expect(result, 1);
    });
  });
}
