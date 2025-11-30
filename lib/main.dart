import 'package:flutter/material.dart';
import 'screens/task_list_screen.dart';
import 'services/connectivity_service.dart';
import 'services/api_service.dart';
import 'services/sync_service.dart';
import 'services/database_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ConnectivityService _connectivityService;
  late final ApiService _apiService;
  late final SyncService _syncService;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  void _initServices() {
    _connectivityService = ConnectivityService();
    _apiService = ApiService();
    _syncService = SyncService(
      dbService: DatabaseService.instance,
      apiService: _apiService,
      connectivityService: _connectivityService,
    );
  }

  @override
  void dispose() {
    _connectivityService.dispose();
    _apiService.dispose();
    _syncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(  // ← CardThemeData ao invés de CardTheme
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          filled: true,
          fillColor: Color(0xFFF5F5F5), // Colors.grey.shade50
        ),
      ),
      home: TaskListScreen(
        connectivityService: _connectivityService,
        syncService: _syncService,
      ),
    );
  }
}