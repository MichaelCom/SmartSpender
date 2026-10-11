import '../../models/category.dart';
import '../../models/transaction.dart';

/// A category suggestion with a confidence signal.
class CategorySuggestion {
  /// The suggested category id.
  final int categoryId;

  /// Human-readable reason, e.g. "You usually tag 'uber' as Transport".
  final String reason;

  /// Whether this came from the user's own history (true) or a seed rule.
  final bool fromHistory;

  const CategorySuggestion({
    required this.categoryId,
    required this.reason,
    required this.fromHistory,
  });
}

/// Offline auto-categorization: seed keyword rules + learning from the user's
/// own tagging history. History always overrides seed rules.
///
/// Pure/stateless — callers pass the current categories and transaction history.
class CategorizationEngine {
  /// Minimum number of matching historical precedents before a history-based
  /// suggestion is considered confident enough to surface.
  static const int minHistoryMatches = 2;

  /// Seed keyword → canonical category-name hints. Matched case-insensitively
  /// as substrings of the description. Values are matched against the user's
  /// actual category names (case-insensitive); if no such category exists the
  /// seed rule is simply skipped (users may have custom category names).
  static const Map<String, String> seedKeywords = {
    // Transport
    'uber': 'Transportation',
    'bolt': 'Transportation',
    'taxi': 'Transportation',
    'fuel': 'Transportation',
    'petrol': 'Transportation',
    'gas station': 'Transportation',
    'parking': 'Transportation',
    'gautrain': 'Transportation',
    // Food & Dining
    'woolworths': 'Food & Dining',
    'checkers': 'Food & Dining',
    'pick n pay': 'Food & Dining',
    'spar': 'Food & Dining',
    'restaurant': 'Food & Dining',
    'cafe': 'Food & Dining',
    'coffee': 'Food & Dining',
    'mcdonald': 'Food & Dining',
    'kfc': 'Food & Dining',
    'uber eats': 'Food & Dining',
    'mr d': 'Food & Dining',
    'grocery': 'Food & Dining',
    'groceries': 'Food & Dining',
    // Entertainment
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
    'showmax': 'Entertainment',
    'disney': 'Entertainment',
    'cinema': 'Entertainment',
    'movie': 'Entertainment',
    'youtube premium': 'Entertainment',
    // Bills & Utilities
    'electricity': 'Bills & Utilities',
    'eskom': 'Bills & Utilities',
    'water': 'Bills & Utilities',
    'rent': 'Bills & Utilities',
    'vodacom': 'Bills & Utilities',
    'mtn': 'Bills & Utilities',
    'telkom': 'Bills & Utilities',
    'internet': 'Bills & Utilities',
    'insurance': 'Bills & Utilities',
    // Healthcare
    'pharmacy': 'Healthcare',
    'clicks': 'Healthcare',
    'dis-chem': 'Healthcare',
    'doctor': 'Healthcare',
    'hospital': 'Healthcare',
    'dentist': 'Healthcare',
    // Shopping
    'takealot': 'Shopping',
    'amazon': 'Shopping',
    'mall': 'Shopping',
    'clothing': 'Shopping',
    // Income
    'salary': 'Salary',
    'payroll': 'Salary',
  };

  /// Returns a suggestion for [description] given the user's [categories] and
  /// transaction [history], or null when nothing is confident enough.
  ///
  /// Strategy:
  ///  1. History: among past transactions whose description shares a
  ///     significant token with [description], pick the most-used category if
  ///     it has at least [minHistoryMatches] precedents.
  ///  2. Seed rules: otherwise, if a seed keyword appears in [description] and
  ///     maps to an existing category, suggest that.
  ///  3. Else null.
  ///
  /// [type] optionally restricts suggestions to categories of that type
  /// ('income' | 'expense'); when provided, only matching categories are used.
  static CategorySuggestion? suggest({
    required String description,
    required List<Category> categories,
    required List<Transaction> history,
    String? type,
  }) {
    final desc = description.trim().toLowerCase();
    if (desc.isEmpty) return null;

    final byId = {for (final c in categories) if (c.id != null) c.id!: c};
    bool typeOk(int categoryId) {
      if (type == null) return true;
      final c = byId[categoryId];
      return c != null && c.type == type;
    }

    // --- 1. History ---
    final descTokens = _tokens(desc);
    final counts = <int, int>{};
    for (final tx in history) {
      final cid = tx.categoryId;
      if (cid == null || !byId.containsKey(cid) || !typeOk(cid)) continue;
      final txDesc = (tx.description ?? '').toLowerCase();
      if (txDesc.isEmpty) continue;
      if (_shareSignificantToken(descTokens, _tokens(txDesc))) {
        counts[cid] = (counts[cid] ?? 0) + 1;
      }
    }
    if (counts.isNotEmpty) {
      final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      if (best.value >= minHistoryMatches) {
        final name = byId[best.key]?.name ?? 'this category';
        return CategorySuggestion(
          categoryId: best.key,
          reason: "You usually tag similar transactions as $name",
          fromHistory: true,
        );
      }
    }

    // --- 2. Seed rules ---
    // Longer keywords first so 'uber eats' beats 'uber'.
    final keywords = seedKeywords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final kw in keywords) {
      if (!desc.contains(kw)) continue;
      final targetName = seedKeywords[kw]!.toLowerCase();
      for (final c in categories) {
        if (c.id == null) continue;
        if (c.name.toLowerCase() == targetName && typeOk(c.id!)) {
          return CategorySuggestion(
            categoryId: c.id!,
            reason: "'$kw' usually means ${c.name}",
            fromHistory: false,
          );
        }
      }
    }

    return null;
  }

  /// Splits a lowercased string into alphanumeric tokens of length >= 3,
  /// dropping very common noise words.
  static Set<String> _tokens(String s) {
    const stop = {'the', 'and', 'for', 'payment', 'purchase', 'from', 'with'};
    return s
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length >= 3 && !stop.contains(t))
        .toSet();
  }

  /// True if the two token sets share at least one token.
  static bool _shareSignificantToken(Set<String> a, Set<String> b) {
    for (final t in a) {
      if (b.contains(t)) return true;
    }
    return false;
  }
}
