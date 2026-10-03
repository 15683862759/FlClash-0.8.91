import 'dart:convert';

import 'package:fl_clash/plugins/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'package icon requests reuse cached futures and refresh with packages',
    () async {
      final app = App();
      var iconCallCount = 0;
      var packageCallCount = 0;

      Future<Object?> handleMethodCall(MethodCall call) async {
        switch (call.method) {
          case 'getPackageIcon':
            iconCallCount++;
            expect(call.arguments, {'packageName': 'com.example.app'});
            return 'C:\\cache\\com.example.app_1.webp';
          case 'getPackages':
            packageCallCount++;
            return jsonEncode([
              {
                'packageName': 'com.example.app',
                'label': 'Example',
                'system': false,
                'internet': true,
                'lastUpdateTime': 1,
              },
            ]);
          default:
            return null;
        }
      }

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(app.methodChannel, handleMethodCall);
      addTearDown(() {
        messenger.setMockMethodCallHandler(app.methodChannel, null);
      });

      final firstIconFuture = app.getPackageIcon('com.example.app');
      final secondIconFuture = app.getPackageIcon('com.example.app');
      final firstIcon = await firstIconFuture;
      final secondIcon = await secondIconFuture;

      expect(iconCallCount, 1);
      expect(secondIconFuture, same(firstIconFuture));
      expect(firstIcon, isA<FileImage>());
      expect(secondIcon, same(firstIcon));
      expect(
        (firstIcon as FileImage).file.path,
        'C:\\cache\\com.example.app_1.webp',
      );

      await app.getPackages();
      expect(packageCallCount, 1);

      await app.getPackageIcon('com.example.app');
      expect(iconCallCount, 2);
    },
  );
}
