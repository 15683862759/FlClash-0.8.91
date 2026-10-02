import 'package:fl_clash/common/measure.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/card.dart';
import 'package:fl_clash/widgets/card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAppController extends AppController {
  _RecordingAppController(super.context, super.ref);

  final selections = <(String, String)>[];
  final proxyChanges = <(String, String)>[];

  @override
  void updateCurrentSelectedMap(String groupName, String proxyName) {
    selections.add((groupName, proxyName));
  }

  @override
  void changeProxyDebounce(String groupName, String proxyName) {
    proxyChanges.add((groupName, proxyName));
  }
}

void main() {
  testWidgets('tapping the selected selector node is a no-op', (tester) async {
    globalState.config = Config(themeProps: defaultThemeProps);
    late _RecordingAppController controller;
    final container = ProviderContainer(
      overrides: [
        appSettingProvider.overrideWithValue(defaultAppSettingProps),
        groupsProvider.overrideWithValue(const [
          Group(
            type: GroupType.Selector,
            name: 'group',
            all: [Proxy(name: 'node', type: 'Shadowsocks')],
          ),
        ]),
        selectedMapProvider.overrideWithValue(const {'group': 'node'}),
        delayDataSourceProvider.overrideWithValue(const {}),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            controller = _RecordingAppController(context, ref);
            globalState.appController = controller;
            globalState.measure = Measure.of(context, 1);
            return MaterialApp(
              home: Center(
                child: ProxyCard(
                  groupName: 'group',
                  testUrl: null,
                  proxy: const Proxy(name: 'node', type: 'Shadowsocks'),
                  groupType: GroupType.Selector,
                  type: ProxyCardType.shrink,
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byType(CommonCard));
    await tester.pump();

    expect(controller.selections, isEmpty);
    expect(controller.proxyChanges, isEmpty);
  });
}
