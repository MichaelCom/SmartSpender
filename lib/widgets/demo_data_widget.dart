import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../test_database.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_provider.dart';

class DemoDataWidget extends StatefulWidget {
  const DemoDataWidget({Key? key}) : super(key: key);

  @override
  State<DemoDataWidget> createState() => _DemoDataWidgetState();
}

class _DemoDataWidgetState extends State<DemoDataWidget> {
  bool _isLoading = false;

  Future<void> _seedDemoData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Seed the demo data
      await seedDemoDataAndTest();

      // Refresh all providers to show the new data
      if (mounted) {
        await Provider.of<CategoryProvider>(
          context,
          listen: false,
        ).loadCategories();
        await Provider.of<TransactionProvider>(
          context,
          listen: false,
        ).loadTransactions();
        await Provider.of<BudgetProvider>(context, listen: false).loadBudgets();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Demo data created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error creating demo data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.data_usage, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Demo Data',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Populate your app with realistic demo data for testing and demonstration purposes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'This will create:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• 18 categories with icons and colors'),
                Text('• 6 months of transaction history'),
                Text('• Monthly budgets for major categories'),
                Text('• Realistic amounts and descriptions'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _seedDemoData,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _isLoading ? 'Creating Demo Data...' : 'Create Demo Data',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '⚠️ This will clear all existing data!',
              style: TextStyle(
                color: Colors.orange[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
