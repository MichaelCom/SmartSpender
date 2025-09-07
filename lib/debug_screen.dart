import 'package:flutter/material.dart';
import 'database/hive_helper.dart';
import 'models/category.dart';
import 'models/transaction.dart';
import 'models/budget.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hive Database Contents'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
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
    final categories = HiveHelper.getAllCategories();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Categories (${categories.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (categories.isEmpty)
              const Text('No categories found')
            else
              ...categories.map((category) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Key: ${category.key} | ${category.name} (${category.type}) | Icon: ${category.icon} | Color: ${category.color}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsSection() {
    final transactions = HiveHelper.getAllTransactions();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transactions (${transactions.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (transactions.isEmpty)
              const Text('No transactions found')
            else
              ...transactions.map((transaction) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Key: ${transaction.key} | R${transaction.amount} | ${transaction.type} | Cat: ${transaction.categoryKey} | ${transaction.description ?? 'No desc'} | ${transaction.date.toString().split(' ')[0]}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetsSection() {
    final budgets = HiveHelper.getAllBudgets();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budgets (${budgets.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (budgets.isEmpty)
              const Text('No budgets found')
            else
              ...budgets.map((budget) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Key: ${budget.key} | R${budget.amount} | Cat: ${budget.categoryKey} | ${budget.period} | Active: ${budget.isActive}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              )),
          ],
        ),
      ),
    );
  }
}
