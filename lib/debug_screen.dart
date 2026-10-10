import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/category.dart';
import 'models/transaction.dart';
import 'models/budget.dart';
import 'repositories/repositories.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  List<Category> _categories = [];
  List<Transaction> _transactions = [];
  List<Budget> _budgets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repositories = Provider.of<AppRepositories>(context, listen: false);
    final categories = await repositories.categories.getAll();
    final transactions =
        await repositories.transactions.getAllWithCategoryInfo();
    final budgets = await repositories.budgets.getAllWithCategoryInfo();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _transactions = transactions;
      _budgets = budgets;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Contents'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategoriesSection(),
                  const SizedBox(height: 24),
                  _buildTransactionsSection(),
                  const SizedBox(height: 24),
                  _buildBudgetsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoriesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Categories (${_categories.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_categories.isEmpty)
              const Text('No categories found')
            else
              ..._categories.map((category) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Id: ${category.id} | ${category.name} (${category.type}) | Icon: ${category.icon} | Color: ${category.color}',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transactions (${_transactions.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_transactions.isEmpty)
              const Text('No transactions found')
            else
              ..._transactions.map((transaction) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Id: ${transaction.id} | R${transaction.amount} | ${transaction.type} | Cat: ${transaction.categoryId ?? 'none'} | ${transaction.description ?? 'No desc'} | ${transaction.date.toString().split(' ')[0]}',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budgets (${_budgets.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_budgets.isEmpty)
              const Text('No budgets found')
            else
              ..._budgets.map((budget) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Id: ${budget.id} | R${budget.amount} | Cat: ${budget.categoryId} | ${budget.period} | Active: ${budget.isActive}',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
