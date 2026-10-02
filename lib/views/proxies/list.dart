import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'common.dart';

enum ProxiesListItemKind {
  header,
  headerSpacing,
  proxyRow,
  rowSpacing,
  tailSpacing,
}

class ProxiesListItem {
  const ProxiesListItem({
    required this.kind,
    required this.groupIndex,
    this.proxyStartIndex = 0,
    this.proxyEndIndex = 0,
  });

  final ProxiesListItemKind kind;
  final int groupIndex;
  final int proxyStartIndex;
  final int proxyEndIndex;
}

class ProxiesListLayout {
  const ProxiesListLayout({
    required this.items,
    required this.extents,
    required this.headerIndexes,
    required this.headerOffsets,
  });

  final List<ProxiesListItem> items;
  final List<double> extents;
  final List<int> headerIndexes;
  final List<double> headerOffsets;
}

ProxiesListLayout computeProxiesListLayout({
  required List<Group> groups,
  required Set<String> currentUnfoldSet,
  required int columns,
  required double headerHeight,
  required double proxyItemHeight,
}) {
  final effectiveColumns = columns < 1 ? 1 : columns;
  final items = <ProxiesListItem>[];
  final extents = <double>[];
  final headerIndexes = <int>[];
  final headerOffsets = <double>[];
  var currentOffset = 0.0;

  void addItem(ProxiesListItem item, double extent) {
    items.add(item);
    extents.add(extent);
    currentOffset += extent;
  }

  for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    final group = groups[groupIndex];
    headerIndexes.add(items.length);
    headerOffsets.add(currentOffset);
    addItem(
      ProxiesListItem(kind: ProxiesListItemKind.header, groupIndex: groupIndex),
      headerHeight,
    );
    addItem(
      ProxiesListItem(
        kind: ProxiesListItemKind.headerSpacing,
        groupIndex: groupIndex,
      ),
      8,
    );

    if (!currentUnfoldSet.contains(group.name)) {
      continue;
    }

    final proxies = group.all;
    final rowCount = (proxies.length / effectiveColumns).ceil();
    for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
      if (rowIndex > 0) {
        addItem(
          ProxiesListItem(
            kind: ProxiesListItemKind.rowSpacing,
            groupIndex: groupIndex,
          ),
          8,
        );
      }
      final startIndex = rowIndex * effectiveColumns;
      final endIndex = min(startIndex + effectiveColumns, proxies.length);
      addItem(
        ProxiesListItem(
          kind: ProxiesListItemKind.proxyRow,
          groupIndex: groupIndex,
          proxyStartIndex: startIndex,
          proxyEndIndex: endIndex,
        ),
        proxyItemHeight,
      );
    }
    addItem(
      ProxiesListItem(
        kind: ProxiesListItemKind.tailSpacing,
        groupIndex: groupIndex,
      ),
      8,
    );
  }

  return ProxiesListLayout(
    items: items,
    extents: extents,
    headerIndexes: headerIndexes,
    headerOffsets: headerOffsets,
  );
}

class ProxiesListView extends StatefulWidget {
  const ProxiesListView({super.key});

  @override
  State<ProxiesListView> createState() => _ProxiesListViewState();
}

class _ProxiesListViewState extends State<ProxiesListView> {
  final _controller = ScrollController();
  final _headerStateNotifier = ValueNotifier<ProxiesListHeaderSelectorState?>(
    null,
  );
  List<double> _headerOffset = [];
  double containerHeight = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_adjustHeader);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustHeader();
    });
  }

  ProxiesListHeaderSelectorState _getProxiesListHeaderSelectorState(
    double initOffset,
  ) {
    final index = _headerOffset.findInterval(initOffset);
    final currentIndex = index;
    double headerOffset = 0.0;
    if (index + 1 <= _headerOffset.length - 1) {
      final endOffset = _headerOffset[index + 1];
      final startOffset = endOffset - listHeaderHeight - 8;
      if (initOffset > startOffset && initOffset < endOffset) {
        headerOffset = initOffset - startOffset;
      }
    }
    return ProxiesListHeaderSelectorState(
      offset: max(headerOffset, 0),
      currentIndex: currentIndex,
    );
  }

  void _adjustHeader() {
    _headerStateNotifier.value = _getProxiesListHeaderSelectorState(
      !_controller.hasClients ? 0 : _controller.offset,
    );
  }

  @override
  void dispose() {
    _headerStateNotifier.dispose();
    _controller.removeListener(_adjustHeader);
    _controller.dispose();
    super.dispose();
  }

  void _handleChange(Set<String> currentUnfoldSet, String groupName) {
    _autoScrollToGroup(groupName);
    final tempUnfoldSet = Set<String>.from(currentUnfoldSet);
    if (tempUnfoldSet.contains(groupName)) {
      tempUnfoldSet.remove(groupName);
    } else {
      tempUnfoldSet.add(groupName);
    }
    globalState.appController.updateCurrentUnfoldSet(tempUnfoldSet);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustHeader();
    });
  }

  Widget _buildItem(
    WidgetRef ref, {
    required ProxiesListLayout layout,
    required List<Group> groups,
    required Set<String> currentUnfoldSet,
    required ProxyCardType cardType,
    required int columns,
    required int index,
  }) {
    final item = layout.items[index];
    final group = groups[item.groupIndex];
    final groupName = group.name;
    return switch (item.kind) {
      ProxiesListItemKind.header => ListHeader(
        onScrollToSelected: _scrollToGroupSelected,
        isExpand: currentUnfoldSet.contains(groupName),
        group: group,
        onChange: (String groupName) {
          _handleChange(currentUnfoldSet, groupName);
        },
      ),
      ProxiesListItemKind.proxyRow => _buildProxyRow(
        group: group,
        start: item.proxyStartIndex,
        end: item.proxyEndIndex,
        columns: columns,
        cardType: cardType,
      ),
      ProxiesListItemKind.headerSpacing ||
      ProxiesListItemKind.rowSpacing ||
      ProxiesListItemKind.tailSpacing => const SizedBox(height: 8),
    };
  }

  Widget _buildProxyRow({
    required Group group,
    required int start,
    required int end,
    required int columns,
    required ProxyCardType cardType,
  }) {
    final groupName = group.name;
    final proxies = group.all.sublist(start, end);
    final children = proxies
        .map<Widget>(
          (proxy) => Flexible(
            child: SizedBox(
              height: getItemHeight(cardType),
              child: ProxyCard(
                testUrl: group.testUrl,
                type: cardType,
                groupType: group.type,
                key: ValueKey('$groupName.${proxy.name}'),
                proxy: proxy,
                groupName: groupName,
              ),
            ),
          ),
        )
        .fill(columns, filler: (_) => const Flexible(child: SizedBox()))
        .separated(const SizedBox(width: 8));
    return Row(children: children.toList());
  }

  Widget _buildHeader(
    WidgetRef ref, {
    required Group group,
    required Set<String> currentUnfoldSet,
  }) {
    final groupName = group.name;
    final isExpand = currentUnfoldSet.contains(groupName);
    return SizedBox(
      height: listHeaderHeight,
      child: ListHeader(
        enterAnimated: false,
        onScrollToSelected: _scrollToGroupSelected,
        key: Key(groupName),
        isExpand: isExpand,
        group: group,
        onChange: (String groupName) {
          _handleChange(currentUnfoldSet, groupName);
        },
      ),
    );
  }

  double _getGroupOffset(String groupName) {
    if (_controller.position.maxScrollExtent == 0) {
      return 0;
    }
    final currentGroups = globalState.appController.getCurrentGroups();
    final findIndex = currentGroups.indexWhere(
      (item) => item.name == groupName,
    );
    final index = findIndex != -1 ? findIndex : 0;
    return _headerOffset[index];
  }

  void _scrollToMakeVisibleWithPadding({
    required double containerHeight,
    required double pixels,
    required double start,
    required double end,
    double padding = 24,
  }) {
    final visibleStart = pixels;
    final visibleEnd = pixels + containerHeight;

    final isElementVisible = start >= visibleStart && end <= visibleEnd;
    if (isElementVisible) {
      return;
    }

    double targetScrollOffset;

    if (end <= visibleStart) {
      targetScrollOffset = start;
    } else if (start >= visibleEnd) {
      targetScrollOffset = end - containerHeight + padding;
    } else {
      final visibleTopPart = end - visibleStart;
      final visibleBottomPart = visibleEnd - start;
      if (visibleTopPart.abs() >= visibleBottomPart.abs()) {
        targetScrollOffset = end - containerHeight + padding;
      } else {
        targetScrollOffset = start;
      }
    }

    targetScrollOffset = targetScrollOffset.clamp(
      _controller.position.minScrollExtent,
      _controller.position.maxScrollExtent,
    );

    _controller.jumpTo(targetScrollOffset);
  }

  void _autoScrollToGroup(String groupName) {
    final pixels = _controller.position.pixels;
    final offset = _getGroupOffset(groupName);
    _scrollToMakeVisibleWithPadding(
      containerHeight: containerHeight,
      pixels: pixels,
      start: offset,
      end: offset + listHeaderHeight,
    );
  }

  void _scrollToGroupSelected(String groupName) {
    final currentInitOffset = _getGroupOffset(groupName);
    final currentGroups = globalState.appController.getCurrentGroups();
    final proxies = currentGroups.getGroup(groupName)?.all;
    _jumpTo(
      currentInitOffset +
          8 +
          getScrollToSelectedOffset(
            groupName: groupName,
            proxies: proxies ?? [],
          ),
    );
  }

  void _jumpTo(double offset) {
    if (mounted && _controller.hasClients) {
      _controller.animateTo(
        offset.clamp(
          _controller.position.minScrollExtent,
          _controller.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, _) {
        final state = ref.watch(proxiesListStateProvider);
        ref.watch(themeSettingProvider.select((state) => state.textScale));
        if (state.groups.isEmpty) {
          return NullStatus(
            illustration: ProxyEmptyIllustration(),
            label: appLocalizations.nullTip(appLocalizations.proxies),
          );
        }
        final layout = computeProxiesListLayout(
          groups: state.groups,
          currentUnfoldSet: state.currentUnfoldSet,
          columns: state.columns,
          headerHeight: listHeaderHeight,
          proxyItemHeight: getItemHeight(state.proxyCardType),
        );
        _headerOffset = layout.headerOffsets;
        return CommonScrollBar(
          controller: _controller,
          thumbVisibility: true,
          trackVisibility: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: ScrollConfiguration(
                  behavior: HiddenBarScrollBehavior(),
                  child: ListView.builder(
                    key: proxiesListStoreKey,
                    padding: const EdgeInsets.all(16),
                    controller: _controller,
                    itemExtentBuilder: (index, _) {
                      return layout.extents[index];
                    },
                    itemCount: layout.items.length,
                    itemBuilder: (_, index) {
                      return _buildItem(
                        ref,
                        layout: layout,
                        groups: state.groups,
                        currentUnfoldSet: state.currentUnfoldSet,
                        cardType: state.proxyCardType,
                        columns: state.columns,
                        index: index,
                      );
                    },
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (_, container) {
                  containerHeight = container.maxHeight;
                  return ValueListenableBuilder(
                    valueListenable: _headerStateNotifier,
                    builder: (_, headerState, _) {
                      if (headerState == null) {
                        return SizedBox();
                      }
                      final index =
                          headerState.currentIndex > state.groups.length - 1
                          ? 0
                          : headerState.currentIndex;
                      if (index < 0 || state.groups.isEmpty) {
                        return Container();
                      }
                      return Stack(
                        children: [
                          Positioned(
                            top: -headerState.offset,
                            child: Container(
                              width: container.maxWidth,
                              color: context.colorScheme.surface,
                              padding: const EdgeInsets.only(
                                top: 16,
                                left: 16,
                                right: 16,
                                bottom: 8,
                              ),
                              child: _buildHeader(
                                ref,
                                group: state.groups[index],
                                currentUnfoldSet: state.currentUnfoldSet,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class ListHeader extends StatefulWidget {
  final Group group;

  final Function(String groupName) onChange;
  final Function(String groupName) onScrollToSelected;
  final bool isExpand;

  final bool enterAnimated;

  const ListHeader({
    super.key,
    this.enterAnimated = true,
    required this.group,
    required this.onChange,
    required this.onScrollToSelected,
    required this.isExpand,
  });

  @override
  State<ListHeader> createState() => _ListHeaderState();
}

class _ListHeaderState extends State<ListHeader> {
  var isLock = false;

  String get icon => widget.group.icon;

  String get groupName => widget.group.name;

  String get groupType => widget.group.type.name;

  bool get isExpand => widget.isExpand;

  Future<void> _delayTest() async {
    if (isLock) return;
    isLock = true;
    await delayTest(widget.group.all, widget.group.testUrl);
    isLock = false;
  }

  void _handleChange(String groupName) {
    widget.onChange(groupName);
  }

  Widget _buildIcon() {
    return Consumer(
      builder: (_, ref, child) {
        final iconStyle = ref.watch(
          proxiesStyleSettingProvider.select((state) => state.iconStyle),
        );
        return switch (iconStyle) {
          ProxiesIconStyle.standard => LayoutBuilder(
            builder: (_, constraints) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    height: constraints.maxHeight,
                    width: constraints.maxWidth,
                    alignment: Alignment.center,
                    padding: EdgeInsets.all(6.ap),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: context.colorScheme.secondaryContainer,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CommonTargetIcon(
                      src: icon,
                      size: constraints.maxHeight - 12.ap,
                    ),
                  ),
                ),
              );
            },
          ),
          ProxiesIconStyle.icon => Container(
            margin: const EdgeInsets.only(right: 16),
            child: LayoutBuilder(
              builder: (_, constraints) {
                return CommonTargetIcon(
                  src: icon,
                  size: constraints.maxHeight - 8,
                );
              },
            ),
          ),
          ProxiesIconStyle.none => Container(),
        };
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      enterAnimated: widget.enterAnimated,
      key: widget.key,
      radius: 18.ap,
      type: CommonCardType.filled,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  _buildIcon(),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EmojiText(
                          groupName,
                          style: context.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          flex: 1,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                groupType,
                                style: context.textTheme.labelMedium?.toLight,
                              ),
                              Flexible(
                                flex: 1,
                                child: Consumer(
                                  builder: (_, ref, _) {
                                    final proxyName = ref
                                        .watch(
                                          getSelectedProxyNameProvider(
                                            groupName,
                                          ),
                                        )
                                        .getSafeValue('');
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        if (proxyName.isNotEmpty) ...[
                                          Flexible(
                                            flex: 1,
                                            child: EmojiText(
                                              overflow: TextOverflow.ellipsis,
                                              ' · $proxyName',
                                              style: context
                                                  .textTheme
                                                  .labelMedium
                                                  ?.toLight,
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (isExpand) ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.all(2),
                    onPressed: () {
                      widget.onScrollToSelected(groupName);
                    },
                    style: ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    iconSize: 19,
                    icon: const Icon(Icons.adjust),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.all(2),
                    onPressed: _delayTest,
                    style: ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.network_ping),
                  ),
                  const SizedBox(width: 6),
                ] else
                  SizedBox(width: 6),
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.all(2),
                  iconSize: 24,
                  style: ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    _handleChange(groupName);
                  },
                  icon: CommonExpandIcon(expand: isExpand),
                ),
              ],
            ),
          ],
        ),
      ),
      onPressed: () {
        _handleChange(groupName);
      },
    );
  }
}
