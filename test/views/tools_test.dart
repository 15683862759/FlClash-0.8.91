import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    globalState.config = Config(themeProps: defaultThemeProps);
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

  testWidgets('tools page does not expose the disclaimer dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          builder: (context, child) {
            globalState.theme = CommonTheme.of(context, 1);
            return child!;
          },
          home: ToolsView(),
        ),
      ),
    );

    expect(find.text('Disclaimer'), findsNothing);
  });
}
