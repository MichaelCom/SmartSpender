/// Plain domain model for a spending/income category.
///
/// Persistence is handled by the Drift layer; this class is intentionally free
/// of any storage annotations so it can be mapped to/from any backend.
class Category {
  final int? id;
  String name;
  String type; // 'income' or 'expense'
  String? color;
  String? icon;
  DateTime createdAt;

  Category({
    this.id,
    required this.name,
    required this.type,
    this.color,
    this.icon,
    required this.createdAt,
  });

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

  /// Backwards-compatible alias for [id].
  int? get key => id;
}
