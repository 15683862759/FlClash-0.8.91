import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

class Debouncer {
  final Map<FunctionTag, Timer?> _operations = {};

  void call(
    FunctionTag tag,
    Function func, {
    List<dynamic>? args,
    Duration? duration,
  }) {
    final timer = _operations[tag];
    if (timer != null) {
      timer.cancel();
    }
    _operations[tag] = Timer(duration ?? const Duration(milliseconds: 600), () {
      _operations[tag]?.cancel();
      _operations.remove(tag);
      Function.apply(func, args);
    });
  }

  void cancel(dynamic tag) {
    _operations[tag]?.cancel();
    _operations[tag] = null;
  }
}

class ProxyChangeDebouncer {
  final FutureOr<void> Function(String groupName, String proxyName) _onChange;
  final void Function()? _onBatchComplete;
  final Duration duration;
  final Map<String, String> _pendingChanges = {};
  Timer? _timer;
  Future<void>? _activeFlush;

  ProxyChangeDebouncer({
    required FutureOr<void> Function(String groupName, String proxyName)
    onChange,
    void Function()? onBatchComplete,
    this.duration = const Duration(milliseconds: 100),
  }) : _onChange = onChange,
       _onBatchComplete = onBatchComplete;

  void call(String groupName, String proxyName) {
    _pendingChanges[groupName] = proxyName;
    if (_activeFlush != null || _timer != null) {
      _scheduleFlush();
      return;
    }
    unawaited(_flush());
  }

  void _scheduleFlush() {
    _timer?.cancel();
    _timer = Timer(duration, () {
      _timer = null;
      unawaited(_flush());
    });
  }

  Future<void> _flush() async {
    final activeFlush = _activeFlush;
    if (activeFlush != null) {
      await activeFlush;
      if (_pendingChanges.isNotEmpty) {
        await _flush();
      }
      return;
    }
    if (_pendingChanges.isEmpty) {
      return;
    }

    final flush = _runFlush();
    _activeFlush = flush;
    try {
      await flush;
    } finally {
      if (identical(_activeFlush, flush)) {
        _activeFlush = null;
      }
    }
  }

  Future<void> _runFlush() async {
    final changes = Map.of(_pendingChanges);
    _pendingChanges.clear();
    for (final entry in changes.entries) {
      await _onChange(entry.key, entry.value);
    }
    _onBatchComplete?.call();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pendingChanges.clear();
  }
}

class DelayResultBatcher {
  final void Function(List<Delay> delays) onFlush;
  final Duration interval;
  final List<Delay> _delays = [];
  Timer? _timer;

  DelayResultBatcher({
    required this.onFlush,
    this.interval = const Duration(milliseconds: 16),
  });

  void add(Delay delay) {
    _delays.add(delay);
    _timer ??= Timer(interval, flush);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_delays.isEmpty) {
      return;
    }
    final delays = List.of(_delays);
    _delays.clear();
    onFlush(delays);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _delays.clear();
  }
}

class CoreEventBatcher<T> {
  final void Function(List<T> values) onFlush;
  final Duration interval;
  final List<T> _values = [];
  Timer? _timer;

  CoreEventBatcher({
    required this.onFlush,
    this.interval = const Duration(milliseconds: 16),
  });

  void add(T value) {
    _values.add(value);
    _timer ??= Timer(interval, flush);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_values.isEmpty) {
      return;
    }
    final values = List.of(_values);
    _values.clear();
    onFlush(values);
  }

  void dispose() {
    flush();
  }
}

class GroupRefreshGate {
  List<Group>? _lastGroups;

  GroupRefreshGate([List<Group>? initialGroups]) {
    if (initialGroups != null) {
      _lastGroups = List.of(initialGroups);
    }
  }

  bool shouldCommit(List<Group> groups) {
    final lastGroups = _lastGroups;
    if (lastGroups != null && groupListEquality.equals(lastGroups, groups)) {
      return false;
    }
    _lastGroups = List.of(groups);
    return true;
  }
}

class GroupRefreshScheduler {
  GroupRefreshScheduler(
    this._refresh, {
    this.interval = const Duration(milliseconds: 250),
  });

  final FutureOr<void> Function() _refresh;
  final Duration interval;
  bool _refreshing = false;
  bool _pending = false;
  bool _disposed = false;
  Timer? _cooldown;

  bool get isRefreshing => _refreshing;

  void schedule() {
    if (_disposed) return;
    _pending = true;
    if (_refreshing || _cooldown != null) return;
    unawaited(_run());
  }

  Future<void> _run() async {
    if (_disposed || _refreshing) return;
    _cooldown?.cancel();
    _cooldown = null;
    _refreshing = true;
    _pending = false;
    try {
      await _refresh();
    } finally {
      _refreshing = false;
      if (_pending && !_disposed) {
        _cooldown = Timer(interval, () {
          _cooldown = null;
          if (_pending) unawaited(_run());
        });
      }
    }
  }

  void dispose() {
    _disposed = true;
    _cooldown?.cancel();
    _cooldown = null;
  }
}

class Throttler {
  final Map<FunctionTag, Timer?> _operations = {};

  bool call(
    FunctionTag tag,
    Function func, {
    List<dynamic>? args,
    Duration duration = const Duration(milliseconds: 600),
    bool fire = false,
  }) {
    final timer = _operations[tag];
    if (timer != null) {
      return true;
    }
    if (fire) {
      Function.apply(func, args);
      _operations[tag] = Timer(duration, () {
        _operations[tag]?.cancel();
        _operations.remove(tag);
      });
    } else {
      _operations[tag] = Timer(duration, () {
        Function.apply(func, args);
        _operations[tag]?.cancel();
        _operations.remove(tag);
      });
    }
    return false;
  }

  void cancel(dynamic tag) {
    _operations[tag]?.cancel();
    _operations[tag] = null;
  }
}

Future<T> retry<T>({
  required Future<T> Function() task,
  int maxAttempts = 3,
  required bool Function(T res) retryIf,
  Duration delay = midDuration,
}) async {
  int attempts = 0;
  while (attempts < maxAttempts) {
    final res = await task();
    if (!retryIf(res) || attempts >= maxAttempts) {
      return res;
    }
    attempts++;
    await Future<void>.delayed(delay);
  }
  throw 'retry error';
}

final debouncer = Debouncer();

final throttler = Throttler();
