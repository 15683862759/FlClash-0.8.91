import 'dart:collection';

import 'package:fl_clash/common/compute.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingSelectedMap extends MapBase<String, String> {
  final _values = <String, String>{};
  int readCount = 0;

  @override
  String? operator [](Object? key) {
    readCount++;
    return _values[key];
  }

  @override
  void operator []=(String key, String value) => _values[key] = value;

  @override
  void clear() => _values.clear();

  @override
  Iterable<String> get keys => _values.keys;

  @override
  int get length => _values.length;

  @override
  String? remove(Object? key) => _values.remove(key);
}

void main() {
  test('active proxy state ignores an unrelated group switch', () {
    List<Group> buildGroups({required String fallbackNode}) => [
      const Group(
        type: GroupType.Selector,
        name: 'manual',
        all: [
          Proxy(name: 'auto', type: 'URLTest'),
          Proxy(name: 'fallback', type: 'Fallback'),
        ],
      ),
      const Group(type: GroupType.URLTest, name: 'auto', now: 'node-a'),
      Group(type: GroupType.Fallback, name: 'fallback', now: fallbackNode),
    ];

    final before = computeActiveSelectedProxyState(
      mode: Mode.rule,
      groups: buildGroups(fallbackNode: 'node-a'),
      selectedMap: const {'manual': 'auto'},
      currentGroupName: 'manual',
    );

    final after = computeActiveSelectedProxyState(
      mode: Mode.rule,
      groups: buildGroups(fallbackNode: 'node-b'),
      selectedMap: const {'manual': 'auto'},
      currentGroupName: 'manual',
    );

    expect(before, after);
  });

  test('active proxy state follows the active group switch', () {
    List<Group> buildGroups({required String autoNode}) => [
      const Group(
        type: GroupType.Selector,
        name: 'manual',
        all: [
          Proxy(name: 'auto', type: 'URLTest'),
          Proxy(name: 'fallback', type: 'Fallback'),
        ],
      ),
      Group(type: GroupType.URLTest, name: 'auto', now: autoNode),
      const Group(type: GroupType.Fallback, name: 'fallback', now: 'node-a'),
    ];

    final before = computeActiveSelectedProxyState(
      mode: Mode.rule,
      groups: buildGroups(autoNode: 'node-a'),
      selectedMap: const {'manual': 'auto'},
      currentGroupName: 'manual',
    );

    final after = computeActiveSelectedProxyState(
      mode: Mode.rule,
      groups: buildGroups(autoNode: 'node-b'),
      selectedMap: const {'manual': 'auto'},
      currentGroupName: 'manual',
    );

    expect(before, isNot(after));
  });

  test('delay sorting orders proxies by resolved delay', () {
    const defaultTestUrl = 'https://example.com/default';
    final groups = [
      Group(
        type: GroupType.Selector,
        name: 'root',
        all: const [
          Proxy(name: 'group-c', type: 'Selector'),
          Proxy(name: 'group-a', type: 'Selector'),
          Proxy(name: 'group-b', type: 'Selector'),
        ],
      ),
      const Group(type: GroupType.Selector, name: 'group-a'),
      const Group(type: GroupType.Selector, name: 'group-b'),
      const Group(type: GroupType.Selector, name: 'group-c'),
    ];
    final selectedMap = {
      'group-a': 'node-a',
      'group-b': 'node-b',
      'group-c': 'node-c',
    };
    final delayMap = {
      defaultTestUrl: {'node-a': 20, 'node-b': 10, 'node-c': 30},
    };

    final result = computeSort(
      groups: groups,
      sortType: ProxiesSortType.delay,
      delayMap: delayMap,
      selectedMap: selectedMap,
      defaultTestUrl: defaultTestUrl,
    );

    expect(result.first.all.map((proxy) => proxy.name), [
      'group-b',
      'group-a',
      'group-c',
    ]);
  });

  test('delay sorting resolves each proxy only once', () {
    const proxyCount = 2048;
    const defaultTestUrl = 'https://example.com/default';
    final selectedMap = _CountingSelectedMap();
    final delayMap = <String, Map<String, int?>>{};
    final groups = [
      Group(
        type: GroupType.Selector,
        name: 'root',
        all: List.generate(
          proxyCount,
          (index) => Proxy(name: 'group-$index', type: 'Selector'),
        ),
      ),
      for (var index = 0; index < proxyCount; index++)
        Group(type: GroupType.Selector, name: 'group-$index'),
    ];
    for (var index = 0; index < proxyCount; index++) {
      selectedMap['group-$index'] = 'node-$index';
    }
    delayMap[defaultTestUrl] = {
      for (var index = 0; index < proxyCount; index++)
        'node-$index': (index % 4) + 1,
    };

    computeSort(
      groups: groups,
      sortType: ProxiesSortType.delay,
      delayMap: delayMap,
      selectedMap: selectedMap,
      defaultTestUrl: defaultTestUrl,
    );

    expect(selectedMap.readCount, lessThan(proxyCount * 2));
  });

  test('delay comparison places groups before nodes with equal delay', () {
    const group = DelayState(delay: 10, group: true);
    const node = DelayState(delay: 10, group: false);

    expect(group.compareTo(node), -1);
    expect(node.compareTo(group), 1);
  });

  test('batch resolution keeps input order and resolves nested groups', () {
    final groups = [
      const Group(type: GroupType.Selector, name: 'group-a'),
      const Group(
        type: GroupType.Selector,
        name: 'group-b',
        testUrl: 'https://example.com/group-b',
      ),
    ];
    final selectedMap = {'group-a': 'group-b', 'group-b': 'node-b'};

    final states = computeRealSelectedProxyStates(
      ['group-a', 'node-a'],
      groups: groups,
      selectedMap: selectedMap,
    );

    expect(states, hasLength(2));
    expect(states[0].proxyName, 'node-b');
    expect(states[0].group, isTrue);
    expect(states[0].testUrl, 'https://example.com/group-b');
    expect(states[1].proxyName, 'node-a');
    expect(states[1].group, isFalse);
    expect(states[1].testUrl, isNull);
  });

  test('cycle resolution stops instead of looping forever', () {
    final groups = [
      const Group(type: GroupType.Selector, name: 'group-a'),
      const Group(type: GroupType.Selector, name: 'group-b'),
    ];
    const selectedMap = {'group-a': 'group-b', 'group-b': 'group-a'};

    final state = computeRealSelectedProxyState(
      'group-a',
      groups: groups,
      selectedMap: selectedMap,
    );

    expect(state.proxyName, isEmpty);
    expect(state.group, isTrue);
  }, timeout: const Timeout(Duration(milliseconds: 200)));

  test('delay sorting preserves whether each proxy is a group', () {
    const defaultTestUrl = 'https://example.com/default';
    final groups = [
      Group(
        type: GroupType.Selector,
        name: 'root',
        all: const [
          Proxy(name: 'node-b', type: 'Selector'),
          Proxy(name: 'group-a', type: 'Selector'),
        ],
      ),
      const Group(type: GroupType.Selector, name: 'group-a'),
    ];
    final delayMap = {
      defaultTestUrl: {'node-a': 10, 'node-b': 10},
    };

    final result = computeSort(
      groups: groups,
      sortType: ProxiesSortType.delay,
      delayMap: delayMap,
      selectedMap: const {'group-a': 'node-a'},
      defaultTestUrl: defaultTestUrl,
    );

    expect(result.first.all.map((proxy) => proxy.name), ['group-a', 'node-b']);
  });

  test('delay map updates batch changes without mutating source', () {
    final source = {
      'https://example.com/a': {'existing': 1},
      'https://example.com/b': {'kept': 2},
    };

    final result = updateDelayMap(source, [
      const Delay(url: 'https://example.com/a', name: 'existing', value: 0),
      const Delay(url: 'https://example.com/a', name: 'node-a', value: 10),
      const Delay(url: 'https://example.com/new', name: 'node-b', value: 20),
    ]);

    expect(result, {
      'https://example.com/a': {'existing': 0, 'node-a': 10},
      'https://example.com/b': {'kept': 2},
      'https://example.com/new': {'node-b': 20},
    });
    expect(source, {
      'https://example.com/a': {'existing': 1},
      'https://example.com/b': {'kept': 2},
    });
    expect(
      identical(
        result['https://example.com/b'],
        source['https://example.com/b'],
      ),
      isTrue,
    );
  });

  test('delay map update returns current state without changes', () {
    final source = {
      'https://example.com/a': {'node-a': 10},
    };

    final result = updateDelayMap(source, [
      const Delay(url: 'https://example.com/a', name: 'node-a', value: 10),
    ]);

    expect(identical(result, source), isTrue);
  });
}
