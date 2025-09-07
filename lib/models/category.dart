import 'package:hive/hive.dart';

part 'category.g.dart';

@HiveType(typeId: 0)
class Category extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String type; // 'income' or 'expense'

  @HiveField(2)
  String? color;

  @HiveField(3)
  String? icon;

  @HiveField(4)
  DateTime createdAt;

  Category({
    required this.name,
    required this.type,
    this.color,
    this.icon,
    required this.createdAt,
  });

  // Convert Category to Map for compatibility (if needed)
  Map<String, dynamic> toMap() {
    return {
      'key': key, // Hive's auto-generated key
      'name': name,
      'type': type,
      'color': color,
      'icon': icon,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create Category from Map (for migration purposes)
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      color: map['color'],
      icon: map['icon'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // Create a copy of Category with updated fields
  Category copyWith({
    String? name,
    String? type,
    String? color,
    String? icon,
    DateTime? createdAt,
  }) {
    return Category(
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Category{key: $key, name: $name, type: $type, color: $color, icon: $icon, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.key == key &&
        other.name == name &&
        other.type == type &&
        other.color == color &&
        other.icon == icon &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return key.hashCode ^
        name.hashCode ^
        type.hashCode ^
        color.hashCode ^
        icon.hashCode ^
        createdAt.hashCode;
  }

  // Helper methods
  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  
  // Get the ID (Hive key) for compatibility
  int? get id => key;
}
