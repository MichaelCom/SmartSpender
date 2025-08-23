class Transaction {
  final int? id;
  final double amount;
  final String? description;
  final int categoryId;
  final DateTime date;
  final String type; // 'income' or 'expense'
  final DateTime createdAt;

  // Optional fields from joined queries
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  Transaction({
    this.id,
    required this.amount,
    this.description,
    required this.categoryId,
    required this.date,
    required this.type,
    required this.createdAt,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  // Convert Transaction to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'category_id': categoryId,
      'date': date.toIso8601String().split('T')[0], // Store as YYYY-MM-DD
      'type': type,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create Transaction from Map (database result)
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id']?.toInt(),
      amount: (map['amount'] as num).toDouble(),
      description: map['description'],
      categoryId: map['category_id']?.toInt() ?? 0,
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
    int? id,
    double? amount,
    String? description,
    int? categoryId,
    DateTime? date,
    String? type,
    DateTime? createdAt,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
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
    return 'Transaction{id: $id, amount: $amount, description: $description, categoryId: $categoryId, date: $date, type: $type, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
        other.id == id &&
        other.amount == amount &&
        other.description == description &&
        other.categoryId == categoryId &&
        other.date == date &&
        other.type == type &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        amount.hashCode ^
        description.hashCode ^
        categoryId.hashCode ^
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
    return '$prefix\$${formattedAmount}';
  }
}
