import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingHotKeyActions extends HotKeyActions {
  int updateCount = 0;

  @override
  List<HotKeyAction> build() => const [
    HotKeyAction(action: HotAction.start, key: 1),
  ];

  @override
  void onUpdate(List<HotKeyAction> value) {
    updateCount++;
    super.onUpdate(value);
  }
}

class _RecordingGroupRefreshController extends AppController {
  _RecordingGroupRefreshController(super.context, super.ref);

  final groupRefreshDurations = <Duration?>[];

  @override
  Future<void> changeProxy({
    required String groupName,
    required String proxyName,
  }) async {}

  @override
  void updateGroupsDebounce([Duration? duration]) {
    groupRefreshDurations.add(duration);
  }
}

class _CountingDelayDataSource extends DelayDataSource {
  int setDelayCalls = 0;

  @override
  DelayMap build() => {};

  @override
  bool setDelays(Iterable<Delay> delays) {
    setDelayCalls++;
    return super.setDelays(delays);
  }
}

class _CountingDebouncedGroupRefreshController extends AppController {
  _CountingDebouncedGroupRefreshController(super.context, super.ref);

  var activeRefresh = Completer<void>();
  int updateCalls = 0;

  @override
  Future<void> updateGroups() {
    updateCalls++;
    return activeRefresh.future;
  }
}

void main() {
  setUp(() async {
    globalState.appState = AppState(
      brightness: Brightness.light,
      requests: FixedList(100),
      version: 0,
      viewSize: const Size(800, 600),
      logs: FixedList(100),
      traffics: FixedList(30),
      totalTraffic: const Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    await AppLocalizations.load(const Locale('en'));
  });

  testWidgets('updating a hotkey action commits one state change', (
    tester,
  ) async {
    globalState.config = Config(themeProps: defaultThemeProps);
    late AppController controller;
    final container = ProviderContainer(
      overrides: [
        hotKeyActionsProvider.overrideWith(_CountingHotKeyActions.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            controller = AppController(context, ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    controller.updateOrAddHotKeyAction(
      const HotKeyAction(action: HotAction.start, key: 2),
    );

    final notifier =
        container.read(hotKeyActionsProvider.notifier)
            as _CountingHotKeyActions;
    expect(notifier.updateCount, 1);
    expect(container.read(hotKeyActionsProvider), const [
      HotKeyAction(action: HotAction.start, key: 2),
    ]);
  });

  testWidgets('proxy change schedules a fast group refresh', (tester) async {
    globalState.config = Config(themeProps: defaultThemeProps);
    late _RecordingGroupRefreshController controller;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            controller = _RecordingGroupRefreshController(context, ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    controller.changeProxyDebounce('group', 'node');
    await tester.pump();
    expect(controller.groupRefreshDurations, [
      const Duration(milliseconds: 16),
    ]);
  });

  testWidgets('setting unchanged delays reports no change', (tester) async {
    globalState.appState = AppState(
      brightness: Brightness.light,
      requests: FixedList(100),
      version: 0,
      viewSize: Size.zero,
      logs: FixedList(100),
      traffics: FixedList(30),
      totalTraffic: const Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    final container = ProviderContainer(
      overrides: [
        delayDataSourceProvider.overrideWith(_CountingDelayDataSource.new),
      ],
    );
    addTearDown(container.dispose);

    late AppController controller;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            controller = AppController(context, ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const delay = Delay(name: 'node', url: 'https://test', value: 120);
    expect(controller.setDelays([delay]), isTrue);
    expect(controller.setDelays([delay]), isFalse);
  });

  testWidgets('debounced group refreshes coalesce during a refresh storm', (
    tester,
  ) async {
    globalState.config = Config(themeProps: defaultThemeProps);
    late _CountingDebouncedGroupRefreshController controller;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            controller = _CountingDebouncedGroupRefreshController(context, ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    for (var index = 0; index < 5; index++) {
      controller.updateGroupsDebounce();
    }
    expect(controller.updateCalls, 1);

    controller.updateGroupsDebounce();
    await tester.pump();
    expect(controller.updateCalls, 1);

    controller.activeRefresh.complete();
    await tester.pump();
    expect(controller.updateCalls, 1);

    await tester.pump(const Duration(milliseconds: 249));
    expect(controller.updateCalls, 1);

    controller.activeRefresh = Completer<void>();
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.updateCalls, 2);
    expect(controller.activeRefresh.isCompleted, isFalse);
  });

  testWidgets('automatic update results do not open a prompt dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    globalState.config = Config(themeProps: defaultThemeProps);
    late AppController controller;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: globalState.navigatorKey,
          home: Consumer(
            builder: (context, ref, _) {
              controller = AppController(context, ref);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    unawaited(
      controller.checkUpdateResultHandle(
        data: {'tag_name': 'v999.0.0', 'body': '- performance improvements'},
      ),
    );
    await tester.pump();

    expect(find.byType(CommonDialog), findsNothing);
  });

  testWidgets('manual update checks keep showing the result dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    globalState.config = Config(themeProps: defaultThemeProps);
    late AppController controller;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: globalState.navigatorKey,
          home: Consumer(
            builder: (context, ref, _) {
              controller = AppController(context, ref);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    unawaited(
      controller.checkUpdateResultHandle(
        data: {'tag_name': 'v999.0.0', 'body': '- performance improvements'},
        isUser: true,
      ),
    );
    await tester.pump();

    expect(find.byType(CommonDialog), findsOneWidget);
    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();
  });
}
