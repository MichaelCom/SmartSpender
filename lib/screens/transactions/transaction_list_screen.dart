import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/transaction.dart' as model;
import '../../models/category.dart' as cat_model;
import '../../utils/currency.dart';
import '../../services/insights/anomaly_engine.dart';
import '../../theme/finance_colors.dart';
import '../../widgets/redesign/redesign.dart';
import 'add_transaction_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  // Combined filter token: 'all', 'income', 'expense', or 'cat:<id>'.
  String _selectedFilter = 'all';
  bool _searchVisible = false;
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
      Provider.of<CategoryProvider>(context, listen: false).loadCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<model.Transaction> _getFilteredTransactions(
    List<model.Transaction> transactions,
  ) {
    var filtered = transactions;

    // Filter by type / category.
    if (_selectedFilter == 'income') {
      filtered = filtered.where((t) => t.type == 'income').toList();
    } else if (_selectedFilter == 'expense') {
      filtered = filtered.where((t) => t.type == 'expense').toList();
    } else if (_selectedFilter.startsWith('cat:')) {
      final id = int.tryParse(_selectedFilter.substring(4));
      filtered = filtered.where((t) => t.categoryId == id).toList();
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

  /// Buckets a transaction date into TODAY / YESTERDAY / EARLIER.
  String _dayGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'TODAY';
    if (d == today.subtract(const Duration(days: 1))) return 'YESTERDAY';
    return 'EARLIER';
  }

  /// Shows the reason an expense was flagged as unusually large.
  void _showAnomalyDetail(
    model.Transaction transaction,
    SpendingAnomaly anomaly,
    String symbol,
    String categoryName,
  ) {
    final amount = CurrencyFormatter.format(symbol, transaction.amount);
    final mean = CurrencyFormatter.format(symbol, anomaly.categoryMean);
    final times = anomaly.timesTypical;
    final timesLabel = times >= 10
        ? times.toStringAsFixed(0)
        : times.toStringAsFixed(1);

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).financeColors.warning,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Unusually large',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'This $amount is about ${timesLabel}x your typical '
              '$categoryName spend of $mean.',
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTransaction(model.Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction?',
        ),
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

  List<FilterChipOption> _buildChipOptions(List<cat_model.Category> categories) {
    return [
      const FilterChipOption(value: 'all', label: 'All'),
      const FilterChipOption(value: 'income', label: 'Income'),
      const FilterChipOption(value: 'expense', label: 'Expenses'),
      for (final c in categories)
        if (c.id != null)
          FilterChipOption(value: 'cat:${c.id}', label: c.name),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final finance = Theme.of(context).financeColors;
    final symbol = context.watch<SettingsController>().currencySymbol;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
            tooltip: 'Search',
            onPressed: () {
              setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
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
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar (toggled from the AppBar)
          if (_searchVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
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

          // Filter chips (All / Income / Expenses + category chips)
          Consumer<CategoryProvider>(
            builder: (context, categoryProvider, child) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: FilterChipScroller(
                  options: _buildChipOptions(categoryProvider.categories),
                  selected: _selectedFilter,
                  onSelected: (value) {
                    setState(() {
                      _selectedFilter = value;
                    });
                  },
                ),
              );
            },
          ),

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
                          color: colorScheme.error,
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

                // A2: compute anomalies ONCE per build over the displayed
                // expenses, judged against the full history. Keyed by tx id
                // for O(1) lookup in the item builder.
                final anomaliesById = <int, SpendingAnomaly>{};
                final anomalies = AnomalyEngine.detect(
                  transactions: filteredTransactions
                      .where((t) => t.type == 'expense')
                      .toList(),
                  history: transactionProvider.transactions,
                );
                for (final a in anomalies) {
                  final id = a.transaction.id;
                  if (id != null) anomaliesById[id] = a;
                }

                if (filteredTransactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No transactions found for "$_searchQuery"'
                              : 'No transactions found',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the + button to add a transaction',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                // Sort newest-first, then group by day bucket preserving order.
                final sorted = [...filteredTransactions]
                  ..sort((a, b) => b.date.compareTo(a.date));

                const groupOrder = ['TODAY', 'YESTERDAY', 'EARLIER'];
                final grouped = <String, List<model.Transaction>>{};
                for (final t in sorted) {
                  grouped.putIfAbsent(_dayGroup(t.date), () => []).add(t);
                }

                final slivers = <Widget>[];
                for (final group in groupOrder) {
                  final items = grouped[group];
                  if (items == null || items.isEmpty) continue;
                  slivers.add(
                    SectionHeader(group, padding: const EdgeInsets.fromLTRB(2, 10, 2, 6)),
                  );
                  slivers.add(
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: colorScheme.surfaceContainer,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              if (i > 0) FinanceListRow.divider(context),
                              _buildTransactionRow(
                                context,
                                transactionProvider,
                                categoryProvider,
                                items[i],
                                anomaliesById[items[i].id],
                                symbol,
                                finance,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => transactionProvider.loadTransactions(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: slivers,
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
          if (result == true && context.mounted) {
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

  Widget _buildTransactionRow(
    BuildContext context,
    TransactionProvider transactionProvider,
    CategoryProvider categoryProvider,
    model.Transaction transaction,
    SpendingAnomaly? anomaly,
    String symbol,
    FinanceColors finance,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isIncome = transaction.type == 'income';
    final amountColor = isIncome ? finance.income : finance.expense;
    final categoryId = transaction.categoryId;
    final category = categoryId == null
        ? null
        : categoryProvider.getCategoryById(categoryId);
    final categoryName = category?.name ?? 'Uncategorised';

    // Subtitle: "Category · date" plus the optional description/anomaly flag.
    final metaParts = <String>[
      categoryName,
      DateFormat('MMM d, y').format(transaction.date),
    ];
    final subtitleChildren = <Widget>[
      Text(
        metaParts.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      if (transaction.description != null &&
          transaction.description!.isNotEmpty)
        Text(
          transaction.description!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      // A2: subtle inline anomaly flag.
      if (anomaly != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: GestureDetector(
            onTap: () => _showAnomalyDetail(
              transaction,
              anomaly,
              symbol,
              categoryName,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: finance.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  'Unusually large',
                  style: TextStyle(fontSize: 12, color: finance.warning),
                ),
              ],
            ),
          ),
        ),
    ];

    return FinanceListRow(
      title: categoryName,
      colorHex: category?.color,
      iconName: category?.icon,
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: subtitleChildren,
      ),
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                AddTransactionScreen(transaction: transaction),
          ),
        );
        if (result == true) {
          transactionProvider.loadTransactions();
        }
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            CurrencyFormatter.formatSigned(
              symbol,
              transaction.amount,
              isIncome: isIncome,
            ),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: amountColor,
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
                          AddTransactionScreen(transaction: transaction),
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
