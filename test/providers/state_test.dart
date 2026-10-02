import 'dart:collection';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingGroupList extends ListBase<Group> {
  _CountingGroupList(this._groups);

  final List<Group> _groups;
  int elementReadCount = 0;

  @override
  Group operator [](int index) {
    elementReadCount++;
    return _groups[index];
  }

  @override
  void operator []=(int index, Group value) => _groups[index] = value;

  @override
  int get length => _groups.length;

  @override
  set length(int value) => _groups.length = value;
}

class _CountingProxyList extends ListBase<Proxy> {
  _CountingProxyList(this._proxies);

  final List<Proxy> _proxies;
  int elementReadCount = 0;

  @override
  Proxy operator [](int index) {
    elementReadCount++;
    return _proxies[index];
  }

  @override
  void operator []=(int index, Proxy value) => _proxies[index] = value;

  @override
  int get length => _proxies.length;

  @override
  set length(int value) => _proxies.length = value;
}

void main() {
  test('proxy descriptions reuse one group index', () {
    const groupCount = 64;
    final sourceGroups = <Group>[];
    final selectedMap = <String, String>{};
    for (var index = 0; index < groupCount; index++) {
      sourceGroups.add(Group(type: GroupType.Selector, name: 'group-$index'));
      selectedMap['group-$index'] = 'node-$index';
    }
    final groups = _CountingGroupList(sourceGroups);

    final container = ProviderContainer(
      overrides: [
        groupsProvider.overrideWithValue(groups),
        selectedMapProvider.overrideWith((_) => selectedMap),
      ],
    );
    addTearDown(container.dispose);

    final subscriptions = [
      for (var index = 0; index < groupCount; index++)
        container.listen(
          getProxyDescProvider(Proxy(name: 'group-$index', type: 'Selector')),
          (_, _) {},
        ),
    ];

    expect(
      subscriptions.map((subscription) => subscription.read()),
      equals(List.generate(groupCount, (index) => 'Selector(node-$index)')),
    );
    expect(groups.elementReadCount, lessThan(groupCount * 3));
  });

  test('real selected proxy states share the group resolver', () {
    const proxyCount = 64;
    final sourceGroups = <Group>[];
    final selectedMap = <String, String>{};
    for (var index = 0; index < proxyCount; index++) {
      sourceGroups.add(Group(type: GroupType.Selector, name: 'group-$index'));
      selectedMap['group-$index'] = 'node-$index';
    }
    final groups = _CountingGroupList(sourceGroups);

    final container = ProviderContainer(
      overrides: [
        groupsProvider.overrideWithValue(groups),
        selectedMapProvider.overrideWith((_) => selectedMap),
      ],
    );
    addTearDown(container.dispose);

    final subscriptions = [
      for (var index = 0; index < proxyCount; index++)
        container.listen(
          realSelectedProxyStateProvider('group-$index'),
          (_, _) {},
        ),
    ];

    expect(
      subscriptions.map((subscription) => subscription.read().proxyName),
      equals(List.generate(proxyCount, (index) => 'node-$index')),
    );
    expect(groups.elementReadCount, lessThan(proxyCount * 2));
  });

  test('selected proxy names reuse one group index', () {
    const groupCount = 64;
    final sourceGroups = <Group>[];
    final selectedMap = <String, String>{};
    for (var index = 0; index < groupCount; index++) {
      sourceGroups.add(Group(type: GroupType.Selector, name: 'group-$index'));
      selectedMap['group-$index'] = 'node-$index';
    }
    final groups = _CountingGroupList(sourceGroups);

    final container = ProviderContainer(
      overrides: [
        groupsProvider.overrideWithValue(groups),
        selectedMapProvider.overrideWith((_) => selectedMap),
      ],
    );
    addTearDown(container.dispose);

    final subscriptions = [
      for (var index = 0; index < groupCount; index++)
        container.listen(
          getSelectedProxyNameProvider('group-$index'),
          (_, _) {},
        ),
    ];

    expect(
      subscriptions.map((subscription) => subscription.read()),
      equals(List.generate(groupCount, (index) => 'node-$index')),
    );
    expect(groups.elementReadCount, lessThan(groupCount * 2));
  });

  test('clearing group selection preserves untouched proxy lists', () {
    const proxyCount = 1024;
    final proxies = _CountingProxyList([
      for (var index = 0; index < proxyCount; index++)
        Proxy(name: 'node-$index', type: 'Shadowsocks'),
    ]);

    final container = ProviderContainer(
      overrides: [
        patchClashConfigProvider.overrideWithValue(defaultClashConfig),
        groupsProvider.overrideWithValue([
          Group(
            type: GroupType.Selector,
            name: 'group',
            hidden: false,
            now: 'node-0',
            all: proxies,
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(currentGroupsStateProvider);

    expect(state.value.single.now, isEmpty);
    expect(proxies.elementReadCount, proxyCount);
  });

  test('rule mode skips clearing hidden groups', () {
    const proxyCount = 1024;
    final proxies = _CountingProxyList([
      for (var index = 0; index < proxyCount; index++)
        Proxy(name: 'node-$index', type: 'Shadowsocks'),
    ]);

    final container = ProviderContainer(
      overrides: [
        patchClashConfigProvider.overrideWithValue(defaultClashConfig),
        groupsProvider.overrideWithValue([
          const Group(type: GroupType.Selector, name: 'visible', hidden: false),
          Group(
            type: GroupType.Selector,
            name: 'hidden',
            hidden: true,
            now: 'node-0',
            all: proxies,
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(currentGroupsStateProvider);

    expect(state.value.map((group) => group.name), ['visible']);
    expect(proxies.elementReadCount, 0);
  });

  test('clearing selection removes current nodes from groups and proxies', () {
    final container = ProviderContainer(
      overrides: [
        patchClashConfigProvider.overrideWithValue(defaultClashConfig),
        groupsProvider.overrideWithValue([
          Group(
            type: GroupType.Selector,
            name: 'group',
            hidden: false,
            now: 'node-a',
            all: const [
              Proxy(name: 'node-a', type: 'Selector', now: 'node-b'),
              Proxy(name: 'node-b', type: 'Shadowsocks'),
            ],
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);

    final group = container.read(currentGroupsStateProvider).value.single;

    expect(group.now, isEmpty);
    expect(group.all[0].now, isEmpty);
    expect(group.all[1].now, isNull);
  });
}
