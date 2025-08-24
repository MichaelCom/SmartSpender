import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/transaction.dart' as model;
import 'add_transaction_screen.dart';
import '../../widgets/logo_widget.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  String _selectedFilter = 'all'; // 'all', 'income', 'expense'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load transactions when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).loadTransactions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  IconData _getIconData(String iconName) {
    const Map<String, IconData> iconMap = {
      'category': Icons.category,
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'shopping_bag': Icons.shopping_bag,
      'movie': Icons.movie,
      'receipt': Icons.receipt,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
      'work': Icons.work,
      'computer': Icons.computer,
      'trending_up': Icons.trending_up,
      'card_giftcard': Icons.card_giftcard,
      'attach_money': Icons.attach_money,
      'home': Icons.home,
      'fitness_center': Icons.fitness_center,
      'local_gas_station': Icons.local_gas_station,
      'phone': Icons.phone,
      'wifi': Icons.wifi,
      'pets': Icons.pets,
      'child_care': Icons.child_care,
    };
    return iconMap[iconName] ?? Icons.category;
  }

  List<model.Transaction> _getFilteredTransactions(
    List<model.Transaction> transactions,
  ) {
    var filtered = transactions;

    // Filter by type
    switch (_selectedFilter) {
      case 'income':
        filtered = filtered.where((t) => t.type == 'income').toList();
        break;
      case 'expense':
        filtered = filtered.where((t) => t.type == 'expense').toList();
        break;
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((transaction) {
        return transaction.description?.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ??
            false;
      }).toList();
    }

    return filtered;
  }

  Future<void> _deleteTransaction(model.Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Are you sure you want to delete this transaction?'),
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
      final transactionProvider = Provider.of<TransactionProvider>(
        context,
        listen: false,
      );
      final success = await transactionProvider.deleteTransaction(
        transaction.id!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Transaction deleted successfully'
                  : transactionProvider.error ?? 'Failed to delete transaction',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const LogoWidget(width: 100, height: 100),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All Transactions'),
              ),
              const PopupMenuItem(value: 'income', child: Text('Income Only')),
              const PopupMenuItem(
                value: 'expense',
                child: Text('Expenses Only'),
              ),
            ],
            child: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Summary Cards
          Consumer<TransactionProvider>(
            builder: (context, transactionProvider, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Text(
                                'Income',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'R${NumberFormat('#,##0.00').format(transactionProvider.totalIncome)}',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Card(
                        color: Colors.red[50],
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Text(
                                'Expenses',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'R${NumberFormat('#,##0.00').format(transactionProvider.totalExpenses)}',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Card(
                        color: transactionProvider.balance >= 0
                            ? Colors.blue[50]
                            : Colors.orange[50],
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Text(
                                'Balance',
                                style: TextStyle(
                                  color: transactionProvider.balance >= 0
                                      ? Colors.blue[700]
                                      : Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'R${NumberFormat('#,##0.00').format(transactionProvider.balance)}',
                                  style: TextStyle(
                                    color: transactionProvider.balance >= 0
                                        ? Colors.blue[700]
                                        : Colors.orange[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Transactions List
          Expanded(
            child: Consumer2<TransactionProvider, CategoryProvider>(
              builder: (context, transactionProvider, categoryProvider, child) {
                if (transactionProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (transactionProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${transactionProvider.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () =>
                              transactionProvider.loadTransactions(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final filteredTransactions = _getFilteredTransactions(
                  transactionProvider.transactions,
                );

                if (filteredTransactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No transactions found for "$_searchQuery"'
                              : _selectedFilter == 'all'
                              ? 'No transactions found'
                              : 'No ${_selectedFilter} transactions found',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap the + button to add a transaction',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => transactionProvider.loadTransactions(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = filteredTransactions[index];
                      final category = categoryProvider.getCategoryById(
                        transaction.categoryId,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: category != null
                                  ? _hexToColor(category.color ?? '#FF6B6B')
                                  : Colors.grey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              category != null
                                  ? _getIconData(category.icon ?? 'category')
                                  : Icons.category,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            category?.name ?? 'Unknown Category',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (transaction.description != null)
                                Text(
                                  transaction.description!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              Text(
                                DateFormat('MMM d, y').format(transaction.date),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${transaction.type == 'income' ? '+' : '-'}R${NumberFormat('#,##0.00').format(transaction.amount)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: transaction.type == 'income'
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                  Text(
                                    transaction.type.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: transaction.type == 'income'
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'edit':
                                      final result = await Navigator.of(context)
                                          .push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  AddTransactionScreen(
                                                    transaction: transaction,
                                                  ),
                                            ),
                                          );
                                      if (result == true) {
                                        transactionProvider.loadTransactions();
                                      }
                                      break;
                                    case 'delete':
                                      await _deleteTransaction(transaction);
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
                                        Icon(
                                          Icons.delete,
                                          size: 20,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => AddTransactionScreen(
                                  transaction: transaction,
                                ),
                              ),
                            );
                            if (result == true) {
                              // Transaction was updated, refresh the list
                              transactionProvider.loadTransactions();
                            }
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );
          if (result == true) {
            // Transaction was added, refresh the list
            Provider.of<TransactionProvider>(
              context,
              listen: false,
            ).loadTransactions();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
