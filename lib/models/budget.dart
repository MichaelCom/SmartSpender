class Budget {
  final int? id;
  final int categoryId;
  final double amount;
  final String period; // 'weekly', 'monthly', 'yearly'
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  // Optional fields from joined queries
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  Budget({
    this.id,
    required this.categoryId,
    required this.amount,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  // Convert Budget to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'amount': amount,
      'period': period,
      'start_date': startDate.toIso8601String().split('T')[0], // Store as YYYY-MM-DD
      'end_date': endDate.toIso8601String().split('T')[0], // Store as YYYY-MM-DD
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create Budget from Map (database result)
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id']?.toInt(),
      categoryId: map['category_id']?.toInt() ?? 0,
      amount: (map['amount'] as num).toDouble(),
      period: map['period'] ?? '',
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      createdAt: DateTime.parse(map['created_at']),
      categoryName: map['category_name'],
      categoryIcon: map['category_icon'],
      categoryColor: map['category_color'],
    );
  }

  // Create a copy of Budget with updated fields
  Budget copyWith({
    int? id,
    int? categoryId,
    double? amount,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
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
  
  String get formattedAmount {
    return amount.toStringAsFixed(2);
  }
  
  String get displayAmount {
    return '\$${formattedAmount}';
  }

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate.add(const Duration(days: 1)));
  }

  Duration get remainingDuration {
    final now = DateTime.now();
    if (now.isAfter(endDate)) {
      return Duration.zero;
    }
    return endDate.difference(now);
  }

  int get remainingDays {
    return remainingDuration.inDays;
  }

  // Calculate budget progress (requires spent amount)
  double calculateProgress(double spentAmount) {
    if (amount <= 0) return 0.0;
    return (spentAmount / amount).clamp(0.0, 1.0);
  }

  // Check if budget is exceeded
  bool isExceeded(double spentAmount) {
    return spentAmount > amount;
  }

  // Get remaining budget amount
  double getRemainingAmount(double spentAmount) {
    return (amount - spentAmount).clamp(0.0, double.infinity);
  }
}
