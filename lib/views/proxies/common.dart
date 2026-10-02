import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';

double get listHeaderHeight {
  final measure = globalState.measure;
  return 20 + measure.titleMediumHeight + 4 + measure.bodyMediumHeight + 2;
}

double getItemHeight(ProxyCardType proxyCardType) {
  final measure = globalState.measure;
  final baseHeight =
      16 + measure.bodyMediumHeight * 2 + measure.bodySmallHeight + 8 + 4;
  return switch (proxyCardType) {
    ProxyCardType.expand => baseHeight + measure.labelSmallHeight + 6,
    ProxyCardType.shrink => baseHeight,
    ProxyCardType.min => baseHeight - measure.bodyMediumHeight,
  };
}

Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) async {
  final appController = globalState.appController;
  final groups = globalState.appState.groups;
  final selectedMap = globalState.config.currentProfile?.selectedMap ?? {};
  final state = computeRealSelectedProxyState(
    proxy.name,
    groups: groups,
    selectedMap: selectedMap,
  );
  final currentTestUrl = state.testUrl.getSafeValue(
    appController.getRealTestUrl(testUrl),
  );
  if (state.proxyName.isEmpty) {
    return;
  }
  appController.setDelay(
    Delay(url: currentTestUrl, name: state.proxyName, value: 0),
  );
  appController.setDelay(
    await coreController.getDelay(currentTestUrl, state.proxyName),
  );
}

Future<void> runDelayTests(
  Iterable<SelectedProxyState> proxyStates, {
  required String defaultTestUrl,
  required Future<Delay> Function(String url, String proxyName) getDelay,
  required void Function(List<Delay> delays) setDelays,
  int concurrencyLimit = 100,
  Duration resultBatchInterval = const Duration(milliseconds: 16),
}) async {
  final uniqueStates = <(String, String), SelectedProxyState>{};
  final loadingDelays = <Delay>[];
  for (final state in proxyStates) {
    final url = state.testUrl.getSafeValue(defaultTestUrl);
    final name = state.proxyName;
    if (name.isEmpty || uniqueStates.containsKey((url, name))) {
      continue;
    }
    uniqueStates[(url, name)] = state;
    loadingDelays.add(Delay(url: url, name: name, value: 0));
  }
  if (loadingDelays.isNotEmpty) {
    setDelays(loadingDelays);
  }

  final pendingDelays = <Delay>[];
  Timer? resultTimer;

  void flushPendingDelays() {
    resultTimer?.cancel();
    resultTimer = null;
    if (pendingDelays.isEmpty) {
      return;
    }
    final delays = List.of(pendingDelays);
    pendingDelays.clear();
    setDelays(delays);
  }

  try {
    await forEachBounded(uniqueStates.values, (state) async {
      final url = state.testUrl.getSafeValue(defaultTestUrl);
      final name = state.proxyName;
      pendingDelays.add(await getDelay(url, name));
      resultTimer ??= Timer(resultBatchInterval, flushPendingDelays);
    }, concurrencyLimit: concurrencyLimit);
  } finally {
    flushPendingDelays();
  }
}

Future<void> delayTest(List<Proxy> proxies, [String? testUrl]) async {
  final appController = globalState.appController;
  final proxyNames = proxies.map((proxy) => proxy.name).toSet().toList();
  final groups = globalState.appState.groups;
  final selectedMap = globalState.config.currentProfile?.selectedMap ?? {};
  final defaultTestUrl = appController.getRealTestUrl(testUrl);
  final proxyStates = computeRealSelectedProxyStates(
    proxyNames,
    groups: groups,
    selectedMap: selectedMap,
  );
  await runDelayTests(
    proxyStates,
    defaultTestUrl: defaultTestUrl,
    getDelay: coreController.getDelay,
    setDelays: appController.setDelays,
    concurrencyLimit: 100,
  );
  appController.addSortNum();
}

double getScrollToSelectedOffset({
  required String groupName,
  required List<Proxy> proxies,
}) {
  final appController = globalState.appController;
  final columns = appController.getProxiesColumns();
  final proxyCardType = globalState.config.proxiesStyle.cardType;
  final selectedProxyName = appController.getSelectedProxyName(groupName);
  final findSelectedIndex = proxies.indexWhere(
    (proxy) => proxy.name == selectedProxyName,
  );
  final selectedIndex = findSelectedIndex != -1 ? findSelectedIndex : 0;
  final rows = (selectedIndex / columns).floor();
  return rows * getItemHeight(proxyCardType) + (rows - 1) * 8;
}
