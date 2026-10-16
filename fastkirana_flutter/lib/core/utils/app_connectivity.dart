import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';

/// Device transport plus a verified response from the configured FastKirana API.
class AppConnectivityObserver extends ChangeNotifier {
  final Future<List<ConnectivityResult>> Function() _readConnections;
  final Future<bool> Function()? _reachabilityProbe;
  final Duration _offlineDebounce;
  final Duration _pollInterval;
  final Dio _probeClient;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _offlineTimer;
  Timer? _pollTimer;
  _ConnectionLifecycleObserver? _lifecycle;
  Future<bool>? _manualCheck;
  List<ConnectivityResult> _results = [];
  bool _isOnline = true;
  bool _disposed = false;
  int _epoch = 0;

  bool get isOnline => _isOnline;
  bool get isWifi => _results.contains(ConnectivityResult.wifi);
  bool get isMobileData => _results.contains(ConnectivityResult.mobile);
  List<ConnectivityResult> get results => List.unmodifiable(_results);

  AppConnectivityObserver({
    Future<List<ConnectivityResult>> Function()? connectionReader,
    Stream<List<ConnectivityResult>>? connectionChanges,
    Future<bool> Function()? reachabilityProbe,
    Duration offlineDebounce = const Duration(milliseconds: 700),
    Duration pollInterval = const Duration(seconds: 20),
    bool observeLifecycle = true,
    Dio? probeClient,
  })  : _readConnections = connectionReader ?? Connectivity().checkConnectivity,
        _reachabilityProbe = reachabilityProbe,
        _offlineDebounce = offlineDebounce,
        _pollInterval = pollInterval,
        _probeClient = probeClient ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 3),
              followRedirects: false,
              headers: {'Cache-Control': 'no-cache, no-store'},
            )) {
    _subscription =
        (connectionChanges ?? Connectivity().onConnectivityChanged).listen(
      (results) => unawaited(_check(results: results, debounce: true)),
      onError: (Object _) => unawaited(_check(debounce: true)),
    );
    if (observeLifecycle) {
      _lifecycle = _ConnectionLifecycleObserver((state) {
        if (state == AppLifecycleState.resumed) {
          _startPolling();
          unawaited(checkConnection());
        } else if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) {
          _pollTimer?.cancel();
        }
      });
      WidgetsBinding.instance.addObserver(_lifecycle!);
    }
    _startPolling();
    unawaited(checkConnection());
  }

  void _startPolling() {
    _pollTimer?.cancel();
    if (_pollInterval > Duration.zero) {
      _pollTimer = Timer.periodic(_pollInterval, (_) {
        if (_manualCheck == null) unawaited(_check(debounce: true));
      });
    }
  }

  Future<bool> _probeApi() async {
    final response = await _probeClient.get('/api/healthz', queryParameters: {
      't': DateTime.now().millisecondsSinceEpoch,
    });
    final data = response.data;
    // Captive-portal HTML, redirects and proxy error pages cannot report online.
    return response.statusCode == 200 &&
        data is Map &&
        data['status'] == 'healthy' &&
        data['probe'] == 'liveness' &&
        data['service'] is String &&
        (data['service'] as String).contains('FastKirana');
  }

  void _publish(bool online, int epoch, {required bool debounce}) {
    if (_disposed || epoch != _epoch) return;
    void apply() {
      if (_disposed || epoch != _epoch || _isOnline == online) return;
      _isOnline = online;
      notifyListeners();
    }

    if (!online && _isOnline && debounce) {
      _offlineTimer = Timer(_offlineDebounce, apply);
    } else {
      apply();
    }
  }

  Future<bool> _check(
      {List<ConnectivityResult>? results, bool debounce = false}) async {
    if (_disposed) return false;
    final epoch = ++_epoch;
    _offlineTimer?.cancel();
    var reachable = false;
    try {
      final transports = results ??
          await _readConnections().timeout(const Duration(seconds: 4));
      if (_disposed || epoch != _epoch) return false;
      _results = List.of(transports);
      if (transports.any((result) => result != ConnectivityResult.none)) {
        reachable = await (_reachabilityProbe?.call() ?? _probeApi())
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {
      reachable = false;
    }
    if (_disposed || epoch != _epoch) return false;
    _publish(reachable, epoch, debounce: debounce);
    return reachable;
  }

  Future<bool> checkConnection() {
    if (_disposed) return Future.value(false);
    return _manualCheck ??= _check().whenComplete(() => _manualCheck = null);
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _subscription?.cancel();
    _offlineTimer?.cancel();
    _pollTimer?.cancel();
    if (_lifecycle != null) WidgetsBinding.instance.removeObserver(_lifecycle!);
    _probeClient.close(force: true);
    super.dispose();
  }
}

class _ConnectionLifecycleObserver extends WidgetsBindingObserver {
  final void Function(AppLifecycleState) onStateChanged;
  _ConnectionLifecycleObserver(this.onStateChanged);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      onStateChanged(state);
}

final connectivityProvider =
    ChangeNotifierProvider<AppConnectivityObserver>((ref) {
  // ChangeNotifierProvider owns disposal of its notifier.
  return AppConnectivityObserver();
});
