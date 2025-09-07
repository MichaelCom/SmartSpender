import 'package:hive/hive.dart';

part 'budget.g.dart';

@HiveType(typeId: 2)
class Budget extends HiveObject {
  @HiveField(0)
  int categoryKey; // Reference to Category's Hive key

  @HiveField(1)
  double amount;

  @HiveField(2)
  String period; // 'weekly', 'monthly', 'yearly'

  @HiveField(3)
  DateTime startDate;

  @HiveField(4)
  DateTime endDate;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  String? description;

  // Optional fields from joined queries (not stored in Hive)
  String? categoryName;
  String? categoryIcon;
  String? categoryColor;

  Budget({
    required this.categoryKey,
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

  // Convert Budget to Map for compatibility
  Map<String, dynamic> toMap() {
    return {
      'key': key, // Hive's auto-generated key
      'category_id': categoryKey,
      'amount': amount,
      'period': period,
      'start_date': startDate.toIso8601String().split('T')[0], // Store as YYYY-MM-DD
      'end_date': endDate.toIso8601String().split('T')[0], // Store as YYYY-MM-DD
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create Budget from Map (for migration purposes)
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      categoryKey: map['category_id']?.toInt() ?? 0,
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
    int? categoryKey,
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
      categoryKey: categoryKey ?? this.categoryKey,
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
    return 'Budget{key: $key, categoryKey: $categoryKey, amount: $amount, period: $period, startDate: $startDate, endDate: $endDate, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Budget &&
        other.key == key &&
        other.categoryKey == categoryKey &&
        other.amount == amount &&
        other.period == period &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return key.hashCode ^
        categoryKey.hashCode ^
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
    return 'R${formattedAmount}';
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

  // Get the ID (Hive key) for compatibility
  int? get id => key;
  
  // Get categoryId for compatibility
  int get categoryId => categoryKey;
}
