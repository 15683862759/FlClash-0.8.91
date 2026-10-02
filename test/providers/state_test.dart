import 'dart:collection';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
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

void main() {
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
}
