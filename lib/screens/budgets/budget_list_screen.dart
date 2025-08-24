import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_budget_screen.dart';
import '../../database/database_helper.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../widgets/logo_widget.dart';

class BudgetListScreen extends StatefulWidget {
  const BudgetListScreen({super.key});

  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> {
  bool _showIncomeCategories = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Category> _incomeCategories = [];
  List<Category> _expenseCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Map<int, double> _categoryAmounts = {};

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load categories from database
      final allCategories = await _dbHelper.getCategories();

      // Separate income and expense categories
      _incomeCategories = allCategories
          .where((cat) => cat.type == 'income')
          .toList();
      _expenseCategories = allCategories
          .where((cat) => cat.type == 'expense')
          .toList();

      // Calculate amounts for each category
      _categoryAmounts.clear();
      for (var category in [..._incomeCategories, ..._expenseCategories]) {
        final transactions = await _dbHelper.getTransactions(
          categoryId: category.id!,
        );
        double totalAmount = 0.0;
        for (var transaction in transactions) {
          totalAmount += transaction.amount;
        }
        _categoryAmounts[category.id!] = totalAmount;
      }
    } catch (e) {
      print('Error loading categories: $e');
      // If no categories exist, we'll show empty lists
      _incomeCategories = [];
      _expenseCategories = [];
      _categoryAmounts.clear();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _clearAllData() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will delete all categories and transactions. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _dbHelper.clearAllCategories();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared successfully')),
                );
                _loadCategories();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error clearing data: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  double get _totalIncome {
    return _incomeCategories.fold(
      0.0,
      (sum, cat) => sum + (_categoryAmounts[cat.id] ?? 0.0),
    );
  }

  double get _totalExpenses {
    return _expenseCategories.fold(
      0.0,
      (sum, cat) => sum + (_categoryAmounts[cat.id] ?? 0.0),
    );
  }

  double get _moneyLeftOver {
    return _totalIncome - _totalExpenses;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const LogoWidget(width: 60, height: 60),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearAllData,
            tooltip: 'Clear All Data',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCategories,
          ),
        ],
      ),
      body: Column(
        children: [
          // Total Overview Card
          Container(
            margin: const EdgeInsets.all(16),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Monthly Overview',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTotalCard(
                            'Total Income',
                            'R${_totalIncome.toStringAsFixed(2)}',
                            Colors.green,
                            Icons.trending_up,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTotalCard(
                            'Total Expenses',
                            'R${_totalExpenses.toStringAsFixed(2)}',
                            Colors.red,
                            Icons.trending_down,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _moneyLeftOver >= 0
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _moneyLeftOver >= 0
                              ? Colors.blue.withOpacity(0.3)
                              : Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _moneyLeftOver >= 0
                                ? Icons.account_balance_wallet
                                : Icons.warning,
                            color: _moneyLeftOver >= 0
                                ? Colors.blue
                                : Colors.red,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              Text(
                                _moneyLeftOver >= 0
                                    ? 'Money Left Over'
                                    : 'Over Budget',
                                style: TextStyle(
                                  color: _moneyLeftOver >= 0
                                      ? Colors.blue[700]
                                      : Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'R${_moneyLeftOver.abs().toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _moneyLeftOver >= 0
                                      ? Colors.blue[700]
                                      : Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Category Type Toggle
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    'Income Categories (${_incomeCategories.length})',
                    _showIncomeCategories,
                    Colors.green,
                    () => setState(() => _showIncomeCategories = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton(
                    'Expense Categories (${_expenseCategories.length})',
                    !_showIncomeCategories,
                    Colors.red,
                    () => setState(() => _showIncomeCategories = false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Categories List
          Expanded(child: _buildCategoriesList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddBudgetScreen(isIncomeCategory: _showIncomeCategories),
            ),
          );

          // Reload categories if something was added
          if (result == true) {
            _loadCategories();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_showIncomeCategories ? 'Add Income' : 'Add Expense'),
        backgroundColor: _showIncomeCategories ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildTotalCard(
    String title,
    String amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    String title,
    bool isSelected,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? color : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesList() {
    final categories = _showIncomeCategories
        ? _incomeCategories
        : _expenseCategories;

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showIncomeCategories ? Icons.trending_up : Icons.trending_down,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _showIncomeCategories
                  ? 'No income categories'
                  : 'No expense categories',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              _showIncomeCategories
                  ? 'Add your income sources to get started'
                  : 'Add your expense categories to track spending',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final amount = _categoryAmounts[category.id] ?? 0.0;
        final hasAmount = amount > 0;

        // Get icon and color from database or use defaults
        IconData iconData = Icons.category;
        Color iconColor = _showIncomeCategories ? Colors.green : Colors.red;

        if (category.icon != null) {
          // Map icon names to IconData (simplified version)
          final iconMap = {
            'work': Icons.work,
            'computer': Icons.computer,
            'restaurant': Icons.restaurant,
            'directions_car': Icons.directions_car,
            'shopping_cart': Icons.shopping_cart,
            'security': Icons.security,
            'flash_on': Icons.flash_on,
            'phone': Icons.phone,
            'local_hospital': Icons.local_hospital,
            'movie': Icons.movie,
            'school': Icons.school,
            'checkroom': Icons.checkroom,
            'home_repair_service': Icons.home_repair_service,
            'subscriptions': Icons.subscriptions,
            'spa': Icons.spa,
            'flight': Icons.flight,
            'savings': Icons.savings,
            'more_horiz': Icons.more_horiz,
          };
          iconData = iconMap[category.icon!] ?? Icons.category;
        }

        if (category.color != null) {
          // Parse color from hex string
          try {
            final colorValue = int.parse(category.color!, radix: 16);
            iconColor = Color(colorValue);
          } catch (e) {
            // Use default color if parsing fails
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.1),
              child: Icon(iconData, color: iconColor),
            ),
            title: Text(
              category.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _showIncomeCategories ? 'Income source' : 'Expense category',
                ),
                if (hasAmount) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last updated: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasAmount) ...[
                  Text(
                    'R${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _showIncomeCategories ? Colors.green : Colors.red,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Not set',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey[400],
                ),
              ],
            ),
            onTap: () {
              _editCategoryAmount(context, category);
            },
          ),
        );
      },
    );
  }

  void _editCategoryAmount(
    BuildContext context,
    Category category,
  ) {
    final TextEditingController amountController = TextEditingController();
    final currentAmount = _categoryAmounts[category.id] ?? 0.0;
    if (currentAmount > 0) {
      amountController.text = currentAmount.toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  (_showIncomeCategories ? Colors.green : Colors.red)
                      .withOpacity(0.1),
              child: Icon(
                Icons.category, // Simplified for now
                color: _showIncomeCategories ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _showIncomeCategories
                  ? 'Enter your income amount:'
                  : 'Enter your expense amount:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                prefixText: 'R ',
                hintText: '0.00',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (currentAmount > 0)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, category);
              },
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount >= 0) {
                Navigator.pop(context);

                try {
                  // Save transaction to database
                  final transaction = Transaction(
                    amount: amount,
                    description: '${_showIncomeCategories ? 'Income' : 'Expense'} update',
                    categoryId: category.id!,
                    date: DateTime.now(),
                    type: _showIncomeCategories ? 'income' : 'expense',
                    createdAt: DateTime.now(),
                  );
                  await _dbHelper.insertTransaction(transaction);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${category.name} updated to R${amount.toStringAsFixed(2)}',
                      ),
                    ),
                  );

                  // Reload categories to show updated amounts
                  _loadCategories();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error saving: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Category category,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Amount'),
        content: Text('Remove all transactions from "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                // Delete all transactions for this category
                final transactions = await _dbHelper.getTransactions(
                  categoryId: category.id!,
                );
                for (var transaction in transactions) {
                  await _dbHelper.deleteTransaction(transaction.id!);
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'All amounts removed from ${category.name}',
                    ),
                  ),
                );

                // Reload categories
                _loadCategories();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error removing: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
