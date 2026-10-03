import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/proxies.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';

class CoreController {
  static CoreController? _instance;
  late CoreHandlerInterface _interface;
  final ProxiesSnapshotCache _proxiesSnapshotCache = ProxiesSnapshotCache();

  CoreController._internal() {
    if (system.isAndroid) {
      _interface = coreLib!;
    } else {
      _interface = coreService!;
    }
  }

  factory CoreController() {
    _instance ??= CoreController._internal();
    return _instance!;
  }

  bool get isCompleted => _interface.completer.isCompleted;

  Future<String> preload() {
    return _interface.preload();
  }

  static Future<void> initGeo() async {
    final homePath = await appPath.homeDirPath;
    final homeDir = Directory(homePath);
    final isExists = await homeDir.exists();
    if (!isExists) {
      await homeDir.create(recursive: true);
    }
    const geoFileNameList = [MMDB, GEOIP, GEOSITE, ASN];
    try {
      for (final geoFileName in geoFileNameList) {
        final geoFile = File(join(homePath, geoFileName));
        final isExists = await geoFile.exists();
        if (isExists) {
          continue;
        }
        final data = await rootBundle.load('assets/data/$geoFileName');
        List<int> bytes = data.buffer.asUint8List();
        await geoFile.writeAsBytes(bytes, flush: true);
      }
    } catch (e) {
      exit(0);
    }
  }

  Future<bool> init(int version) async {
    await initGeo();
    final homeDirPath = await appPath.homeDirPath;
    return await _interface.init(
      InitParams(homeDir: homeDirPath, version: version),
    );
  }

  Future<void> shutdown() async {
    await _interface.shutdown();
    _proxiesSnapshotCache.clear();
  }

  FutureOr<bool> get isInit => _interface.isInit;

  Future<String> validateConfig(String data) async {
    final path = await appPath.validateFilePath;
    await globalState.genValidateFile(path, data);
    final res = await _interface.validateConfig(path);
    await File(path).delete();
    return res;
  }

  Future<String> validateConfigFormBytes(Uint8List bytes) async {
    final path = await appPath.validateFilePath;
    await globalState.genValidateFileFormBytes(path, bytes);
    final res = await _interface.validateConfig(path);
    await File(path).delete();
    return res;
  }

  Future<String> updateConfig(UpdateParams updateParams) async {
    return await _interface.updateConfig(updateParams);
  }

  Future<String> setupConfig({
    required SetupParams params,
    required SetupState setupState,
    VoidCallback? preloadInvoke,
  }) async {
    final res = _interface.setupConfig(params);
    _proxiesSnapshotCache.clear();
    if (preloadInvoke != null) {
      preloadInvoke();
    }
    return res;
  }

  Future<List<Group>> getProxiesGroups({
    required ProxiesSortType sortType,
    required DelayMap delayMap,
    required Map<String, String> selectedMap,
    required String defaultTestUrl,
  }) async {
    final snapshot = await _interface.getProxiesSnapshot();
    if (snapshot.isEmpty) return const [];
    final signature = snapshot['signature'].toString();
    final states = snapshot['states'] as Map<Object?, Object?>? ?? const {};
    final snapshotStates = ProxiesSnapshotCache.parseStates(states);
    List<Group>? baseGroups;
    final proxies = snapshot['proxies'] as Map<Object?, Object?>?;
    if (proxies != null) {
      if (proxies.isEmpty) return const [];
      baseGroups = await Isolate.run<List<Group>>(
        () => ProxiesSnapshotCache.parse(proxies),
      );
    }
    return _proxiesSnapshotCache.update(
      signature: signature,
      baseGroups: baseGroups,
      states: snapshotStates,
      sortType: sortType,
      delayMap: delayMap,
      selectedMap: selectedMap,
      defaultTestUrl: defaultTestUrl,
    );
  }

  FutureOr<String> changeProxy(ChangeProxyParams changeProxyParams) async {
    return await _interface.changeProxy(changeProxyParams);
  }

  Future<List<TrackerInfo>> getConnections() async {
    final res = await _interface.getConnections();
    if (res.isEmpty) {
      return const [];
    }
    return parseConnections(res);
  }

  static Future<List<TrackerInfo>> parseConnections(String res) {
    return Isolate.run(() {
      if (res.isEmpty) {
        return const <TrackerInfo>[];
      }
      final connectionsData = json.decode(res) as Map;
      final connectionsRaw = connectionsData['connections'] as List? ?? [];
      return connectionsRaw
          .map((e) => TrackerInfo.fromJson(e as Map<String, Object?>))
          .toList();
    });
  }

  void closeConnection(String id) {
    _interface.closeConnection(id);
  }

  void closeConnections() {
    _interface.closeConnections();
  }

  void resetConnections() {
    _interface.resetConnections();
  }

  Future<List<ExternalProvider>> getExternalProviders() async {
    final externalProvidersRawString = await _interface.getExternalProviders();
    if (externalProvidersRawString.isEmpty) {
      return [];
    }
    return Isolate.run<List<ExternalProvider>>(() {
      final externalProviders =
          (json.decode(externalProvidersRawString) as List<dynamic>)
              .map((item) => ExternalProvider.fromJson(item))
              .toList();
      return externalProviders;
    });
  }

  Future<ExternalProvider?> getExternalProvider(
    String externalProviderName,
  ) async {
    final externalProvidersRawString = await _interface.getExternalProvider(
      externalProviderName,
    );
    if (externalProvidersRawString.isEmpty) {
      return null;
    }
    return ExternalProvider.fromJson(json.decode(externalProvidersRawString));
  }

  Future<String> updateGeoData(UpdateGeoDataParams params) {
    return _interface.updateGeoData(params);
  }

  Future<String> sideLoadExternalProvider({
    required String providerName,
    required String data,
  }) {
    return _interface.sideLoadExternalProvider(
      providerName: providerName,
      data: data,
    );
  }

  Future<String> updateExternalProvider({required String providerName}) async {
    return _interface.updateExternalProvider(providerName);
  }

  Future<bool> startListener() async {
    return await _interface.startListener();
  }

  Future<bool> stopListener() async {
    return await _interface.stopListener();
  }

  Future<Delay> getDelay(String url, String proxyName) async {
    final data = await _interface.asyncTestDelay(url, proxyName);
    return Delay.fromJson(json.decode(data));
  }

  Future<Map<String, dynamic>> getConfig(String id) async {
    final profilePath = await appPath.getProfilePath(id);
    final res = await _interface.getConfig(profilePath);
    if (res.isSuccess) {
      return res.data;
    } else {
      throw res.message;
    }
  }

  Future<Traffic> getTraffic(bool onlyStatisticsProxy) async {
    final trafficString = await _interface.getTraffic(onlyStatisticsProxy);
    if (trafficString.isEmpty) {
      return Traffic();
    }
    return Traffic.fromJson(json.decode(trafficString));
  }

  Future<IpInfo?> getCountryCode(String ip) async {
    final countryCode = await _interface.getCountryCode(ip);
    if (countryCode.isEmpty) {
      return null;
    }
    return IpInfo(ip: ip, countryCode: countryCode);
  }

  Future<Traffic> getTotalTraffic(bool onlyStatisticsProxy) async {
    final totalTrafficString = await _interface.getTotalTraffic(
      onlyStatisticsProxy,
    );
    if (totalTrafficString.isEmpty) {
      return Traffic();
    }
    return Traffic.fromJson(json.decode(totalTrafficString));
  }

  Future<int> getMemory() async {
    final value = await _interface.getMemory();
    if (value.isEmpty) {
      return 0;
    }
    return int.parse(value);
  }

  void resetTraffic() {
    _interface.resetTraffic();
  }

  void startLog() {
    _interface.startLog();
  }

  void stopLog() {
    _interface.stopLog();
  }

  Future<void> requestGc() async {
    await _interface.forceGc();
  }

  Future<void> destroy() async {
    await _interface.destroy();
  }

  Future<void> crash() async {
    await _interface.crash();
  }

  Future<String> deleteFile(String path) async {
    return await _interface.deleteFile(path);
  }
}

final coreController = CoreController();
