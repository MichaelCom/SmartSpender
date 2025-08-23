import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/database_helper.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';

class AddBudgetScreen extends StatefulWidget {
  final Map<String, dynamic>? budget;
  final bool isIncomeCategory;
  
  const AddBudgetScreen({
    super.key, 
    this.budget,
    this.isIncomeCategory = false,
  });

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    final budget = widget.budget!;
    _amountController.text = (budget['amount'] as double).toStringAsFixed(2);
    _categoryController.text = budget['category'] as String;
    _descriptionController.text = budget['description'] ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.budget != null;
    final title = widget.isIncomeCategory ? 'Income' : 'Expense';
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${isEditing ? 'Edit' : 'Add'} $title'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _saveEntry,
            child: Text(isEditing ? 'Update' : 'Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Card(
                color: (widget.isIncomeCategory ? Colors.green : Colors.red).withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        widget.isIncomeCategory ? Icons.trending_up : Icons.trending_down,
                        color: widget.isIncomeCategory ? Colors.green : Colors.red,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${isEditing ? 'Edit' : 'Add'} $title',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: widget.isIncomeCategory ? Colors.green : Colors.red,
                              ),
                            ),
                            Text(
                              widget.isIncomeCategory 
                                  ? 'Track money coming in'
                                  : 'Track money going out',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category Name Input
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category Name',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _categoryController,
                        decoration: InputDecoration(
                          hintText: widget.isIncomeCategory 
                              ? 'e.g., Salary, Freelance, Business...'
                              : 'e.g., Groceries, Rent, Insurance...',
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(
                            widget.isIncomeCategory ? Icons.trending_up : Icons.trending_down,
                            color: widget.isIncomeCategory ? Colors.green : Colors.red,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a category name';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Amount Input
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isIncomeCategory ? 'Income Amount' : 'Expense Amount',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: InputDecoration(
                          prefixText: 'R ',
                          hintText: '0.00',
                          border: const OutlineInputBorder(),
                          helperText: widget.isIncomeCategory 
                              ? 'How much did you earn?'
                              : 'How much did you spend?',
                        ),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid amount';
                          }
                          if (double.parse(value) <= 0) {
                            return 'Amount must be greater than 0';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description Input
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description (Optional)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: widget.isIncomeCategory 
                              ? 'e.g., Monthly salary, bonus payment...'
                              : 'e.g., Weekly groceries, car payment...',
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tips Card
              Card(
                color: Colors.blue.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Tips',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isIncomeCategory 
                            ? '• Create categories like "Salary", "Freelance", "Business"\n• Enter your actual income amounts\n• Update regularly to track your earnings\n• Use descriptions to add more details'
                            : '• Create categories like "Groceries", "Rent", "Insurance"\n• Enter actual amounts you spend\n• Update regularly to track spending\n• Use descriptions for specific details',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveEntry,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: widget.isIncomeCategory ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    '${isEditing ? 'Update' : 'Add'} $title',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveEntry() async {
    if (_formKey.currentState!.validate()) {
      try {
        final dbHelper = DatabaseHelper();
        final amount = double.parse(_amountController.text);
        final categoryName = _categoryController.text.trim();
        final description = _descriptionController.text.trim();
        final isEditing = widget.budget != null;
        final type = widget.isIncomeCategory ? 'income' : 'expense';
        
        // Check if category already exists
        final categories = await dbHelper.getCategories(type: type);
        Category? categoryData;
        
        try {
          categoryData = categories.firstWhere(
            (cat) => cat.name.toLowerCase() == categoryName.toLowerCase(),
          );
        } catch (e) {
          // Category doesn't exist, create it
          final newCategory = Category(
            name: categoryName,
            type: type,
            icon: 'category',
            color: widget.isIncomeCategory ? 'FF4CAF50' : 'FFF44336',
            createdAt: DateTime.now(),
          );
          
          final categoryId = await dbHelper.insertCategory(newCategory);
          categoryData = newCategory.copyWith(id: categoryId);
        }
        
        // Save as a transaction
        final transaction = Transaction(
          amount: amount,
          description: description.isEmpty ? '$type entry for $categoryName' : description,
          categoryId: categoryData.id!,
          date: DateTime.now(),
          type: type,
          createdAt: DateTime.now(),
        );
        
        await dbHelper.insertTransaction(transaction);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$categoryName ${isEditing ? 'updated' : 'added'}: R${amount.toStringAsFixed(2)}',
            ),
          ),
        );
        
        // Return true to indicate success
        Navigator.pop(context, true);
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
