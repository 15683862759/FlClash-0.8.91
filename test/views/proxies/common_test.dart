import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/proxies/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delay tests mark each proxy loading only once', () async {
    final writes = <List<Delay>>[];

    await runDelayTests(
      [
        const SelectedProxyState(proxyName: 'node-a', testUrl: 'url-a'),
        const SelectedProxyState(proxyName: 'node-b', testUrl: 'url-b'),
      ],
      defaultTestUrl: 'default-url',
      getDelay: (url, name) async =>
          Delay(url: url, name: name, value: name == 'node-a' ? 20 : 30),
      setDelays: writes.add,
      concurrencyLimit: 2,
    );

    final delays = writes.expand((batch) => batch).toList();
    expect(
      delays.where((delay) => delay.value == 0).map((delay) => delay.name),
      containsAllInOrder(['node-a', 'node-b']),
    );
    expect(delays.where((delay) => delay.value == 0), hasLength(2));
    expect(delays.where((delay) => (delay.value ?? 0) > 0), hasLength(2));
  });

  test('delay test results are written as one batch', () async {
    final writes = <List<Delay>>[];

    await runDelayTests(
      [
        const SelectedProxyState(proxyName: 'node-a', testUrl: 'url-a'),
        const SelectedProxyState(proxyName: 'node-b', testUrl: 'url-b'),
      ],
      defaultTestUrl: 'default-url',
      getDelay: (url, name) async =>
          Delay(url: url, name: name, value: name == 'node-a' ? 20 : 30),
      setDelays: writes.add,
      concurrencyLimit: 2,
      resultBatchInterval: Duration.zero,
    );

    expect(writes, hasLength(2));
    expect(
      writes.last.map((delay) => delay.name),
      containsAll(['node-a', 'node-b']),
    );
  });
}
