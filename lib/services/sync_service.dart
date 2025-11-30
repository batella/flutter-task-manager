import 'dart:async';
import '../models/task.dart';
import '../models/sync_queue_item.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'connectivity_service.dart';

/// Serviço responsável por sincronizar tarefas entre banco local e API
/// Implementa lógica offline-first com resolução de conflitos Last-Write-Wins
class SyncService {
  final DatabaseService _dbService;
  final ApiService _apiService;
  final ConnectivityService _connectivityService;

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isSyncing = false;
  
  // Stream para notificar quando a sincronização é concluída
  final _syncCompleteController = StreamController<void>.broadcast();
  Stream<void> get syncCompleteStream => _syncCompleteController.stream;

  SyncService({
    required DatabaseService dbService,
    required ApiService apiService,
    required ConnectivityService connectivityService,
  })  : _dbService = dbService,
        _apiService = apiService,
        _connectivityService = connectivityService {
    _init();
  }

  /// Inicializa escuta de mudanças de conectividade
  void _init() {
    _connectivitySubscription = _connectivityService.connectivityStream.listen((isOnline) {
      if (isOnline && !_isSyncing) {
        print('🔄 Conexão restaurada, iniciando sincronização...');
        syncPendingOperations();
      }
    });
  }

  /// Sincroniza todas as operações pendentes na fila
  Future<void> syncPendingOperations() async {
    if (_isSyncing) {
      print('⚠️ Sincronização já em andamento, ignorando...');
      return;
    }

    if (!_connectivityService.isOnline) {
      print('📴 Offline - sincronização adiada');
      return;
    }

    _isSyncing = true;
    print('🔄 Iniciando sincronização...');

    try {
      final queue = await _dbService.getSyncQueue();
      
      if (queue.isEmpty) {
        print('✅ Nenhuma operação pendente para sincronizar');
        _isSyncing = false;
        return;
      }

      print('📋 ${queue.length} operação(ões) pendente(s) na fila');

      for (final item in queue) {
        try {
          await _processSyncItem(item);
          await _dbService.removeFromSyncQueue(item.id);
          print('✅ Operação sincronizada: ${item.operation} - ${item.taskId}');
        } catch (e) {
          print('❌ Erro ao sincronizar ${item.id}: $e');
          // Continua para próximo item mesmo com erro
        }
      }

      print('✅ Sincronização concluída');
      _syncCompleteController.add(null); // Notifica que sincronização foi concluída
    } catch (e) {
      print('❌ Erro durante sincronização: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Processa um item individual da fila de sincronização
  Future<void> _processSyncItem(SyncQueueItem item) async {
    switch (item.operation) {
      case 'create':
        final task = Task.fromMap(item.data);
        await _apiService.createTask(task);
        // Atualiza status local para 'synced' SEM adicionar à fila novamente
        await _dbService.updateSyncStatus(task.id, 'synced');
        print('✅ Tarefa sincronizada: ${task.title}');
        break;

      case 'update':
        final task = Task.fromMap(item.data);
        await _apiService.updateTask(task);
        await _dbService.updateSyncStatus(task.id, 'synced');
        print('✅ Tarefa sincronizada: ${task.title}');
        break;

      case 'delete':
        if (item.taskId != null) {
          await _apiService.deleteTask(item.taskId!);
        }
        break;

      default:
        print('⚠️ Operação desconhecida: ${item.operation}');
    }
  }

  /// Adiciona uma operação à fila de sincronização
  Future<void> queueOperation({
    required String operation,
    required Task task,
  }) async {
    final item = SyncQueueItem.create(
      operation: operation,
      taskId: task.id,
      data: task.toMap(),
    );

    await _dbService.addToSyncQueue(item);
    print('📤 Operação adicionada à fila: $operation - ${task.title}');

    // Tenta sincronizar imediatamente se estiver online
    if (_connectivityService.isOnline) {
      syncPendingOperations();
    }
  }

  /// Implementa resolução de conflitos Last-Write-Wins (LWW)
  /// Compara timestamps e mantém a versão mais recente
  Future<Task> resolveConflict(Task localTask, Task serverTask) async {
    print('⚔️ Conflito detectado para tarefa: ${localTask.title}');
    
    final Task winner;
    if (localTask.updatedAt.isAfter(serverTask.updatedAt)) {
      print('🏆 Versão local mais recente (${localTask.updatedAt}) vence sobre servidor (${serverTask.updatedAt})');
      winner = localTask;
      // Envia versão local para servidor
      await _apiService.updateTask(localTask);
    } else {
      print('🏆 Versão do servidor mais recente (${serverTask.updatedAt}) vence sobre local (${localTask.updatedAt})');
      winner = serverTask;
      // Atualiza banco local com versão do servidor
      await _dbService.update(serverTask.copyWith(syncStatus: 'synced'));
    }

    return winner;
  }

  /// Sincroniza tarefas do servidor (pull)
  /// Usado para buscar atualizações do servidor
  Future<void> pullFromServer() async {
    if (!_connectivityService.isOnline) {
      print('📴 Offline - não é possível buscar do servidor');
      return;
    }

    try {
      print('⬇️ Buscando tarefas do servidor...');
      final serverTasks = await _apiService.fetchTasks();
      final localTasks = await _dbService.readAll();

      // Mapa de tarefas locais por ID para acesso rápido
      final localTasksMap = {for (var task in localTasks) task.id: task};

      for (final serverTask in serverTasks) {
        final localTask = localTasksMap[serverTask.id];

        if (localTask == null) {
          // Tarefa existe apenas no servidor - adicionar localmente
          await _dbService.create(serverTask.copyWith(syncStatus: 'synced'));
          print('➕ Nova tarefa do servidor: ${serverTask.title}');
        } else if (localTask.syncStatus == 'pending') {
          // Conflito - resolver usando LWW
          await resolveConflict(localTask, serverTask);
        } else {
          // Atualizar com versão do servidor se for mais recente
          if (serverTask.updatedAt.isAfter(localTask.updatedAt)) {
            await _dbService.update(serverTask.copyWith(syncStatus: 'synced'));
            print('🔄 Tarefa atualizada do servidor: ${serverTask.title}');
          }
        }
      }

      print('✅ Pull do servidor concluído');
    } catch (e) {
      print('❌ Erro ao buscar do servidor: $e');
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncCompleteController.close();
  }
}
