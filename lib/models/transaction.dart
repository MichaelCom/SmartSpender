/// Plain domain model for a transaction.
///
/// [categoryId] is nullable: a transaction whose category has been deleted
/// becomes "uncategorised" rather than being removed.
class Transaction {
  final int? id;
  double amount;
  String? description;
  int? categoryId;
  DateTime date;
  String type; // 'income' or 'expense'
  DateTime createdAt;
  int? recurringId; // links to the recurring rule that generated this tx

  // Optional fields populated from joined queries (not persisted directly).
  String? categoryName;
  String? categoryIcon;
  String? categoryColor;

  Transaction({
    this.id,
    required this.amount,
    this.description,
    required this.categoryId,
    required this.date,
    required this.type,
    required this.createdAt,
    this.recurringId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  Transaction copyWith({
    int? id,
    double? amount,
    String? description,
    int? categoryId,
    DateTime? date,
    String? type,
    DateTime? createdAt,
    int? recurringId,
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
      recurringId: recurringId ?? this.recurringId,
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

  String get formattedAmount => amount.toStringAsFixed(2);

  // NOTE: Currency formatting is intentionally NOT done here. Domain models must
  // not read settings. Screens format via CurrencyFormatter.formatSigned(...)
  // using the symbol from SettingsController.currencySymbol.

  /// Human-friendly category label, falling back to "Uncategorised".
  String get displayCategoryName => categoryName ?? 'Uncategorised';

  /// Backwards-compatible alias for [id].
  int? get key => id;

  /// Backwards-compatible alias for [categoryId].
  int? get categoryKey => categoryId;
}
