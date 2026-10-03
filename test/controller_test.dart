import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
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

void main() {
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
}
