import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  bool _isMetered = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _periodicTimer;
  int _checkCounter = 0;
  bool _disposed = false;

  bool get isOnline => _isOnline;

  /// True on mobile data without Wi-Fi/Ethernet.
  bool get isMetered => _isMetered;

  ConnectivityProvider() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  // Background: no UI depends on the status, so skip probes entirely.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      checkReachability();
      _schedulePeriodicCheck();
    } else if (state == AppLifecycleState.paused) {
      _periodicTimer?.cancel();
      _periodicTimer = null;
    }
  }

  /// Probes for "Wi-Fi without internet": every 15 s while offline (to
  /// recover quickly), every 60 s while online.
  void _schedulePeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer(
      Duration(seconds: _isOnline ? 60 : 15),
      () async {
        if (_disposed) return;
        await checkReachability();
        if (!_disposed && _periodicTimer != null) _schedulePeriodicCheck();
      },
    );
  }

  Future<void> _init() async {
    final result = await _connectivity.checkConnectivity();
    if (_disposed) return;
    await _updateStatus(result);
    if (_disposed) return;

    _sub = _connectivity.onConnectivityChanged.listen((results) {
      if (_disposed) return;
      _updateStatus(results);
    });

    _schedulePeriodicCheck();
  }

  /// Verifica manualmente la conectividad y reachability real a internet.
  Future<bool> checkReachability() async {
    final results = await _connectivity.checkConnectivity();
    return _updateStatus(results);
  }

  Future<bool> _updateStatus(List<ConnectivityResult> results) async {
    final currentToken = ++_checkCounter;
    final hasInterface =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    _isMetered = results.contains(ConnectivityResult.mobile) &&
        !results.contains(ConnectivityResult.wifi) &&
        !results.contains(ConnectivityResult.ethernet);

    if (!hasInterface) {
      _setOnline(false);
      return false;
    }

    final reachable = await _hasRealInternet();
    if (currentToken == _checkCounter) {
      _setOnline(reachable);
    }
    return reachable;
  }

  void _setOnline(bool online) {
    if (_disposed) return;
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
      if (_periodicTimer != null) _schedulePeriodicCheck();
    }
  }

  /// Comprueba si hay acceso real a Internet y no solo una interfaz de red conectada.
  Future<bool> _hasRealInternet() async {
    if (kIsWeb) return true;

    // 1. Sondeo rápido en paralelo a servidores DNS públicos conocidos vía TCP (puerto 53).
    // Usa IPs directas para evitar resolución DNS local y cachés obsoletas.
    try {
      final socketResults = await Future.wait([
        _checkSocket('8.8.8.8', 53),
        _checkSocket('1.1.1.1', 53),
      ]);
      if (socketResults.any((ok) => ok)) return true;
    } catch (_) {}

    // 2. Fallback: Sondeo HTTPS en paralelo si el puerto 53 está restringido por firewall.
    // Google generate_204 es el endpoint estándar de validación en Android.
    try {
      final httpResults = await Future.wait([
        _checkHttp('https://www.google.com/generate_204'),
        _checkHttp('https://api.deezer.com'),
      ]);
      if (httpResults.any((ok) => ok)) return true;
    } catch (_) {}

    return false;
  }

  Future<bool> _checkSocket(
    String host,
    int port, {
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkHttp(
    String url, {
    Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = timeout;
      final uri = Uri.parse(url);
      final request = await client.headUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }
}
