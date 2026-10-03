import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

void main() {
  test('throttler does not delay first callback when events repeat', () {
    fakeAsync((async) {
      var calls = 0;
      final throttler = Throttler();

      throttler.call(
        FunctionTag.updateDelay,
        () => calls++,
        duration: const Duration(seconds: 3),
      );

      for (var i = 0; i < 5; i++) {
        async.elapse(const Duration(milliseconds: 500));
        throttler.call(
          FunctionTag.updateDelay,
          () => calls++,
          duration: const Duration(seconds: 3),
        );
        expect(calls, 0);
      }

      async.elapse(const Duration(milliseconds: 499));
      expect(calls, 0);

      async.elapse(const Duration(milliseconds: 2));
      expect(calls, 1);
    });
  });

  test('delay result batcher coalesces a short burst', () {
    fakeAsync((async) {
      final flushes = <List<Delay>>[];
      final batcher = DelayResultBatcher(
        onFlush: flushes.add,
        interval: const Duration(milliseconds: 16),
      );

      batcher.add(const Delay(name: 'A', url: 'https://a', value: 20));
      batcher.add(const Delay(name: 'B', url: 'https://b', value: 0));
      batcher.add(const Delay(name: 'C', url: 'https://c', value: -1));
      expect(flushes, isEmpty);

      async.elapse(const Duration(milliseconds: 16));
      expect(flushes, [
        [
          const Delay(name: 'A', url: 'https://a', value: 20),
          const Delay(name: 'B', url: 'https://b', value: 0),
          const Delay(name: 'C', url: 'https://c', value: -1),
        ],
      ]);

      batcher.add(const Delay(name: 'D', url: 'https://d', value: 30));
      async.elapse(const Duration(milliseconds: 16));
      expect(flushes, hasLength(2));
      expect(flushes.last.single.name, 'D');
    });
  });

  test('group refresh gate rejects equivalent snapshots', () {
    final gate = GroupRefreshGate();
    const groups = [Group(name: 'Proxy', type: GroupType.Selector)];

    expect(gate.shouldCommit(groups), isTrue);
    expect(gate.shouldCommit(List.of(groups)), isFalse);
    expect(
      gate.shouldCommit([
        Group(
          name: 'Proxy',
          type: GroupType.Selector,
          all: const [Proxy(name: 'Node', type: 'Selector', now: 'Next')],
        ),
      ]),
      isTrue,
    );
    expect(gate.shouldCommit(List.of(groups)), isTrue);
  });

  testWidgets('proxy change debouncer applies first change immediately', (
    tester,
  ) async {
    final changes = <(String, String)>[];
    final firstChangeGate = Completer<void>();
    var completedBatches = 0;
    final debouncer = ProxyChangeDebouncer(
      onChange: (groupName, proxyName) {
        changes.add((groupName, proxyName));
        if (changes.length == 1) {
          return firstChangeGate.future;
        }
        return Future.value();
      },
      onBatchComplete: () {
        completedBatches++;
      },
    );

    debouncer.call('Direct', 'Node A');
    await tester.pump();
    expect(changes, [('Direct', 'Node A')]);

    debouncer.call('Direct', 'Node B');
    debouncer.call('Streaming', 'Node C');

    await tester.pump(const Duration(milliseconds: 99));
    expect(changes, [('Direct', 'Node A')]);
    expect(completedBatches, 0);

    firstChangeGate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(changes, [
      ('Direct', 'Node A'),
      ('Direct', 'Node B'),
      ('Streaming', 'Node C'),
    ]);
    expect(completedBatches, 2);
  });

  test('retry waits between attempts', () {
    fakeAsync((async) {
      var attempts = 0;
      Object? resultValue;
      Object? resultError;
      final result = retry<int>(
        task: () async {
          attempts++;
          return attempts;
        },
        retryIf: (value) => value < 3,
        delay: const Duration(milliseconds: 20),
      );
      result.then(
        (value) => resultValue = value,
        onError: (error) => resultError = error,
      );

      async.flushMicrotasks();
      expect(attempts, 1);

      async.elapse(const Duration(milliseconds: 19));
      expect(attempts, 1);

      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();
      expect(attempts, 2);

      async.elapse(const Duration(milliseconds: 20));
      async.flushMicrotasks();
      expect(attempts, 3);
      expect(resultValue, 3);
      expect(resultError, isNull);
    });
  });
}
