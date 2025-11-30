import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Representa um item na fila de sincronização para operações offline
class SyncQueueItem {
  final String id;
  final String operation; // 'create', 'update', 'delete'
  final String? taskId; // ID da tarefa relacionada (null para create antes de sync)
  final DateTime timestamp;
  final Map<String, dynamic> data; // Dados da operação (JSON da tarefa)

  SyncQueueItem({
    required this.id,
    required this.operation,
    this.taskId,
    required this.timestamp,
    required this.data,
  });

  /// Cria um novo item de sincronização com ID gerado automaticamente
  factory SyncQueueItem.create({
    required String operation,
    String? taskId,
    required Map<String, dynamic> data,
  }) {
    return SyncQueueItem(
      id: const Uuid().v4(),
      operation: operation,
      taskId: taskId,
      timestamp: DateTime.now(),
      data: data,
    );
  }

  /// Converte o item para Map para salvar no banco de dados
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operation': operation,
      'taskId': taskId,
      'timestamp': timestamp.toIso8601String(),
      'data': jsonEncode(data), // Serializado como string JSON
    };
  }

  /// Cria um item a partir de um Map do banco de dados
  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    // Parse data: pode ser String JSON ou Map direto
    Map<String, dynamic> parsedData;
    if (map['data'] is String) {
      parsedData = jsonDecode(map['data'] as String) as Map<String, dynamic>;
    } else {
      parsedData = map['data'] as Map<String, dynamic>;
    }
    
    return SyncQueueItem(
      id: map['id'] as String,
      operation: map['operation'] as String,
      taskId: map['taskId'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      data: parsedData,
    );
  }

  @override
  String toString() {
    return 'SyncQueueItem(id: $id, operation: $operation, taskId: $taskId, timestamp: $timestamp)';
  }
}
