import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';

/// Serviço para comunicação com a API REST de tarefas
/// NOTA: Este é um serviço mock para demonstração offline-first
/// Em produção, substituir pela URL da API real
class ApiService {
  // URL base da API (substitua pela sua API real)
  static const String baseUrl = 'https://jsonplaceholder.typicode.com';
  
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Busca todas as tarefas do servidor
  Future<List<Task>> fetchTasks() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/todos'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        // Mock: converter JSONPlaceholder todos para Tasks
        return jsonList.take(10).map((json) => _mockTaskFromJson(json)).toList();
      } else {
        throw Exception('Falha ao buscar tarefas: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao buscar tarefas da API: $e');
      rethrow;
    }
  }

  /// Cria uma tarefa no servidor
  Future<Task> createTask(Task task) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/todos'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(_taskToMockJson(task)),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Tarefa criada no servidor: ${task.title}');
        return task.copyWith(syncStatus: 'synced');
      } else {
        throw Exception('Falha ao criar tarefa: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao criar tarefa na API: $e');
      rethrow;
    }
  }

  /// Atualiza uma tarefa no servidor
  Future<Task> updateTask(Task task) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/todos/1'), // Mock endpoint
        headers: {'Content-Type': 'application/json'},
        body: json.encode(_taskToMockJson(task)),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Tarefa atualizada no servidor: ${task.title}');
        return task.copyWith(syncStatus: 'synced');
      } else {
        throw Exception('Falha ao atualizar tarefa: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao atualizar tarefa na API: $e');
      rethrow;
    }
  }

  /// Deleta uma tarefa no servidor
  Future<void> deleteTask(String taskId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/todos/1'), // Mock endpoint
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ Tarefa deletada no servidor: $taskId');
      } else {
        throw Exception('Falha ao deletar tarefa: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao deletar tarefa na API: $e');
      rethrow;
    }
  }

  // ========== Helpers para conversão Mock ==========

  /// Converte JSONPlaceholder todo para Task (mock)
  Task _mockTaskFromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: 'Tarefa sincronizada da API',
      completed: json['completed'] ?? false,
      priority: 'medium',
      createdAt: DateTime.now(),
      syncStatus: 'synced',
    );
  }

  /// Converte Task para formato mock da API
  Map<String, dynamic> _taskToMockJson(Task task) {
    return {
      'title': task.title,
      'completed': task.completed,
      'userId': 1, // Mock user ID
    };
  }

  void dispose() {
    _client.close();
  }
}
