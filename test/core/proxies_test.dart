import 'package:fl_clash/core/proxies.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _delayMap = <String, Map<String, int?>>{
  'https://example.com/default': {'node-a': 10, 'node-b': 20},
};

void main() {
  test('snapshot cache parses proxies only when the structure changes', () {
    final cache = ProxiesSnapshotCache();
    final baseGroups = [
      Group(
        type: GroupType.Selector,
        name: 'GLOBAL',
        all: const [
          Proxy(name: 'node-a', type: 'Direct'),
          Proxy(name: 'node-b', type: 'Direct'),
        ],
      ),
    ];

    final first = cache.update(
      signature: 'one',
      baseGroups: baseGroups,
      states: const {
        'GLOBAL': ProxySnapshotState(now: 'node-a', hidden: false),
      },
      sortType: ProxiesSortType.delay,
      delayMap: _delayMap,
      selectedMap: const {},
      defaultTestUrl: 'https://example.com/default',
    );

    expect(first.single.now, 'node-a');
    expect(first.single.all.map((proxy) => proxy.name), ['node-a', 'node-b']);

    final second = cache.update(
      signature: 'one',
      states: const {'GLOBAL': ProxySnapshotState(now: 'node-b', hidden: true)},
      sortType: ProxiesSortType.delay,
      delayMap: _delayMap,
      selectedMap: const {},
      defaultTestUrl: 'https://example.com/default',
    );

    expect(second.single.now, 'node-b');
    expect(second.single.hidden, isTrue);
    expect(second.single.all.map((proxy) => proxy.name), ['node-a', 'node-b']);
  });

  test('snapshot cache reuses the previous list when nothing changes', () {
    final cache = ProxiesSnapshotCache();
    final baseGroups = const [
      Group(
        type: GroupType.Selector,
        name: 'GLOBAL',
        all: [Proxy(name: 'node-a', type: 'Direct')],
      ),
    ];
    final first = cache.update(
      signature: 'one',
      baseGroups: baseGroups,
      states: const {
        'GLOBAL': ProxySnapshotState(now: 'node-a', hidden: false),
      },
      sortType: ProxiesSortType.delay,
      delayMap: _delayMap,
      selectedMap: const {},
      defaultTestUrl: 'https://example.com/default',
    );

    final second = cache.update(
      signature: 'one',
      states: const {
        'GLOBAL': ProxySnapshotState(now: 'node-a', hidden: false),
      },
      sortType: ProxiesSortType.delay,
      delayMap: _delayMap,
      selectedMap: const {},
      defaultTestUrl: 'https://example.com/default',
    );

    expect(identical(second, first), isTrue);
  });

  test('snapshot cache keeps visibility when a group state is missing', () {
    final group = Group(
      type: GroupType.Selector,
      name: 'Proxy',
      now: 'node-a',
      hidden: false,
      all: [Proxy(name: 'node-a', type: 'Direct')],
    );

    final patched = ProxiesSnapshotCache.patch([group], const {});

    expect(patched.single.hidden, isFalse);
    expect(patched.single.now, 'node-a');
  });

  test('snapshot cache parses nested groups and patches states', () {
    final groups = ProxiesSnapshotCache.parse({
      'GLOBAL': {
        'type': 'Selector',
        'name': 'GLOBAL',
        'now': 'Proxy',
        'hidden': false,
        'all': ['Proxy', 'node-a'],
      },
      'Proxy': {
        'type': 'URLTest',
        'name': 'Proxy',
        'now': 'node-a',
        'hidden': true,
        'all': ['node-a'],
      },
      'node-a': {'type': 'Direct', 'name': 'node-a'},
    });

    expect(groups.map((group) => group.name), ['GLOBAL', 'Proxy']);
    expect(groups.first.all.map((proxy) => proxy.name), ['Proxy', 'node-a']);

    final patched = ProxiesSnapshotCache.patch(groups, const {
      'GLOBAL': ProxySnapshotState(now: 'Proxy', hidden: true),
      'Proxy': ProxySnapshotState(now: 'node-a', hidden: false),
    });

    expect(patched.first.hidden, isTrue);
    expect(patched.last.hidden, isFalse);
  });
}
