/// Plain domain model for a recurring transaction rule.
///
/// A rule generates concrete transactions on a schedule. [categoryId] is
/// nullable: if the category is deleted the rule becomes "uncategorised"
/// (SET NULL) rather than being removed.
///
/// NOTE: Currency formatting is intentionally NOT done here. Domain models must
/// not read settings. Screens format via CurrencyFormatter using the symbol
/// from SettingsController.currencySymbol.
class RecurringTransaction {
  final int? id;
  double amount;
  String? description;
  int? categoryId;
  String type; // 'income' or 'expense'
  String frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  DateTime startDate;
  DateTime? endDate;
  DateTime? lastGeneratedDate;
  DateTime createdAt;

  // Optional fields populated from joined queries (not persisted directly).
  String? categoryName;
  String? categoryIcon;
  String? categoryColor;

  RecurringTransaction({
    this.id,
    required this.amount,
    this.description,
    required this.categoryId,
    required this.type,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.lastGeneratedDate,
    required this.createdAt,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  RecurringTransaction copyWith({
    int? id,
    double? amount,
    String? description,
    int? categoryId,
    String? type,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? lastGeneratedDate,
    DateTime? createdAt,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
      createdAt: createdAt ?? this.createdAt,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
    );
  }

  @override
  String toString() {
    return 'RecurringTransaction{id: $id, amount: $amount, description: $description, '
        'categoryId: $categoryId, type: $type, frequency: $frequency, '
        'startDate: $startDate, endDate: $endDate, '
        'lastGeneratedDate: $lastGeneratedDate, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecurringTransaction &&
        other.id == id &&
        other.amount == amount &&
        other.description == description &&
        other.categoryId == categoryId &&
        other.type == type &&
        other.frequency == frequency &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.lastGeneratedDate == lastGeneratedDate &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        amount.hashCode ^
        description.hashCode ^
        categoryId.hashCode ^
        type.hashCode ^
        frequency.hashCode ^
        startDate.hashCode ^
        endDate.hashCode ^
        lastGeneratedDate.hashCode ^
        createdAt.hashCode;
  }

  // Helper methods
  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  String get formattedAmount => amount.toStringAsFixed(2);

  /// Human-friendly category label, falling back to "Uncategorised".
  String get displayCategoryName => categoryName ?? 'Uncategorised';

  /// Advances [d] by one period of this rule's [frequency].
  ///
  /// daily: +1 day, weekly: +7 days, monthly: +1 month, yearly: +1 year.
  /// Month/year arithmetic clamps the day for shorter months (e.g. Jan 31 +1
  /// month => Mar 3 via DateTime normalisation; acceptable for this app).
  DateTime advance(DateTime d) {
    switch (frequency) {
      case 'daily':
        return d.add(const Duration(days: 1));
      case 'weekly':
        return d.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(d.year, d.month + 1, d.day, d.hour, d.minute, d.second,
            d.millisecond, d.microsecond);
      case 'yearly':
        return DateTime(d.year + 1, d.month, d.day, d.hour, d.minute, d.second,
            d.millisecond, d.microsecond);
      default:
        return d.add(const Duration(days: 1));
    }
  }

  /// The next due date strictly after [from], based on [startDate] and the
  /// rule's frequency. If [from] is before [startDate], returns [startDate].
  DateTime nextDueDate(DateTime from) {
    if (!from.isAfter(startDate) && !from.isAtSameMomentAs(startDate)) {
      return startDate;
    }
    var next = startDate;
    while (!next.isAfter(from)) {
      next = advance(next);
    }
    return next;
  }

  /// True when [now] is within the active window `[startDate, endDate?]`.
  bool isActive(DateTime now) {
    if (now.isBefore(startDate)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }
}
