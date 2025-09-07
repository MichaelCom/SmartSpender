// import 'dart:async';
// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
// import '../models/category.dart' as model;
// import '../models/transaction.dart' as model;
// import '../models/budget.dart' as model;

// class DatabaseHelper {
//   static final DatabaseHelper _instance = DatabaseHelper._internal();
//   static Database? _database;

//   DatabaseHelper._internal();

//   factory DatabaseHelper() => _instance;

//   Future<Database> get database async {
//     _database ??= await _initDatabase();
//     return _database!;
//   }

//   Future<Database> _initDatabase() async {
//     String path = join(await getDatabasesPath(), 'smart_spender.db');
//     return await openDatabase(path, version: 1, onCreate: _createDatabase);
//   }

//   Future<void> _createDatabase(Database db, int version) async {
//     // Create Categories table
//     await db.execute('''
//       CREATE TABLE categories (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         name TEXT NOT NULL,
//         type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
//         color TEXT,
//         icon TEXT,
//         created_at TEXT NOT NULL
//       )
//     ''');

//     // Create Transactions table
//     await db.execute('''
//       CREATE TABLE transactions (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         amount REAL NOT NULL,
//         description TEXT,
//         category_id INTEGER NOT NULL,
//         date TEXT NOT NULL,
//         type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
//         created_at TEXT NOT NULL,
//         FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
//       )
//     ''');

//     // Create Budgets table
//     await db.execute('''
//       CREATE TABLE budgets (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         category_id INTEGER NOT NULL,
//         amount REAL NOT NULL,
//         period TEXT NOT NULL CHECK (period IN ('weekly', 'monthly', 'yearly')),
//         start_date TEXT NOT NULL,
//         end_date TEXT NOT NULL,
//         created_at TEXT NOT NULL,
//         FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
//       )
//     ''');

//     // Create indexes for better performance
//     await db.execute(
//       'CREATE INDEX idx_transactions_date ON transactions(date)',
//     );
//     await db.execute(
//       'CREATE INDEX idx_transactions_category ON transactions(category_id)',
//     );
//     await db.execute(
//       'CREATE INDEX idx_budgets_category ON budgets(category_id)',
//     );
//   }

//   // Category CRUD operations
//   Future<int> insertCategory(model.Category category) async {
//     final db = await database;
//     final categoryMap = {
//       'name': category.name,
//       'type': category.type,
//       'color': category.color,
//       'icon': category.icon,
//       'created_at': category.createdAt.toIso8601String(),
//     };
//     return await db.insert('categories', categoryMap);
//   }

//   Future<List<model.Category>> getCategories({String? type}) async {
//     final db = await database;
//     List<Map<String, dynamic>> maps;
    
//     if (type != null) {
//       maps = await db.query(
//         'categories',
//         where: 'type = ?',
//         whereArgs: [type],
//         orderBy: 'name ASC',
//       );
//     } else {
//       maps = await db.query('categories', orderBy: 'name ASC');
//     }

//     return maps.map((map) => model.Category.fromMap(map)).toList();
//   }

//   Future<model.Category?> getCategoryById(int id) async {
//     final db = await database;
//     final result = await db.query(
//       'categories',
//       where: 'id = ?',
//       whereArgs: [id],
//       limit: 1,
//     );
//     return result.isNotEmpty ? model.Category.fromMap(result.first) : null;
//   }

//   Future<bool> updateCategory(model.Category category) async {
//     final db = await database;
//     final categoryMap = {
//       'name': category.name,
//       'type': category.type,
//       'color': category.color,
//       'icon': category.icon,
//     };
//     final result = await db.update(
//       'categories',
//       categoryMap,
//       where: 'id = ?',
//       whereArgs: [category.id],
//     );
//     return result > 0;
//   }

//   Future<bool> deleteCategory(int id) async {
//     final db = await database;
//     final result = await db.delete('categories', where: 'id = ?', whereArgs: [id]);
//     return result > 0;
//   }

//   // Transaction CRUD operations
//   Future<int> insertTransaction(model.Transaction transaction) async {
//     final db = await database;
//     final transactionMap = {
//       'amount': transaction.amount,
//       'description': transaction.description,
//       'category_id': transaction.categoryId,
//       'date': transaction.date.toIso8601String(),
//       'type': transaction.type,
//       'created_at': transaction.createdAt.toIso8601String(),
//     };
//     return await db.insert('transactions', transactionMap);
//   }

//   Future<List<model.Transaction>> getTransactions({
//     String? startDate,
//     String? endDate,
//     int? categoryId,
//     String? type,
//     int? limit,
//   }) async {
//     final db = await database;
//     String whereClause = '';
//     List<dynamic> whereArgs = [];

//     if (startDate != null) {
//       whereClause += 'date >= ?';
//       whereArgs.add(startDate);
//     }

//     if (endDate != null) {
//       if (whereClause.isNotEmpty) whereClause += ' AND ';
//       whereClause += 'date <= ?';
//       whereArgs.add(endDate);
//     }

//     if (categoryId != null) {
//       if (whereClause.isNotEmpty) whereClause += ' AND ';
//       whereClause += 'category_id = ?';
//       whereArgs.add(categoryId);
//     }

//     if (type != null) {
//       if (whereClause.isNotEmpty) whereClause += ' AND ';
//       whereClause += 'type = ?';
//       whereArgs.add(type);
//     }

//     final maps = await db.query(
//       'transactions',
//       where: whereClause.isNotEmpty ? whereClause : null,
//       whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
//       orderBy: 'date DESC, created_at DESC',
//       limit: limit,
//     );

//     return maps.map((map) => model.Transaction.fromMap(map)).toList();
//   }

//   Future<model.Transaction?> getTransactionById(int id) async {
//     final db = await database;
//     final result = await db.query(
//       'transactions',
//       where: 'id = ?',
//       whereArgs: [id],
//       limit: 1,
//     );
//     return result.isNotEmpty ? model.Transaction.fromMap(result.first) : null;
//   }

//   Future<bool> updateTransaction(model.Transaction transaction) async {
//     final db = await database;
//     final transactionMap = {
//       'amount': transaction.amount,
//       'description': transaction.description,
//       'category_id': transaction.categoryId,
//       'date': transaction.date.toIso8601String(),
//       'type': transaction.type,
//     };
//     final result = await db.update(
//       'transactions',
//       transactionMap,
//       where: 'id = ?',
//       whereArgs: [transaction.id],
//     );
//     return result > 0;
//   }

//   Future<bool> deleteTransaction(int id) async {
//     final db = await database;
//     final result = await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
//     return result > 0;
//   }

//   // Budget CRUD operations
//   Future<int> insertBudget(model.Budget budget) async {
//     final db = await database;
//     final budgetMap = {
//       'category_id': budget.categoryId,
//       'amount': budget.amount,
//       'period': budget.period,
//       'start_date': budget.startDate.toIso8601String(),
//       'end_date': budget.endDate.toIso8601String(),
//       'created_at': budget.createdAt.toIso8601String(),
//     };
//     return await db.insert('budgets', budgetMap);
//   }

//   Future<List<model.Budget>> getBudgets({
//     int? categoryId,
//     String? period,
//   }) async {
//     final db = await database;
//     String whereClause = '';
//     List<dynamic> whereArgs = [];

//     if (categoryId != null) {
//       whereClause += 'category_id = ?';
//       whereArgs.add(categoryId);
//     }

//     if (period != null) {
//       if (whereClause.isNotEmpty) whereClause += ' AND ';
//       whereClause += 'period = ?';
//       whereArgs.add(period);
//     }

//     final maps = await db.query(
//       'budgets',
//       where: whereClause.isNotEmpty ? whereClause : null,
//       whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
//       orderBy: 'created_at DESC',
//     );

//     return maps.map((map) => model.Budget.fromMap(map)).toList();
//   }

//   Future<model.Budget?> getBudgetById(int id) async {
//     final db = await database;
//     final result = await db.query(
//       'budgets',
//       where: 'id = ?',
//       whereArgs: [id],
//       limit: 1,
//     );
//     return result.isNotEmpty ? model.Budget.fromMap(result.first) : null;
//   }

//   Future<bool> updateBudget(model.Budget budget) async {
//     final db = await database;
//     final budgetMap = {
//       'category_id': budget.categoryId,
//       'amount': budget.amount,
//       'period': budget.period,
//       'start_date': budget.startDate.toIso8601String(),
//       'end_date': budget.endDate.toIso8601String(),
//     };
//     final result = await db.update('budgets', budgetMap, where: 'id = ?', whereArgs: [budget.id]);
//     return result > 0;
//   }

//   Future<bool> deleteBudget(int id) async {
//     final db = await database;
//     final result = await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
//     return result > 0;
//   }

//   // Analytics and reporting methods
//   Future<Map<String, double>> getMonthlyTotals(String month) async {
//     final db = await database;
//     final result = await db.rawQuery(
//       '''
//       SELECT 
//         type,
//         SUM(amount) as total
//       FROM transactions 
//       WHERE date LIKE ?
//       GROUP BY type
//     ''',
//       ['$month%'],
//     );

//     double income = 0.0;
//     double expense = 0.0;

//     for (var row in result) {
//       if (row['type'] == 'income') {
//         income = (row['total'] as num).toDouble();
//       } else if (row['type'] == 'expense') {
//         expense = (row['total'] as num).toDouble();
//       }
//     }

//     return {'income': income, 'expense': expense, 'balance': income - expense};
//   }

//   Future<List<Map<String, dynamic>>> getCategoryTotals({
//     String? startDate,
//     String? endDate,
//     String? type,
//   }) async {
//     final db = await database;
//     String whereClause = '';
//     List<dynamic> whereArgs = [];

//     if (startDate != null) {
//       whereClause += 't.date >= ?';
//       whereArgs.add(startDate);
//     }

//     if (endDate != null) {
//       if (whereClause.isNotEmpty) whereClause += ' AND ';
//       whereClause += 't.date <= ?';
//       whereArgs.add(endDate);
//     }

//     if (type != null) {
//       if (whereClause.isNotEmpty) whereClause += ' AND ';
//       whereClause += 't.type = ?';
//       whereArgs.add(type);
//     }

//     return await db.rawQuery('''
//       SELECT 
//         c.id,
//         c.name,
//         c.icon,
//         c.color,
//         c.type,
//         SUM(t.amount) as total,
//         COUNT(t.id) as transaction_count
//       FROM categories c
//       LEFT JOIN transactions t ON c.id = t.category_id
//       ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
//       GROUP BY c.id, c.name, c.icon, c.color, c.type
//       HAVING total > 0
//       ORDER BY total DESC
//     ''', whereArgs);
//   }

//   // Clear all data methods
//   Future<void> clearAllData() async {
//     final db = await database;
//     await db.delete('transactions');
//     await db.delete('budgets');
//     await db.delete('categories');
//   }

//   Future<void> clearAllCategories() async {
//     final db = await database;
//     await db.delete('transactions'); // Delete transactions first due to foreign key
//     await db.delete('categories');
//   }

//   // Close database
//   Future<void> close() async {
//     final db = await database;
//     await db.close();
//   }
// }
