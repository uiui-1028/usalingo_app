import '../entities/todo.dart';

/// ToDoリポジトリのインターフェース
abstract class TodoRepository {
  /// すべてのToDoを取得
  Future<List<Todo>> getAllTodos();

  /// アクティブなToDoを取得（削除済み以外）
  Future<List<Todo>> getActiveTodos();

  /// 完了済みToDoを取得
  Future<List<Todo>> getCompletedTodos();

  /// IDでToDoを取得
  Future<Todo?> getTodoById(String id);

  /// ステータスでToDoをフィルタリング
  Future<List<Todo>> getTodosByStatus(TodoStatus status);

  /// 優先度でToDoをフィルタリング
  Future<List<Todo>> getTodosByPriority(TodoPriority priority);

  /// 期限でToDoをフィルタリング
  Future<List<Todo>> getTodosByDueDate(DateTime date);

  /// 期限切れのToDoを取得
  Future<List<Todo>> getOverdueTodos();

  /// 期限が近いToDoを取得（3日以内）
  Future<List<Todo>> getDueSoonTodos();

  /// 検索クエリでToDoを検索
  Future<List<Todo>> searchTodos(String query);

  /// ToDoを作成
  Future<Todo> createTodo(Todo todo);

  /// ToDoを更新
  Future<Todo> updateTodo(Todo todo);

  /// ToDoを削除（論理削除）
  Future<void> deleteTodo(String id);

  /// ToDoを完全削除
  Future<void> permanentlyDeleteTodo(String id);

  /// ToDoを完了にする
  Future<Todo> completeTodo(String id);

  /// ToDoを未完了に戻す
  Future<Todo> uncompleteTodo(String id);

  /// 複数のToDoを一括更新
  Future<List<Todo>> updateMultipleTodos(List<Todo> todos);

  /// 完了済みToDoを一括削除
  Future<void> deleteCompletedTodos();

  /// すべてのToDoを削除
  Future<void> deleteAllTodos();

  /// ToDoの総数を取得
  Future<int> getTodoCount();

  /// 完了済みToDoの数を取得
  Future<int> getCompletedTodoCount();

  /// 未完了ToDoの数を取得
  Future<int> getPendingTodoCount();
}
