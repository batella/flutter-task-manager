import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Serviço para monitorar o status de conectividade de rede
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();

  bool _isOnline = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityService() {
    _init();
  }

  /// Stream que emite true quando online, false quando offline
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Status atual de conectividade
  bool get isOnline => _isOnline;

  /// Inicializa o monitoramento de conectividade
  Future<void> _init() async {
    // Verifica status inicial
    final result = await _connectivity.checkConnectivity();
    _updateConnectivityStatus(result);

    // Escuta mudanças de conectividade
    _subscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateConnectivityStatus(results);
    });
  }

  /// Atualiza o status de conectividade baseado no resultado
  void _updateConnectivityStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    
    // Considera online se houver qualquer conexão (wifi, mobile, ethernet, etc.)
    _isOnline = results.any((result) => 
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.ethernet
    );

    // Notifica apenas se o status mudou
    if (wasOnline != _isOnline) {
      print(_isOnline ? '🌐 Conectado à internet' : '📴 Offline');
      _connectivityController.add(_isOnline);
    }
  }

  /// Libera recursos
  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
  }
}
