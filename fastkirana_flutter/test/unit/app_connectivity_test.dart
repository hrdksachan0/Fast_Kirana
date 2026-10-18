import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastminute_flutter/core/utils/app_connectivity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppConnectivityObserver observer({
    Future<List<ConnectivityResult>> Function()? read,
    Stream<List<ConnectivityResult>>? changes,
    Future<bool> Function()? probe,
    Dio? client,
  }) =>
      AppConnectivityObserver(
        connectionReader: read ?? () async => [ConnectivityResult.wifi],
        connectionChanges: changes ?? const Stream.empty(),
        reachabilityProbe: probe,
        probeClient: client,
        offlineDebounce: const Duration(milliseconds: 100),
        pollInterval: Duration.zero,
        observeLifecycle: false,
      );

  test('Wi-Fi without reachable API stays offline, manual retry recovers',
      () async {
    var reachable = false;
    final connection = observer(probe: () async => reachable);
    addTearDown(connection.dispose);
    expect(await connection.checkConnection(), isFalse);
    expect(connection.isWifi, isTrue);
    expect(connection.isOnline, isFalse);
    reachable = true;
    expect(await connection.checkConnection(), isTrue);
    expect(connection.isOnline, isTrue);
  });

  test('No device transport does not call the API', () async {
    var probes = 0;
    final connection = observer(
        read: () async => [ConnectivityResult.none],
        probe: () async {
          probes++;
          return true;
        });
    addTearDown(connection.dispose);
    expect(await connection.checkConnection(), isFalse);
    expect(probes, 0);
  });

  for (final data in [
    '<html>Sign in to this Wi-Fi network</html>',
    {'status': 'healthy'},
    {'status': 'unhealthy', 'probe': 'liveness', 'service': 'FastKirana'},
    {
      'status': 'healthy',
      'probe': 'liveness',
      'service': 'FastKirana FastAPI Microservice'
    },
  ]) {
    test('Health endpoint validates its response: $data', () async {
      final client = Dio();
      client.interceptors
          .add(InterceptorsWrapper(onRequest: (options, handler) {
        expect(options.path, '/api/healthz');
        handler.resolve(
            Response(requestOptions: options, data: data, statusCode: 200));
      }));
      final connection = observer(client: client);
      addTearDown(connection.dispose);
      expect(
          await connection.checkConnection(),
          data is Map &&
              data['service'] != null &&
              data['status'] == 'healthy');
    });
  }

  testWidgets('Brief network drop does not flash offline or trigger recovery',
      (tester) async {
    final events = StreamController<List<ConnectivityResult>>();
    final connection =
        observer(changes: events.stream, probe: () async => true);
    addTearDown(events.close);
    addTearDown(connection.dispose);
    await connection.checkConnection();
    var changes = 0;
    connection.addListener(() => changes++);
    events.add([ConnectivityResult.none]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    events.add([ConnectivityResult.wifi]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(connection.isOnline, isTrue);
    expect(changes, 0);
  });

  testWidgets('A stale successful probe cannot override a newer disconnect',
      (tester) async {
    final events = StreamController<List<ConnectivityResult>>();
    final delayedProbe = Completer<bool>();
    final connection =
        observer(changes: events.stream, probe: () => delayedProbe.future);
    addTearDown(events.close);
    addTearDown(connection.dispose);
    await tester.pump();
    events.add([ConnectivityResult.none]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    expect(connection.isOnline, isFalse);
    delayedProbe.complete(true);
    await tester.pump();
    expect(connection.isOnline, isFalse);
  });

  testWidgets('API check timeout resolves offline and does not trap retry',
      (tester) async {
    final probe = Completer<bool>();
    final connection = observer(probe: () => probe.future);
    addTearDown(connection.dispose);
    final pending = connection.checkConnection();
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(await pending, isFalse);
    expect(connection.isOnline, isFalse);
    probe.complete(true);
    expect(await connection.checkConnection(), isTrue);
  });

  test('Parallel manual retries share one reachability probe', () async {
    var calls = 0;
    final probe = Completer<bool>();
    final connection = observer(probe: () {
      calls++;
      return probe.future;
    });
    addTearDown(connection.dispose);
    final a = connection.checkConnection();
    final b = connection.checkConnection();
    probe.complete(true);
    expect(await a, isTrue);
    expect(await b, isTrue);
    expect(calls, 1);
  });
}
