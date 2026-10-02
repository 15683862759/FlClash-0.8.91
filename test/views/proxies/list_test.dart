import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/proxies/list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('proxies list layout describes lazy rows and header offsets', () {
    final layout = computeProxiesListLayout(
      groups: [
        Group(
          name: 'group-a',
          type: GroupType.Selector,
          all: [
            for (var index = 0; index < 5; index++)
              Proxy(name: 'node-$index', type: 'Selector'),
          ],
        ),
        const Group(name: 'group-b', type: GroupType.Selector),
      ],
      currentUnfoldSet: const {'group-a'},
      columns: 2,
      headerHeight: 100,
      proxyItemHeight: 40,
    );

    expect(layout.items.map((item) => item.kind), [
      ProxiesListItemKind.header,
      ProxiesListItemKind.headerSpacing,
      ProxiesListItemKind.proxyRow,
      ProxiesListItemKind.rowSpacing,
      ProxiesListItemKind.proxyRow,
      ProxiesListItemKind.rowSpacing,
      ProxiesListItemKind.proxyRow,
      ProxiesListItemKind.tailSpacing,
      ProxiesListItemKind.header,
      ProxiesListItemKind.headerSpacing,
    ]);
    expect(layout.extents, [100, 8, 40, 8, 40, 8, 40, 8, 100, 8]);
    expect(
      layout.items
          .where((item) => item.kind == ProxiesListItemKind.proxyRow)
          .map(
            (item) => [
              item.groupIndex,
              item.proxyStartIndex,
              item.proxyEndIndex,
            ],
          ),
      [
        [0, 0, 2],
        [0, 2, 4],
        [0, 4, 5],
      ],
    );
    expect(layout.headerIndexes, [0, 8]);
    expect(layout.headerOffsets, [0, 252]);
  });

  test('proxies list layout keeps expanded empty groups bounded', () {
    final layout = computeProxiesListLayout(
      groups: [const Group(name: 'group-a', type: GroupType.Selector)],
      currentUnfoldSet: const {'group-a'},
      columns: 2,
      headerHeight: 100,
      proxyItemHeight: 40,
    );

    expect(layout.items.map((item) => item.kind), [
      ProxiesListItemKind.header,
      ProxiesListItemKind.headerSpacing,
      ProxiesListItemKind.tailSpacing,
    ]);
    expect(layout.headerIndexes, [0]);
    expect(layout.headerOffsets, [0]);
  });
}
