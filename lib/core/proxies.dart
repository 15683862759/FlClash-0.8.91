import 'package:collection/collection.dart';
import 'package:fl_clash/common/compute.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

class ProxySnapshotState {
  final String now;
  final bool hidden;

  const ProxySnapshotState({required this.now, required this.hidden});

  factory ProxySnapshotState.fromJson(Map<Object?, Object?> json) {
    return ProxySnapshotState(
      now: json['now'] as String? ?? '',
      hidden: json['hidden'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProxySnapshotState && other.now == now && other.hidden == hidden;

  @override
  int get hashCode => Object.hash(now, hidden);
}

class ProxiesSnapshotCache {
  String? _signature;
  List<Group> _baseGroups = const [];
  Map<String, ProxySnapshotState> _states = const {};
  List<Group> _groups = const [];
  ProxiesSortType? _sortType;
  DelayMap? _delayMap;
  Map<String, String>? _selectedMap;
  String? _defaultTestUrl;

  List<Group> update({
    required String signature,
    List<Group>? baseGroups,
    required Map<String, ProxySnapshotState> states,
    required ProxiesSortType sortType,
    required DelayMap delayMap,
    required Map<String, String> selectedMap,
    required String defaultTestUrl,
  }) {
    if (_signature != signature) {
      if (baseGroups == null) {
        throw ArgumentError.value(
          signature,
          'signature',
          'changed signatures must contain full proxies',
        );
      }
      _signature = signature;
      _baseGroups = baseGroups;
      _groups = const [];
    }

    final nextStates = states;
    final isSameInput =
        sortType == _sortType &&
        identical(delayMap, _delayMap) &&
        identical(selectedMap, _selectedMap) &&
        defaultTestUrl == _defaultTestUrl;
    if (isSameInput &&
        const MapEquality<String, ProxySnapshotState>().equals(
          nextStates,
          _states,
        ) &&
        _groups.isNotEmpty) {
      return _groups;
    }

    _states = nextStates;
    _sortType = sortType;
    _delayMap = delayMap;
    _selectedMap = selectedMap;
    _defaultTestUrl = defaultTestUrl;
    _groups = computeSort(
      groups: patch(_baseGroups, nextStates),
      sortType: sortType,
      delayMap: delayMap,
      selectedMap: selectedMap,
      defaultTestUrl: defaultTestUrl,
    );
    return _groups;
  }

  void clear() {
    _signature = null;
    _baseGroups = const [];
    _states = const {};
    _groups = const [];
    _sortType = null;
    _delayMap = null;
    _selectedMap = null;
    _defaultTestUrl = null;
  }

  static Map<String, ProxySnapshotState> parseStates(
    Map<Object?, Object?> states,
  ) {
    return states.map(
      (key, value) => MapEntry(
        key as String,
        ProxySnapshotState.fromJson(value as Map<Object?, Object?>),
      ),
    );
  }

  static List<Group> parse(Map<Object?, Object?> proxies) {
    final proxyMaps = <String, Map<String, Object?>>{
      for (final entry in proxies.entries)
        if (entry.value is Map)
          entry.key as String: Map<String, Object?>.from(entry.value as Map),
    };
    final global = proxyMaps['GLOBAL'];
    if (global == null) return const [];

    final globalAll = global['all'] as List<Object?>? ?? const [];
    final groupNames = [
      UsedProxy.GLOBAL.name,
      ...globalAll.where(
        (name) =>
            GroupTypeExtension.valueList.contains(proxyMaps[name]?['type']),
      ),
    ];

    return groupNames.map((groupName) {
      final group = Map<String, Object?>.from(proxyMaps[groupName]!);
      final all = group['all'] as List<Object?>? ?? const [];
      group['all'] = all.map((name) => proxyMaps[name]).nonNulls.toList();
      return Group.fromJson(group);
    }).toList();
  }

  static List<Group> patch(
    List<Group> groups,
    Map<String, ProxySnapshotState> states,
  ) {
    return [
      for (final group in groups)
        // Incremental snapshots omit unchanged groups, so missing state must
        // preserve the parsed full snapshot instead of clearing nullable fields.
        group.copyWith(
          now: states[group.name]?.now ?? group.now,
          hidden: states[group.name]?.hidden ?? group.hidden,
        ),
    ];
  }
}
