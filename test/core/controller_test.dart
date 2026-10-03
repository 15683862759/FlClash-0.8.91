import 'dart:convert';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

TrackerInfo _tracker(String id) => TrackerInfo(
  id: id,
  upload: 10,
  download: 20,
  start: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
  metadata: const Metadata(
    network: 'tcp',
    host: 'example.com',
    destinationPort: '443',
  ),
  chains: const ['DIRECT'],
  rule: 'MATCH',
  rulePayload: '',
);

void main() {
  test('connections parser returns trackers from core json', () async {
    final data = json.encode({
      'connections': [_tracker('connection-1').toJson()],
    });

    final connections = await CoreController.parseConnections(data);

    expect(connections, hasLength(1));
    expect(connections.single.id, 'connection-1');
    expect(connections.single.metadata.host, 'example.com');
  });

  test('connections parser accepts missing and empty payloads', () async {
    expect(await CoreController.parseConnections(''), isEmpty);
    expect(await CoreController.parseConnections('{}'), isEmpty);
    expect(
      await CoreController.parseConnections('{"connections": []}'),
      isEmpty,
    );
  });
}
