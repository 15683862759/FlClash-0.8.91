import 'dart:collection';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingPinnedList extends ListBase<String> {
  _CountingPinnedList(this._values);

  final List<String> _values;
  int containsCount = 0;

  @override
  String operator [](int index) => _values[index];

  @override
  void operator []=(int index, String value) => _values[index] = value;

  @override
  int get length => _values.length;

  @override
  set length(int value) => _values.length = value;

  @override
  bool contains(Object? element) {
    containsCount++;
    return super.contains(element);
  }
}

Package _package(String name, {required int updateTime}) => Package(
  packageName: name,
  label: name,
  system: false,
  internet: true,
  lastUpdateTime: updateTime,
);

void main() {
  test('application sorting prepares pinned lookups once', () {
    final pinnedList = _CountingPinnedList(['app.selected']);
    final packages = [
      for (var index = 0; index < 32; index++)
        _package(
          index.isEven
              ? 'app-${index.toString().padLeft(2, '0')}'
              : 'app-$index',
          updateTime: index,
        ),
    ];
    packages.add(_package('app.selected', updateTime: 0));

    final viewPackages = packages.getViewList(
      pinedList: pinnedList,
      sortType: AccessSortType.name,
      isFilterSystemApp: false,
      isFilterNonInternetApp: false,
    );

    expect(viewPackages.first.packageName, 'app.selected');
    expect(
      viewPackages.skip(1).map((package) => package.label),
      isNot(contains('app.selected')),
    );
    expect(pinnedList.containsCount, lessThan(8));
  });

  test('application filtering keeps only user internet packages', () {
    final packages = [
      Package(
        packageName: 'user.internet',
        label: 'User internet',
        system: false,
        internet: true,
        lastUpdateTime: 3,
      ),
      Package(
        packageName: 'system.app',
        label: 'System app',
        system: true,
        internet: true,
        lastUpdateTime: 2,
      ),
      Package(
        packageName: 'offline.app',
        label: 'Offline app',
        system: false,
        internet: false,
        lastUpdateTime: 1,
      ),
    ];

    final viewPackages = packages.getViewList(
      pinedList: const [],
      sortType: AccessSortType.none,
      isFilterSystemApp: true,
      isFilterNonInternetApp: true,
    );

    expect(viewPackages.map((package) => package.packageName), [
      'user.internet',
    ]);
  });
}
