import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('proxy change debouncer batches keyed changes', (tester) async {
    final changes = <(String, String)>[];
    var completedBatches = 0;
    final debouncer = ProxyChangeDebouncer(
      onChange: (groupName, proxyName) {
        changes.add((groupName, proxyName));
      },
      onBatchComplete: () {
        completedBatches++;
      },
    );

    debouncer.call('Direct', 'Node A');
    debouncer.call('Direct', 'Node B');
    debouncer.call('Streaming', 'Node C');

    await tester.pump(const Duration(milliseconds: 99));
    expect(changes, isEmpty);
    expect(completedBatches, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(changes, [('Direct', 'Node B'), ('Streaming', 'Node C')]);
    expect(completedBatches, 1);
  });
}
