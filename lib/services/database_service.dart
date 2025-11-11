import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/category.dart';

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
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
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

    // Tabela de tarefas
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
        photoPaths TEXT,
        completedAt TEXT,
        completedBy TEXT,
        latitude REAL,
        longitude REAL,
        locationName TEXT,
        FOREIGN KEY (categoryId) REFERENCES categories (id)
      )
    ''');

    // Inserir categorias padrão
    await _insertDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migração incremental para cada versão
    if (oldVersion < 2) {
      // versões antigas podem já ter photoPath adicionado em v2
      await db.execute('ALTER TABLE tasks ADD COLUMN photoPath TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN completedBy TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE tasks ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN locationName TEXT');
    }
    // v5: migrar para photoPaths (JSON array)
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN photoPaths TEXT');

        // Migrar dados existentes de photoPath para photoPaths
        final rows = await db.query('tasks');
        for (final row in rows) {
          final id = row['id'] as String?;
          final oldPhoto = row['photoPath'] as String?;
          final newPhotoPaths = row['photoPaths'] as String?;

          if (id != null && oldPhoto != null && (newPhotoPaths == null || newPhotoPaths.isEmpty)) {
            final migrated = '["' + oldPhoto.replaceAll('"', '\\"') + '"]';
            await db.update('tasks', {'photoPaths': migrated}, where: 'id = ?', whereArgs: [id]);
          }
        }
      } catch (e) {
        print('⚠️ Erro na migração para photoPaths: $e');
      }
    }
    print('✅ Banco migrado de v$oldVersion para v$newVersion');
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

  // Método especial: buscar tarefas por proximidade
  Future<List<Task>> getTasksNearLocation({
    required double latitude,
    required double longitude,
    double radiusInMeters = 1000,
  }) async {
    final allTasks = await readAll();

    return allTasks.where((task) {
      if (!task.hasLocation) return false;

      // Cálculo de distância usando fórmula de Haversine (simplificada)
      final latDiff = (task.latitude! - latitude).abs();
      final lonDiff = (task.longitude! - longitude).abs();
      final distance = ((latDiff * 111000) + (lonDiff * 111000)) / 2;

      return distance <= radiusInMeters;
    }).toList();
  }


  Future<int> update(Task task) async {
    try {
      final db = await database;
      return db.update(
        'tasks',
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
    } catch (e) {
      print('⚠️ update falhou (DB indisponível): $e');
      return 0;
    }
  }

  Future<int> delete(String id) async {
    try {
      final db = await database;
      return await db.delete(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
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
}