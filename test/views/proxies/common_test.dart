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

  test('delay tests continue after one proxy fails', () async {
    final calls = <String>[];
    final writes = <List<Delay>>[];

    await runDelayTests(
      [
        const SelectedProxyState(proxyName: 'node-a', testUrl: 'url-a'),
        const SelectedProxyState(proxyName: 'node-b', testUrl: 'url-b'),
        const SelectedProxyState(proxyName: 'node-c', testUrl: 'url-c'),
      ],
      defaultTestUrl: 'default-url',
      getDelay: (url, name) async {
        calls.add(name);
        if (name == 'node-a') {
          throw StateError('test failed');
        }
        return Delay(url: url, name: name, value: name == 'node-b' ? 20 : 30);
      },
      setDelays: writes.add,
      concurrencyLimit: 2,
      resultBatchInterval: Duration.zero,
    );

    expect(calls, containsAll(['node-a', 'node-b', 'node-c']));
    expect(
      writes.expand((batch) => batch).where((delay) => delay.value != 0),
      hasLength(3),
    );
    expect(
      writes
          .expand((batch) => batch)
          .where((delay) => delay.value != 0)
          .map((delay) => delay.name),
      containsAll(['node-a', 'node-b', 'node-c']),
    );
  });

  test('delay tests resolve duplicate real nodes once', () async {
    final calls = <String>[];
    final writes = <List<Delay>>[];

    await runDelayTests(
      [
        const SelectedProxyState(
          proxyName: 'node-a',
          group: true,
          testUrl: 'group-url',
        ),
        const SelectedProxyState(proxyName: 'node-a', testUrl: 'group-url'),
      ],
      defaultTestUrl: 'default-url',
      getDelay: (url, name) async {
        calls.add('$name $url');
        return Delay(url: url, name: name, value: 20);
      },
      setDelays: writes.add,
      concurrencyLimit: 2,
    );

    expect(calls, hasLength(1));
    expect(
      writes.expand((batch) => batch).where((delay) => delay.value == 0),
      hasLength(1),
    );
    expect(
      writes.expand((batch) => batch).where((delay) => delay.value == 20),
      hasLength(1),
    );
  });
}
