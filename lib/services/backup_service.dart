import 'dart:convert';

import '../models/budget.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../repositories/repositories.dart';

/// Current JSON backup schema version. Bump when the on-disk format changes.
const int kBackupSchemaVersion = 1;

/// Result of an import/restore attempt.
class ImportResult {
  final bool success;
  final String message; // user-facing summary or error
  final int categoriesImported;
  final int transactionsImported;
  final int budgetsImported;
  const ImportResult({
    required this.success,
    required this.message,
    this.categoriesImported = 0,
    this.transactionsImported = 0,
    this.budgetsImported = 0,
  });
}

/// Thrown by [BackupService.parseJson] / [BackupService.restoreFromJson] on bad
/// input (malformed JSON, unsupported schema, wrong shapes).
class BackupFormatException implements Exception {
  final String message;
  BackupFormatException(this.message);
  @override
  String toString() => 'BackupFormatException: $message';
}

/// In-memory parsed backup (domain models, with the OLD ids as given in the
/// file). The ids are only used to rebuild relationships during restore; the
/// database assigns fresh ids on insert.
class BackupData {
  final String appVersion; // schema/app version string from file
  final List<Category> categories;
  final List<Transaction> transactions;
  final List<Budget> budgets;
  const BackupData({
    required this.appVersion,
    required this.categories,
    required this.transactions,
    required this.budgets,
  });
}

/// Serializes app data to/from backup formats and performs Replace-restore.
///
/// This service never reads settings and performs no FX conversion: raw stored
/// amounts are exported as-is.
class BackupService {
  BackupService(this._repositories);
  final AppRepositories _repositories;

  /// Serializes ALL data (categories, transactions, budgets) to the JSON backup
  /// string described by the schema (version [kBackupSchemaVersion]).
  Future<String> exportToJsonString() async {
    final categories = await _repositories.categories.getAll();
    final transactions =
        await _repositories.transactions.getAllWithCategoryInfo();
    final budgets = await _repositories.budgets.getAllWithCategoryInfo();

    final map = <String, dynamic>{
      'schemaVersion': kBackupSchemaVersion,
      'app': 'SmartSpender',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'categories': categories.map(_categoryToJson).toList(),
      'transactions': transactions.map(_transactionToJson).toList(),
      'budgets': budgets.map(_budgetToJson).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Serializes transactions to a CSV string (export-only).
  ///
  /// Columns (header row required):
  /// `date,type,amount,category,description`
  /// - date: YYYY-MM-DD
  /// - type: income|expense
  /// - amount: raw number, 2 decimals, no symbol
  /// - category: category NAME, or empty string if uncategorised
  /// - description: RFC-4180 quoted when it contains comma/quote/newline
  Future<String> exportTransactionsToCsvString() async {
    final transactions =
        await _repositories.transactions.getAllWithCategoryInfo();

    final buffer = StringBuffer();
    // RFC-4180 uses CRLF line endings.
    buffer.write('date,type,amount,category,description\r\n');

    for (final t in transactions) {
      final date = _formatDate(t.date);
      final type = t.type;
      final amount = t.amount.toStringAsFixed(2);
      final category = t.categoryName ?? '';
      final description = t.description ?? '';

      final row = [
        _csvField(date),
        _csvField(type),
        _csvField(amount),
        _csvField(category),
        _csvField(description),
      ].join(',');

      buffer.write(row);
      buffer.write('\r\n');
    }

    return buffer.toString();
  }

  /// Parses + validates a JSON backup string WITHOUT touching the DB.
  ///
  /// Throws [BackupFormatException] on malformed/unsupported input.
  BackupData parseJson(String jsonString) {
    dynamic decoded;
    try {
      decoded = json.decode(jsonString);
    } on FormatException catch (e) {
      throw BackupFormatException('Invalid JSON: ${e.message}');
    }

    if (decoded is! Map) {
      throw BackupFormatException('Backup root must be a JSON object.');
    }
    final root = decoded;

    if (!root.containsKey('schemaVersion')) {
      throw BackupFormatException('Missing "schemaVersion".');
    }
    final schemaVersion = root['schemaVersion'];
    if (schemaVersion is! int || schemaVersion != kBackupSchemaVersion) {
      throw BackupFormatException(
        'Unsupported schemaVersion: $schemaVersion '
        '(expected $kBackupSchemaVersion).',
      );
    }

    final categoriesRaw = _requireList(root, 'categories');
    final transactionsRaw = _requireList(root, 'transactions');
    final budgetsRaw = _requireList(root, 'budgets');

    final categories = <Category>[];
    for (final e in categoriesRaw) {
      categories.add(_categoryFromJson(_requireObject(e, 'category')));
    }

    final transactions = <Transaction>[];
    for (final e in transactionsRaw) {
      transactions.add(_transactionFromJson(_requireObject(e, 'transaction')));
    }

    final budgets = <Budget>[];
    for (final e in budgetsRaw) {
      budgets.add(_budgetFromJson(_requireObject(e, 'budget')));
    }

    final appVersion = root['app'] is String ? root['app'] as String : '';

    return BackupData(
      appVersion: appVersion,
      categories: categories,
      transactions: transactions,
      budgets: budgets,
    );
  }

  /// RESTORE: wipes all data then inserts [data] parsed from [jsonString],
  /// re-mapping category ids so transaction/budget → category relationships are
  /// preserved under the new auto-increment ids.
  ///
  /// Transactions with a null or unknown categoryId import as uncategorised.
  /// Budgets referencing an unknown category are skipped (budgets require a
  /// valid category). Returns counts of what was actually inserted.
  Future<ImportResult> restoreFromJson(String jsonString) async {
    // Parse + validate first so a bad file never touches the DB.
    final BackupData data;
    try {
      data = parseJson(jsonString);
    } on BackupFormatException catch (e) {
      return ImportResult(success: false, message: e.message);
    }

    try {
      // Wipe everything, then insert fresh. clearAllData already runs in a DB
      // transaction; inserts below run sequentially so a mid-insert failure is
      // surfaced to the caller rather than silently partially applied.
      await _repositories.clearAllData();

      // oldCategoryId -> newCategoryId
      final idMap = <int, int>{};
      var categoriesImported = 0;
      for (final c in data.categories) {
        final oldId = c.id;
        final newId = await _repositories.categories.insert(
          c.copyWith(id: null),
        );
        if (oldId != null) {
          idMap[oldId] = newId;
        }
        categoriesImported++;
      }

      var transactionsImported = 0;
      for (final t in data.transactions) {
        final oldCategoryId = t.categoryId;
        final newCategoryId =
            oldCategoryId == null ? null : idMap[oldCategoryId];
        await _repositories.transactions.insert(
          t.copyWith(id: null)..categoryId = newCategoryId,
        );
        transactionsImported++;
      }

      var budgetsImported = 0;
      for (final b in data.budgets) {
        final newCategoryId = idMap[b.categoryId];
        // Budgets always need a valid category; skip orphans.
        if (newCategoryId == null) continue;
        await _repositories.budgets.insert(
          b.copyWith(id: null, categoryId: newCategoryId),
        );
        budgetsImported++;
      }

      return ImportResult(
        success: true,
        message: 'Restored $categoriesImported categories, '
            '$transactionsImported transactions, '
            '$budgetsImported budgets.',
        categoriesImported: categoriesImported,
        transactionsImported: transactionsImported,
        budgetsImported: budgetsImported,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Restore failed: $e',
      );
    }
  }

  // -------------------------------------------------------------------------
  // JSON serialization helpers
  // -------------------------------------------------------------------------

  Map<String, dynamic> _categoryToJson(Category c) => {
        'id': c.id,
        'name': c.name,
        'type': c.type,
        'color': c.color,
        'icon': c.icon,
        'createdAt': c.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _transactionToJson(Transaction t) => {
        'id': t.id,
        'amount': t.amount,
        'description': t.description,
        'categoryId': t.categoryId,
        'date': t.date.toIso8601String(),
        'type': t.type,
        'createdAt': t.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _budgetToJson(Budget b) => {
        'id': b.id,
        'categoryId': b.categoryId,
        'amount': b.amount,
        'period': b.period,
        'startDate': b.startDate.toIso8601String(),
        'endDate': b.endDate.toIso8601String(),
        'createdAt': b.createdAt.toIso8601String(),
        'description': b.description,
      };

  Category _categoryFromJson(Map<String, dynamic> m) => Category(
        id: _asIntOrNull(m['id']),
        name: _requireString(m, 'name'),
        type: _requireString(m, 'type'),
        color: _asStringOrNull(m['color']),
        icon: _asStringOrNull(m['icon']),
        createdAt: _parseDate(m, 'createdAt'),
      );

  Transaction _transactionFromJson(Map<String, dynamic> m) => Transaction(
        id: _asIntOrNull(m['id']),
        amount: _requireNum(m, 'amount').toDouble(),
        description: _asStringOrNull(m['description']),
        categoryId: _asIntOrNull(m['categoryId']),
        date: _parseDate(m, 'date'),
        type: _requireString(m, 'type'),
        createdAt: _parseDate(m, 'createdAt'),
      );

  Budget _budgetFromJson(Map<String, dynamic> m) => Budget(
        id: _asIntOrNull(m['id']),
        categoryId: _requireInt(m, 'categoryId'),
        amount: _requireNum(m, 'amount').toDouble(),
        period: _requireString(m, 'period'),
        startDate: _parseDate(m, 'startDate'),
        endDate: _parseDate(m, 'endDate'),
        createdAt: _parseDate(m, 'createdAt'),
        description: _asStringOrNull(m['description']),
      );

  // -------------------------------------------------------------------------
  // Validation / coercion helpers
  // -------------------------------------------------------------------------

  List _requireList(Map root, String key) {
    final value = root[key];
    if (value is! List) {
      throw BackupFormatException('"$key" must be a list.');
    }
    return value;
  }

  Map<String, dynamic> _requireObject(dynamic e, String what) {
    if (e is! Map) {
      throw BackupFormatException('Each $what must be a JSON object.');
    }
    return e.cast<String, dynamic>();
  }

  String _requireString(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is! String) {
      throw BackupFormatException('Field "$key" must be a string.');
    }
    return v;
  }

  num _requireNum(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is! num) {
      throw BackupFormatException('Field "$key" must be a number.');
    }
    return v;
  }

  int _requireInt(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is! int) {
      throw BackupFormatException('Field "$key" must be an integer.');
    }
    return v;
  }

  DateTime _parseDate(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is! String) {
      throw BackupFormatException('Field "$key" must be an ISO-8601 string.');
    }
    try {
      return DateTime.parse(v);
    } on FormatException {
      throw BackupFormatException('Field "$key" is not a valid date: $v');
    }
  }

  int? _asIntOrNull(dynamic v) => v is int ? v : null;

  String? _asStringOrNull(dynamic v) => v is String ? v : null;

  // -------------------------------------------------------------------------
  // CSV helpers
  // -------------------------------------------------------------------------

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// RFC-4180 field quoting: wrap in double quotes and double any embedded
  /// quotes when the field contains a comma, quote, CR, or LF.
  String _csvField(String value) {
    final needsQuoting = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuoting) return value;
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
