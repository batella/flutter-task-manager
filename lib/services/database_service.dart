import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../models/sync_queue_item.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabela de categorias
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL
      )
    ''');

    // Tabela de tarefas (versão 2 com campos de sincronização)
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        completed INTEGER NOT NULL,
        priority TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        dueDate TEXT,
        categoryId TEXT,
        updatedAt TEXT NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (categoryId) REFERENCES categories (id)
      )
    ''');

    // Tabela de fila de sincronização
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        operation TEXT NOT NULL,
        taskId TEXT,
        timestamp TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');

    // Inserir categorias padrão
    await _insertDefaultCategories(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Adicionar campos de sincronização à tabela tasks
      await db.execute('ALTER TABLE tasks ADD COLUMN updatedAt TEXT NOT NULL DEFAULT "${DateTime.now().toIso8601String()}"');
      await db.execute('ALTER TABLE tasks ADD COLUMN syncStatus TEXT NOT NULL DEFAULT "pending"');

      // Criar tabela de fila de sincronização
      await db.execute('''
        CREATE TABLE sync_queue (
          id TEXT PRIMARY KEY,
          operation TEXT NOT NULL,
          taskId TEXT,
          timestamp TEXT NOT NULL,
          data TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final defaultCategories = [
      Category(name: 'Trabalho', color: 0xFF2196F3), // Azul
      Category(name: 'Pessoal', color: 0xFF4CAF50), // Verde
      Category(name: 'Estudo', color: 0xFFFF9800), // Laranja
      Category(name: 'Saúde', color: 0xFFE91E63), // Rosa
      Category(name: 'Compras', color: 0xFF9C27B0), // Roxo
    ];

    for (var category in defaultCategories) {
      await db.insert('categories', category.toMap());
    }
  }

  // Fallback para plataformas que não suportam sqflite (ex.: web)
  List<Category> _defaultCategoriesList() {
    return [
      Category(name: 'Trabalho', color: 0xFF2196F3),
      Category(name: 'Pessoal', color: 0xFF4CAF50),
      Category(name: 'Estudo', color: 0xFFFF9800),
      Category(name: 'Saúde', color: 0xFFE91E63),
      Category(name: 'Compras', color: 0xFF9C27B0),
    ];
  }

  Future<Task> create(Task task) async {
    try {
      final db = await database;
      await db.insert('tasks', task.toMap());
      
      // Adiciona à fila de sincronização
      final syncItem = SyncQueueItem.create(
        operation: 'create',
        taskId: task.id,
        data: task.toMap(),
      );
      await addToSyncQueue(syncItem);
      print('📝 Tarefa criada e adicionada à fila: ${task.title}');
      
      return task;
    } catch (e) {
      // Ambiente web ou erro ao acessar o banco: log e retornar o objeto sem persistência
      print('⚠️ Não foi possível salvar no DB (fallback): $e');
      return task;
    }
  }

  Future<Task?> read(String id) async {
    try {
      final db = await database;
      final maps = await db.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return Task.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('⚠️ Leitura de tarefa falhou (DB indisponível): $e');
      return null;
    }
  }

  Future<List<Task>> readAll() async {
    try {
      final db = await database;
      // Ordenar por: 1) tarefas não concluídas primeiro, 2) data de vencimento (nulls por último), 3) data de criação
      const orderBy = 'completed ASC, CASE WHEN dueDate IS NULL THEN 1 ELSE 0 END, dueDate ASC, createdAt DESC';
      final result = await db.query('tasks', orderBy: orderBy);
      return result.map((map) => Task.fromMap(map)).toList();
    } catch (e) {
      // Em ambientes onde sqflite não funciona (web), retornar lista vazia
      print('⚠️ readAll falhou (DB indisponível): $e');
      return <Task>[];
    }
  }

  Future<int> update(Task task) async {
    try {
      final db = await database;
      final result = await db.update(
        'tasks',
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
      
      // Só adiciona à fila se não estiver sincronizado
      if (task.syncStatus != 'synced') {
        final syncItem = SyncQueueItem.create(
          operation: 'update',
          taskId: task.id,
          data: task.toMap(),
        );
        await addToSyncQueue(syncItem);
        print('🔄 Tarefa atualizada e adicionada à fila: ${task.title}');
      }
      
      return result;
    } catch (e) {
      print('⚠️ update falhou (DB indisponível): $e');
      return 0;
    }
  }

  /// Atualiza apenas o syncStatus de uma tarefa (sem adicionar à fila)
  Future<int> updateSyncStatus(String taskId, String syncStatus) async {
    try {
      final db = await database;
      return await db.update(
        'tasks',
        {'syncStatus': syncStatus},
        where: 'id = ?',
        whereArgs: [taskId],
      );
    } catch (e) {
      print('⚠️ updateSyncStatus falhou: $e');
      return 0;
    }
  }

  Future<int> delete(String id) async {
    try {
      final db = await database;
      
      // Adiciona à fila de sincronização antes de deletar
      final syncItem = SyncQueueItem.create(
        operation: 'delete',
        taskId: id,
        data: {},
      );
      await addToSyncQueue(syncItem);
      
      final result = await db.delete(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('🗑️ Tarefa deletada e adicionada à fila: $id');
      
      return result;
    } catch (e) {
      print('⚠️ delete falhou (DB indisponível): $e');
      return 0;
    }
  }

  // ========== CRUD para Categorias ==========
  
  Future<List<Category>> readAllCategories() async {
    try {
      if (kIsWeb) {
        return _defaultCategoriesList();
      }

      final db = await database;
      final result = await db.query('categories', orderBy: 'name ASC');
      return result.map((map) => Category.fromMap(map)).toList();
    } catch (e) {
      print('⚠️ readAllCategories falhou (DB indisponível): $e');
      return _defaultCategoriesList();
    }
  }

  Future<Category> createCategory(Category category) async {
    final db = await database;
    await db.insert('categories', category.toMap());
    return category;
  }

  Future<Category?> readCategory(String id) async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Category.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await database;
    // Primeiro, remover a referência de categoria das tarefas
    await db.update(
      'tasks',
      {'categoryId': null},
      where: 'categoryId = ?',
      whereArgs: [id],
    );
    // Depois deletar a categoria
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== Métodos para Fila de Sincronização ==========

  /// Adiciona um item à fila de sincronização
  Future<void> addToSyncQueue(SyncQueueItem item) async {
    try {
      final db = await database;
      await db.insert('sync_queue', {
        'id': item.id,
        'operation': item.operation,
        'taskId': item.taskId,
        'timestamp': item.timestamp.toIso8601String(),
        'data': jsonEncode(item.data),
      });
      print('📤 Item adicionado à fila: ${item.operation} - ${item.taskId}');
    } catch (e) {
      print('⚠️ addToSyncQueue falhou: $e');
    }
  }

  /// Remove um item da fila de sincronização
  Future<void> removeFromSyncQueue(String id) async {
    try {
      final db = await database;
      await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('⚠️ removeFromSyncQueue falhou: $e');
    }
  }

  /// Retorna todos os itens da fila de sincronização, ordenados por timestamp
  Future<List<SyncQueueItem>> getSyncQueue() async {
    try {
      final db = await database;
      final result = await db.query('sync_queue', orderBy: 'timestamp ASC');
      print('📋 Itens na fila de sincronização: ${result.length}');
      
      List<SyncQueueItem> items = [];
      for (final map in result) {
        try {
          final item = SyncQueueItem.fromMap(map);
          items.add(item);
          print('  ✓ ${item.operation}: ${item.taskId}');
        } catch (e) {
          // Se houver erro ao parsear, remove o item corrompido
          print('  ✗ Item corrompido removido: ${map['id']} - $e');
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [map['id']]);
        }
      }
      
      return items;
    } catch (e) {
      print('⚠️ getSyncQueue falhou: $e');
      return [];
    }
  }

  /// Limpa toda a fila de sincronização (após sync bem-sucedido)
  Future<void> clearSyncQueue() async {
    try {
      final db = await database;
      await db.delete('sync_queue');
    } catch (e) {
      print('⚠️ clearSyncQueue falhou: $e');
    }
  }
}