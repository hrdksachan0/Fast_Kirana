import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AppConnectivityObserver extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  AppConnectivityObserver() {
    _init();
  }

  void _init() {
    _checkConnection();
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) => _updateFromResults(results),
    );
  }

  void _updateFromResults(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((c) => c != ConnectivityResult.none);
    if (wasOnline != _isOnline) {
      notifyListeners();
    }
  }

  Future<void> _checkConnection() async {
    final results = await _connectivity.checkConnectivity();
    _updateFromResults(results);
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
