import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

import 'string.dart';

List<Group> computeSort({
  required List<Group> groups,
  required ProxiesSortType sortType,
  required DelayMap delayMap,
  required Map<String, String> selectedMap,
  required String defaultTestUrl,
}) {
  final delayStateResolver = switch (sortType) {
    ProxiesSortType.delay => _RealSelectedProxyResolver(groups, selectedMap),
    _ => null,
  };
  return groups.map((group) {
    final proxies = group.all;
    final newProxies = switch (sortType) {
      ProxiesSortType.none => proxies,
      ProxiesSortType.delay => _sortOfDelay(
        groups: groups,
        delayStateResolver: delayStateResolver!,
        proxies: proxies,
        delayMap: delayMap,
        testUrl: group.testUrl.getSafeValue(defaultTestUrl),
      ),
      ProxiesSortType.name => _sortOfName(proxies),
    };
    return group.copyWith(all: newProxies);
  }).toList();
}

DelayState computeProxyDelayState({
  required String proxyName,
  required String testUrl,
  required List<Group> groups,
  required Map<String, String> selectedMap,
  required DelayMap delayMap,
}) {
  final state = _RealSelectedProxyResolver(
    groups,
    selectedMap,
  ).resolve(proxyName);
  final currentDelayMap = delayMap[state.testUrl.getSafeValue(testUrl)] ?? {};
  final delay = currentDelayMap[state.proxyName];
  return DelayState(delay: delay ?? 0, group: state.group);
}

SelectedProxyState computeRealSelectedProxyState(
  String proxyName, {
  required List<Group> groups,
  required Map<String, String> selectedMap,
}) {
  return _RealSelectedProxyResolver(groups, selectedMap).resolve(proxyName);
}

List<SelectedProxyState> computeRealSelectedProxyStates(
  Iterable<String> proxyNames, {
  required List<Group> groups,
  required Map<String, String> selectedMap,
}) {
  final resolver = _RealSelectedProxyResolver(groups, selectedMap);
  return [for (final proxyName in proxyNames) resolver.resolve(proxyName)];
}

DelayMap updateDelayMap(DelayMap delayMap, Iterable<Delay> delays) {
  var newDelayMap = delayMap;
  final changedUrls = <String>{};
  for (final delay in delays) {
    if (delayMap[delay.url]?[delay.name] == delay.value) {
      continue;
    }
    if (identical(newDelayMap, delayMap)) {
      newDelayMap = Map.from(delayMap);
    }
    if (changedUrls.add(delay.url)) {
      newDelayMap[delay.url] = Map.from(delayMap[delay.url] ?? {});
    }
    newDelayMap[delay.url]![delay.name] = delay.value;
  }
  return newDelayMap;
}

final class _RealSelectedProxyResolver {
  _RealSelectedProxyResolver(this._groups, this._selectedMap) {
    for (final group in _groups) {
      _groupsByName.putIfAbsent(group.name, () => group);
    }
  }

  final List<Group> _groups;
  final Map<String, String> _selectedMap;
  final _groupsByName = <String, Group>{};
  final _statesByName = <String, SelectedProxyState>{};

  SelectedProxyState resolve(String proxyName) {
    return _statesByName.putIfAbsent(
      proxyName,
      () => _resolve(SelectedProxyState(proxyName: proxyName)),
    );
  }

  SelectedProxyState _resolve(SelectedProxyState state) {
    var currentState = state;
    while (currentState.proxyName.isNotEmpty) {
      final newState = currentState.copyWith(group: true);
      final group = _groupsByName[newState.proxyName];
      if (group == null) return newState;
      final currentSelectedName = group.getCurrentSelectedName(
        _selectedMap[newState.proxyName] ?? '',
      );
      if (currentSelectedName.isEmpty) return newState;
      currentState = newState.copyWith(
        proxyName: currentSelectedName,
        testUrl: group.testUrl,
      );
    }
    return currentState;
  }
}

List<Proxy> _sortOfDelay({
  required List<Group> groups,
  required _RealSelectedProxyResolver delayStateResolver,
  required List<Proxy> proxies,
  required DelayMap delayMap,
  required String testUrl,
}) {
  final sortableProxies = proxies
      .map(
        (proxy) => _DelaySortableProxy(
          proxy: proxy,
          delayState: _computeProxyDelayState(
            proxyName: proxy.name,
            testUrl: testUrl,
            delayStateResolver: delayStateResolver,
            delayMap: delayMap,
          ),
        ),
      )
      .toList();
  sortableProxies.sort((a, b) => a.delayState.compareTo(b.delayState));
  return sortableProxies.map((sortableProxy) => sortableProxy.proxy).toList();
}

DelayState _computeProxyDelayState({
  required String proxyName,
  required String testUrl,
  required _RealSelectedProxyResolver delayStateResolver,
  required DelayMap delayMap,
}) {
  final state = delayStateResolver.resolve(proxyName);
  final currentDelayMap = delayMap[state.testUrl.getSafeValue(testUrl)] ?? {};
  final delay = currentDelayMap[state.proxyName];
  return DelayState(delay: delay ?? 0, group: state.group);
}

final class _DelaySortableProxy {
  const _DelaySortableProxy({required this.proxy, required this.delayState});

  final Proxy proxy;
  final DelayState delayState;
}

List<Proxy> _sortOfName(List<Proxy> proxies) {
  return List.of(proxies)..sort((a, b) => a.name.compareTo(b.name));
}
