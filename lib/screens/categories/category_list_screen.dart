import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/category.dart' as model;
import '../../utils/currency.dart';
import '../../widgets/redesign/redesign.dart';
import 'add_category_screen.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  String _selectedFilter = 'all'; // 'all', 'income', 'expense'

  @override
  void initState() {
    super.initState();
    // Load categories when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryProvider>(context, listen: false).loadCategories();
      Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).loadTransactions();
    });
  }

  List<model.Category> _getFilteredCategories(List<model.Category> categories) {
    switch (_selectedFilter) {
      case 'income':
        return categories.where((cat) => cat.type == 'income').toList();
      case 'expense':
        return categories.where((cat) => cat.type == 'expense').toList();
      default:
        return categories;
    }
  }

  Future<void> _deleteCategory(model.Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      final success = await categoryProvider.deleteCategory(category.key!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Category deleted successfully'
                  : categoryProvider.error ?? 'Failed to delete category',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = context.watch<SettingsController>().currencySymbol;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: colorScheme.surface,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            icon: const Icon(Icons.filter_list),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Categories')),
              const PopupMenuItem(
                value: 'income',
                child: Text('Income Categories'),
              ),
              const PopupMenuItem(
                value: 'expense',
                child: Text('Expense Categories'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer2<CategoryProvider, TransactionProvider>(
        builder: (context, categoryProvider, transactionProvider, child) {
          if (categoryProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (categoryProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${categoryProvider.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => categoryProvider.loadCategories(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final filteredCategories = _getFilteredCategories(
            categoryProvider.categories,
          );

          if (filteredCategories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFilter == 'all'
                        ? 'No categories found'
                        : 'No $_selectedFilter categories found',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to add a category',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => categoryProvider.loadCategories(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionHeader('${filteredCategories.length} categories'),
                Card(
                  margin: EdgeInsets.zero,
                  color: colorScheme.surfaceContainer,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (var i = 0;
                            i < filteredCategories.length;
                            i++) ...[
                          if (i > 0) FinanceListRow.divider(context),
                          _buildCategoryRow(
                            context,
                            categoryProvider,
                            transactionProvider,
                            filteredCategories[i],
                            symbol,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddCategoryScreen()),
          );
          if (result == true && context.mounted) {
            // Category was added, refresh the list
            Provider.of<CategoryProvider>(
              context,
              listen: false,
            ).loadCategories();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryRow(
    BuildContext context,
    CategoryProvider categoryProvider,
    TransactionProvider transactionProvider,
    model.Category category,
    String symbol,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryId = category.id;
    final txns = categoryId == null
        ? const []
        : transactionProvider.getTransactionsByCategory(categoryId);
    final count = txns.length;
    final total = txns.fold<double>(0.0, (sum, t) => sum + t.amount);

    return FinanceListRow(
      title: category.name,
      subtitle: '$count ${count == 1 ? 'txn' : 'txns'}',
      colorHex: category.color,
      iconName: category.icon,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            CurrencyFormatter.format(symbol, total),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'edit':
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          AddCategoryScreen(category: category),
                    ),
                  );
                  if (result == true) {
                    categoryProvider.loadCategories();
                  }
                  break;
                case 'delete':
                  await _deleteCategory(category);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
