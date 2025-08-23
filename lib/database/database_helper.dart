import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'smart_spender.db');
    return await openDatabase(path, version: 1, onCreate: _createDatabase);
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create Categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
        color TEXT,
        icon TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Create Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        description TEXT,
        category_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // Create Budgets table
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        period TEXT NOT NULL CHECK (period IN ('weekly', 'monthly', 'yearly')),
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute(
      'CREATE INDEX idx_transactions_date ON transactions(date)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_category ON transactions(category_id)',
    );
    await db.execute(
      'CREATE INDEX idx_budgets_category ON budgets(category_id)',
    );

    // No default categories - user will add their own
  }

  Future<void> _insertDefaultCategories(Database db) async {
    // Removed - no default categories
    // User will add their own categories
  }

  // Category CRUD operations
  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    category['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('categories', category);
  }

  Future<List<Map<String, dynamic>>> getCategories({String? type}) async {
    final db = await database;
    if (type != null) {
      return await db.query(
        'categories',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'name ASC',
      );
    }
    return await db.query('categories', orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getCategoryById(int id) async {
    final db = await database;
    final result = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateCategory(int id, Map<String, dynamic> category) async {
    final db = await database;
    return await db.update(
      'categories',
      category,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // Transaction CRUD operations
  Future<int> insertTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    transaction['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('transactions', transaction);
  }

  Future<List<Map<String, dynamic>>> getTransactions({
    String? startDate,
    String? endDate,
    int? categoryId,
    String? type,
    int? limit,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClause += 'date >= ?';
      whereArgs.add(startDate);
    }

    if (endDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'date <= ?';
      whereArgs.add(endDate);
    }

    if (categoryId != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'category_id = ?';
      whereArgs.add(categoryId);
    }

    if (type != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'type = ?';
      whereArgs.add(type);
    }

    return await db.query(
      'transactions',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date DESC, created_at DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionsWithCategories({
    String? startDate,
    String? endDate,
    int? categoryId,
    String? type,
    int? limit,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClause += 't.date >= ?';
      whereArgs.add(startDate);
    }

    if (endDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 't.date <= ?';
      whereArgs.add(endDate);
    }

    if (categoryId != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 't.category_id = ?';
      whereArgs.add(categoryId);
    }

    if (type != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 't.type = ?';
      whereArgs.add(type);
    }

    return await db.rawQuery('''
      SELECT 
        t.*,
        c.name as category_name,
        c.icon as category_icon,
        c.color as category_color
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
      ORDER BY t.date DESC, t.created_at DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''', whereArgs);
  }

  Future<Map<String, dynamic>?> getTransactionById(int id) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateTransaction(
    int id,
    Map<String, dynamic> transaction,
  ) async {
    final db = await database;
    return await db.update(
      'transactions',
      transaction,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Budget CRUD operations
  Future<int> insertBudget(Map<String, dynamic> budget) async {
    final db = await database;
    budget['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('budgets', budget);
  }

  Future<List<Map<String, dynamic>>> getBudgets({
    int? categoryId,
    String? period,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (categoryId != null) {
      whereClause += 'category_id = ?';
      whereArgs.add(categoryId);
    }

    if (period != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'period = ?';
      whereArgs.add(period);
    }

    return await db.query(
      'budgets',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getBudgetsWithCategories({
    String? period,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (period != null) {
      whereClause += 'b.period = ?';
      whereArgs.add(period);
    }

    return await db.rawQuery('''
      SELECT 
        b.*,
        c.name as category_name,
        c.icon as category_icon,
        c.color as category_color
      FROM budgets b
      LEFT JOIN categories c ON b.category_id = c.id
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
      ORDER BY b.created_at DESC
    ''', whereArgs);
  }

  Future<Map<String, dynamic>?> getBudgetById(int id) async {
    final db = await database;
    final result = await db.query(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateBudget(int id, Map<String, dynamic> budget) async {
    final db = await database;
    return await db.update('budgets', budget, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteBudget(int id) async {
    final db = await database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // Analytics and reporting methods
  Future<Map<String, double>> getMonthlyTotals(String month) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT 
        type,
        SUM(amount) as total
      FROM transactions 
      WHERE date LIKE ?
      GROUP BY type
    ''',
      ['$month%'],
    );

    double income = 0.0;
    double expense = 0.0;

    for (var row in result) {
      if (row['type'] == 'income') {
        income = (row['total'] as num).toDouble();
      } else if (row['type'] == 'expense') {
        expense = (row['total'] as num).toDouble();
      }
    }

    return {'income': income, 'expense': expense, 'balance': income - expense};
  }

  Future<List<Map<String, dynamic>>> getCategoryTotals({
    String? startDate,
    String? endDate,
    String? type,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClause += 't.date >= ?';
      whereArgs.add(startDate);
    }

    if (endDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 't.date <= ?';
      whereArgs.add(endDate);
    }

    if (type != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 't.type = ?';
      whereArgs.add(type);
    }

    return await db.rawQuery('''
      SELECT 
        c.id,
        c.name,
        c.icon,
        c.color,
        c.type,
        SUM(t.amount) as total,
        COUNT(t.id) as transaction_count
      FROM categories c
      LEFT JOIN transactions t ON c.id = t.category_id
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
      GROUP BY c.id, c.name, c.icon, c.color, c.type
      HAVING total > 0
      ORDER BY total DESC
    ''', whereArgs);
  }

  // Clear all data methods
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('budgets');
    await db.delete('categories');
  }

  Future<void> clearAllCategories() async {
    final db = await database;
    await db.delete(
      'transactions',
    ); // Delete transactions first due to foreign key
    await db.delete('categories');
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
