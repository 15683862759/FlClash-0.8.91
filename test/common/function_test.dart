import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
