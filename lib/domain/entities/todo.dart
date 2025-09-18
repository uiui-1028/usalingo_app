/// ToDoアイテムのステータス
enum TodoStatus {
  /// 未完了
  pending,

  /// 完了
  completed,

  /// 削除済み
  deleted,
}

/// ToDoアイテムの優先度
enum TodoPriority {
  /// 低
  low,

  /// 中
  medium,

  /// 高
  high,

  /// 緊急
  urgent,
}

/// ToDoエンティティ
class Todo {
  /// 一意のID
  final String id;

  /// タイトル
  final String title;

  /// 説明（オプション）
  final String? description;

  /// ステータス
  final TodoStatus status;

  /// 優先度
  final TodoPriority priority;

  /// 作成日時
  final DateTime createdAt;

  /// 更新日時
  final DateTime updatedAt;

  /// 期限（オプション）
  final DateTime? dueDate;

  /// 完了日時（オプション）
  final DateTime? completedAt;

  const Todo({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    this.completedAt,
  });

  /// コピーコンストラクタ
  Todo copyWith({
    String? id,
    String? title,
    String? description,
    TodoStatus? status,
    TodoPriority? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dueDate,
    DateTime? completedAt,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// 完了済みかどうか
  bool get isCompleted => status == TodoStatus.completed;

  /// 期限切れかどうか
  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// 期限が近いかどうか（3日以内）
  bool get isDueSoon {
    if (dueDate == null || isCompleted) return false;
    final now = DateTime.now();
    final difference = dueDate!.difference(now).inDays;
    return difference >= 0 && difference <= 3;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Todo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Todo(id: $id, title: $title, status: $status, priority: $priority)';
  }
}
