class Category {
  final int? id;
  final String name;
  final String type; // 'income' or 'expense'
  final String? color;
  final String? icon;
  final DateTime createdAt;

  Category({
    this.id,
    required this.name,
    required this.type,
    this.color,
    this.icon,
    required this.createdAt,
  });

  // Convert Category to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'color': color,
      'icon': icon,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create Category from Map (database result)
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      color: map['color'],
      icon: map['icon'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // Create a copy of Category with updated fields
  Category copyWith({
    int? id,
    String? name,
    String? type,
    String? color,
    String? icon,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Category{id: $id, name: $name, type: $type, color: $color, icon: $icon, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.color == color &&
        other.icon == icon &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        type.hashCode ^
        color.hashCode ^
        icon.hashCode ^
        createdAt.hashCode;
  }

  // Helper methods
  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
}
