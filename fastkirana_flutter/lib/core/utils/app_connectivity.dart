import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AppConnectivityObserver extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  AppConnectivityObserver() {
    _init();
  }

  void _init() {
    _checkConnection();
    _subscription = _connectivity.onConnectivityChanged.listen(
      (result) => _checkConnection(),
    );
  }

  Future<void> _checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    final wasOnline = _isOnline;
    _isOnline = result.any((c) => c != ConnectivityResult.none);
    if (wasOnline != _isOnline) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final connectivityProvider =
    ChangeNotifierProvider<AppConnectivityObserver>((ref) {
  final observer = AppConnectivityObserver();
  ref.onDispose(observer.dispose);
  return observer;
});
