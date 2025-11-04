# Relatório - Laboratório 2: Interface Profissional

## 1. Implementações Realizadas

- Lista de tarefas com criação, edição e exclusão persistentes.
  - Implementado CRUD de tarefas em `lib/services/database_service.dart` usando SQLite (`sqflite`).
  - Ordenação e filtros aplicados (status — todas/pendentes/concluídas, filtro por categoria).
- Formulário de tarefa com validação e campos ricos.
  - Tela de formulário em `lib/screens/task_form_screen.dart` com `TextFormField`, `DropdownButtonFormField`, `SwitchListTile`, seleção de data (`showDatePicker`) e botões de ação (`ElevatedButton`, `OutlinedButton`).
- Visualização de tarefas.
  - Tela de lista em `lib/screens/task_list_screen.dart` que usa `ListView.builder`, `RefreshIndicator` e um `TaskCard` customizado (`lib/widgets/task_card.dart`).
- Gestão de categorias.
  - Tabelas e CRUD para categorias em `DatabaseService`. Inserção de categorias padrão ao criar o banco.
- Feedback e UX.
  - Uso de `SnackBar` para confirmar ações (criação/atualização/exclusão).
  - Caixa de diálogo de confirmação (`AlertDialog`) para exclusão.

### Componentes Material Design 3 utilizados

- `MaterialApp` com `useMaterial3: true` e `ColorScheme.fromSeed` (definido em `lib/main.dart`).
- `AppBar` (barra superior com ações e menu de filtro).
- `FloatingActionButton.extended` para criar nova tarefa.
- `Card` / `CardTheme` (tema global e `Card` em formulários/itens). 
- `ListView` / `ListTile` (via `TaskCard` para exibir cada tarefa).
- `PopupMenuButton` / `PopupMenuItem` (filtros de status).
- `DropdownButtonFormField` (prioridade e filtro por categoria).
- `TextFormField` (título, descrição) com `InputDecorationTheme` global.
- `SwitchListTile` (marcar tarefa como completa).
- `SnackBar`, `AlertDialog`, `CircularProgressIndicator`, `RefreshIndicator`.
- Botões: `ElevatedButton` e `OutlinedButton` (ações no formulário).

## 2. Desafios Encontrados

- Sincronização UI ↔ Banco de dados
  - Dificuldade: garantir que a lista se atualize após operações assíncronas (create/update/delete).
  - Solução: padronizei chamadas a `_loadTasks()` após operações e usei `setState` para atualizar o estado; navegações retornam `true` do `Navigator.pop` para indicar sucesso e forçar recarga.

- Migrações de esquema do banco
  - Dificuldade: adicionar novas colunas (por exemplo, `dueDate`, `categoryId`) mantendo dados existentes.
  - Solução: implementei `onUpgrade` em `DatabaseService._onUpgrade` com verificação de versão e scripts ALTER/CREATE conforme necessário; também criei rotina de inserção de categorias padrão.

- Validação e usabilidade do formulário
  - Dificuldade: combinar validação de campos obrigatórios e UX (ex.: seleção de data e categorias opcionais).
  - Solução: usei `Form` + `GlobalKey<FormState>` e mensagens de validação, campos com `InputDecoration`, e componentes com estado local (controllers) para manter dados durante edição.

## 3. Melhorias Implementadas

- Além do roteiro básico, adicionei/ajustei:
  - Painel de estatísticas na tela principal (total, pendentes, concluídas) com decoração gradient e ícones.
  - Filtro por categoria via `DropdownButtonFormField` para facilitar visualização por contexto.
  - Ordenação customizada no `DatabaseService.readAll()` para priorizar tarefas pendentes e ordenar por `dueDate` e `createdAt`.

- Customizações visuais:
  - Tema Material 3 ativado (`useMaterial3: true`) com `ColorScheme.fromSeed` e `cardTheme` customizado em `lib/main.dart`.
  - `InputDecorationTheme` global para bordas arredondadas e campos preenchidos, melhorando consistência visual.
  - Botões com `RoundedRectangleBorder` e espaçamentos padronizados para melhor toque e aparência.

## 4. Aprendizados

- Principais conceitos aprendidos
  - Integração local persistente com SQLite usando `sqflite` e padrões de migração de banco.
  - Gerenciamento de estado local com `setState` e padrões para recarregar dados após operações assíncronas.
  - Boas práticas em formulários Flutter: uso de `Form`, validators, `TextEditingController` e feedback de usuário com `SnackBar` e `AlertDialog`.
  - Aplicação prática do Material 3 no Flutter (`useMaterial3`, `ColorScheme.fromSeed`, `CardTheme` e `InputDecorationTheme`).

- Diferenças entre Lab 1 e Lab 2
  - Lab 1 (presumido): provavelmente abordou fundamentos (layout básico, navegação, widgets simples e estado). 
  - Lab 2: evolução para interface profissional: tema Material 3, persistência local com banco de dados, formulários com validação, filtros, estado mais robusto e pequenas otimizações de UX (estatísticas, filtros por categoria, migração de esquema).

## 5. Próximos Passos

- Funcionalidades a adicionar
  - Autenticação opcional e sincronização remota (ex.: API ou Firestore) para multi-dispositivo.
  - Notificações locais para lembretes de tarefas com `dueDate` (ex.: `flutter_local_notifications`).
  - Prioridades visuais na lista (indicadores de cor/urgência) e ordenação customizável pelo usuário.
  - Tela de gerenciamento de categorias (criar/editar/excluir categorias pela UI).

- Ideias para melhorar a aplicação
  - Adicionar testes unitários e widget tests para cobertura das principais flows (criação/edição/exclusão/filtragem).
  - Internacionalização (já há `intl` nas dependências) e suporte a múltiplos idiomas com arquivos de localizações.
  - Melhorar acessibilidade: labels, contrastes, tamanhos de toque e suporte a temas dinâmicos (dark mode automático baseado no sistema).
  - Refatoração para separar a lógica de negócio da UI (ex.: Provider, Riverpod ou BLoC) se o app for escalado.

---

Observações de verificação
- Arquivos inspecionados para compor este relatório: `pubspec.yaml`, `lib/main.dart`, `lib/screens/task_list_screen.dart`, `lib/screens/task_form_screen.dart`, `lib/services/database_service.dart`, `lib/widgets/task_card.dart`.
