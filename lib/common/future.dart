import 'dart:async';
import 'dart:ui';

import 'package:fl_clash/common/common.dart';

Future<void> forEachBounded<T>(
  Iterable<T> items,
  FutureOr<void> Function(T item) action, {
  required int concurrencyLimit,
}) async {
  if (concurrencyLimit <= 0) {
    throw ArgumentError.value(
      concurrencyLimit,
      'concurrencyLimit',
      'must be greater than zero',
    );
  }

  final iterator = items.iterator;
  var stopped = false;

  Future<void> runWorker() async {
    while (!stopped) {
      if (!iterator.moveNext()) return;
      final item = iterator.current;
      try {
        await action(item);
      } catch (_) {
        stopped = true;
        rethrow;
      }
    }
  }

  await Future.wait(List.generate(concurrencyLimit, (_) => runWorker()));
}

extension FutureExt<T> on Future<T> {
  Future<T> withTimeout({
    Duration? timeout,
    String? tag,
    VoidCallback? onLast,
    FutureOr<T> Function()? onTimeout,
  }) {
    final realTimeout = timeout ?? const Duration(minutes: 3);
    Timer(realTimeout + commonDuration, () {
      if (onLast != null) {
        onLast();
      }
    });
    return this.timeout(
      realTimeout,
      onTimeout: () async {
        if (onTimeout != null) {
          return onTimeout();
        } else {
          throw TimeoutException('${tag ?? runtimeType} timeout');
        }
      },
    );
  }
}

extension CompleterExt<T> on Completer<T> {
  void safeCompleter(T value) {
    if (isCompleted) {
      return;
    }
    complete(value);
  }
}
