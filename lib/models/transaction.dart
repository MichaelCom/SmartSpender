import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 1)
class Transaction extends HiveObject {
  @HiveField(0)
  double amount;

  @HiveField(1)
  String? description;

  @HiveField(2)
  int categoryKey; // Reference to Category's Hive key

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  String type; // 'income' or 'expense'

  @HiveField(5)
  DateTime createdAt;

  // Optional fields from joined queries (not stored in Hive)
  String? categoryName;
  String? categoryIcon;
  String? categoryColor;

  Transaction({
    required this.amount,
    this.description,
    required this.categoryKey,
    required this.date,
    required this.type,
    required this.createdAt,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  // Convert Transaction to Map for compatibility
  Map<String, dynamic> toMap() {
    return {
      'key': key, // Hive's auto-generated key
      'amount': amount,
      'description': description,
      'category_id': categoryKey,
      'date': date.toIso8601String().split('T')[0], // Store as YYYY-MM-DD
      'type': type,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create Transaction from Map (for migration purposes)
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      amount: (map['amount'] as num).toDouble(),
      description: map['description'],
      categoryKey: map['category_id']?.toInt() ?? 0,
      date: DateTime.parse(map['date']),
      type: map['type'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      categoryName: map['category_name'],
      categoryIcon: map['category_icon'],
      categoryColor: map['category_color'],
    );
  }

  // Create a copy of Transaction with updated fields
  Transaction copyWith({
    double? amount,
    String? description,
    int? categoryKey,
    DateTime? date,
    String? type,
    DateTime? createdAt,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
  }) {
    return Transaction(
      amount: amount ?? this.amount,
      description: description ?? this.description,
      categoryKey: categoryKey ?? this.categoryKey,
      date: date ?? this.date,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
    );
  }

  @override
  String toString() {
    return 'Transaction{key: $key, amount: $amount, description: $description, categoryKey: $categoryKey, date: $date, type: $type, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
        other.key == key &&
        other.amount == amount &&
        other.description == description &&
        other.categoryKey == categoryKey &&
        other.date == date &&
        other.type == type &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return key.hashCode ^
        amount.hashCode ^
        description.hashCode ^
        categoryKey.hashCode ^
        date.hashCode ^
        type.hashCode ^
        createdAt.hashCode;
  }

  // Helper methods
  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  
  String get formattedAmount {
    return amount.toStringAsFixed(2);
  }
  
  String get displayAmount {
    final prefix = isIncome ? '+' : '-';
    return '${prefix}R${formattedAmount}';
  }

  // Get the ID (Hive key) for compatibility
  int? get id => key;
  
  // Get categoryId for compatibility
  int get categoryId => categoryKey;
}
