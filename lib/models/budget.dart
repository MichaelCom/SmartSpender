/// Plain domain model for a budget.
///
/// A budget always belongs to a category; if the category is deleted the budget
/// is deleted too (cascade).
class Budget {
  final int? id;
  int categoryId;
  double amount;
  String period; // 'weekly', 'monthly', 'yearly'
  DateTime startDate;
  DateTime endDate;
  DateTime createdAt;
  String? description;

  // Optional fields populated from joined queries (not persisted directly).
  String? categoryName;
  String? categoryIcon;
  String? categoryColor;

  Budget({
    this.id,
    required this.categoryId,
    required this.amount,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.description,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  Budget copyWith({
    int? id,
    int? categoryId,
    double? amount,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    String? description,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
    );
  }

  @override
  String toString() {
    return 'Budget{id: $id, categoryId: $categoryId, amount: $amount, period: $period, startDate: $startDate, endDate: $endDate, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Budget &&
        other.id == id &&
        other.categoryId == categoryId &&
        other.amount == amount &&
        other.period == period &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        categoryId.hashCode ^
        amount.hashCode ^
        period.hashCode ^
        startDate.hashCode ^
        endDate.hashCode ^
        createdAt.hashCode;
  }

  // Helper methods
  bool get isWeekly => period == 'weekly';
  bool get isMonthly => period == 'monthly';
  bool get isYearly => period == 'yearly';

  String get formattedAmount => amount.toStringAsFixed(2);

  String get displayAmount => 'R$formattedAmount';

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) &&
        now.isBefore(endDate.add(const Duration(days: 1)));
  }

  Duration get remainingDuration {
    final now = DateTime.now();
    if (now.isAfter(endDate)) {
      return Duration.zero;
    }
    return endDate.difference(now);
  }

  int get remainingDays => remainingDuration.inDays;

  double calculateProgress(double spentAmount) {
    if (amount <= 0) return 0.0;
    return (spentAmount / amount).clamp(0.0, 1.0);
  }

  bool isExceeded(double spentAmount) => spentAmount > amount;

  double getRemainingAmount(double spentAmount) {
    return (amount - spentAmount).clamp(0.0, double.infinity);
  }

  /// Backwards-compatible alias for [id].
  int? get key => id;

  /// Backwards-compatible alias for [categoryId].
  int get categoryKey => categoryId;
}
