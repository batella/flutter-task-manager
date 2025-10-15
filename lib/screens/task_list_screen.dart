import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  List<Task> _filteredTasks = [];
  String _filter = 'all'; // all, completed, pending
  final _titleController = TextEditingController();
  String _selectedPriority = 'medium';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await DatabaseService.instance.readAll();
    setState(() {
      _tasks = tasks;
      _applyFilter();
    });
  }

  Future<void> _addTask() async {
    if (_titleController.text.trim().isEmpty) return;
    final task = Task(
      title: _titleController.text.trim(),
      priority: _selectedPriority,
    );
    await DatabaseService.instance.create(task);
    _titleController.clear();
    _selectedPriority = 'medium';
    _loadTasks();
  }

  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(completed: !task.completed);
    await DatabaseService.instance.update(updated);
    _loadTasks();
  }

  Future<void> _deleteTask(String id) async {
    await DatabaseService.instance.delete(id);
    _loadTasks();
  }

  void _applyFilter() {
    if (_filter == 'all') {
      _filteredTasks = List.from(_tasks);
    } else if (_filter == 'completed') {
      _filteredTasks = _tasks.where((t) => t.completed).toList();
    } else {
      _filteredTasks = _tasks.where((t) => !t.completed).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Minhas Tarefas (${_tasks.length})'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          hintText: 'Nova tarefa...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addTask,
                      child: const Text('Adicionar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Prioridade:'),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _selectedPriority,
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Baixa')),
                        DropdownMenuItem(value: 'medium', child: Text('Média')),
                        DropdownMenuItem(value: 'high', child: Text('Alta')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedPriority = v);
                      },
                    ),
                    const Spacer(),
                    ToggleButtons(
                      isSelected: [
                        _filter == 'all',
                        _filter == 'completed',
                        _filter == 'pending'
                      ],
                      onPressed: (i) {
                        setState(() {
                          _filter = i == 0 ? 'all' : (i == 1 ? 'completed' : 'pending');
                          _applyFilter();
                        });
                      },
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Todas')),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Completas')),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Pendentes')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredTasks.length,
              itemBuilder: (context, index) {
                final task = _filteredTasks[index];
                return ListTile(
                  leading: Checkbox(
                    value: task.completed,
                    onChanged: (_) => _toggleTask(task),
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text('Prioridade: ${task.priority} • ${task.createdAt.toLocal().toString().split('.').first}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteTask(task.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}