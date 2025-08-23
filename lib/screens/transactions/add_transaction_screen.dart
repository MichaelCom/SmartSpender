import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart' as model;
import '../../models/category.dart' as model;
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  final model.Transaction?
  transaction; // null for add, existing transaction for edit

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedType = 'expense';
  int? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      // Editing existing transaction
      _amountController.text = widget.transaction!.amount.toString();
      _descriptionController.text = widget.transaction!.description ?? '';
      _selectedType = widget.transaction!.type;
      _selectedCategoryId = widget.transaction!.categoryId;
      _selectedDate = widget.transaction!.date;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final transactionProvider = Provider.of<TransactionProvider>(
      context,
      listen: false,
    );

    final transaction = model.Transaction(
      id: widget.transaction?.id,
      amount: double.parse(_amountController.text),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      categoryId: _selectedCategoryId!,
      date: _selectedDate,
      type: _selectedType,
      createdAt: widget.transaction?.createdAt ?? DateTime.now(),
    );

    bool success;
    if (widget.transaction == null) {
      // Adding new transaction
      success = await transactionProvider.addTransaction(transaction);
    } else {
      // Updating existing transaction
      success = await transactionProvider.updateTransaction(transaction);
    }

    setState(() {
      _isLoading = false;
    });

    if (success) {
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.transaction == null
                  ? 'Transaction added successfully!'
                  : 'Transaction updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              transactionProvider.error ?? 'Failed to save transaction',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null ? 'Add Transaction' : 'Edit Transaction'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(onPressed: _saveTransaction, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Transaction Type
            const Text(
              'Transaction Type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Income'),
                    value: 'income',
                    groupValue: _selectedType,
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                        _selectedCategoryId = null; // Reset category selection
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Expense'),
                    value: 'expense',
                    groupValue: _selectedType,
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                        _selectedCategoryId = null; // Reset category selection
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  _selectedType == 'income' ? Icons.add : Icons.remove,
                  color: _selectedType == 'income' ? Colors.green : Colors.red,
                ),
                prefixText: '\R',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount greater than 0';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Category Selection
            Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                final categories = _selectedType == 'income'
                    ? categoryProvider.incomeCategories
                    : categoryProvider.expenseCategories;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (categories.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No ${_selectedType} categories found',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Please add categories first',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...categories.map((category) {
                        final isSelected = _selectedCategoryId == category.id;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _hexToColor(category.color ?? '#FF6B6B'),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getIconData(category.icon ?? 'category'),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedCategoryId = category.id;
                              });
                            },
                          ),
                        );
                      }).toList(),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 16),

            // Date Selection
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date'),
                subtitle: Text(
                  DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _selectDate,
              ),
            ),

            const SizedBox(height: 32),

            // Preview
            if (_selectedCategoryId != null)
              Consumer<CategoryProvider>(
                builder: (context, categoryProvider, child) {
                  final category = categoryProvider.getCategoryById(
                    _selectedCategoryId!,
                  );
                  if (category == null) return const SizedBox.shrink();

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Preview',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _hexToColor(
                                    category.color ?? '#FF6B6B',
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getIconData(category.icon ?? 'category'),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _descriptionController.text.isEmpty
                                          ? 'No description'
                                          : _descriptionController.text,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'MMM d, y',
                                      ).format(_selectedDate),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${_selectedType == 'income' ? '+' : '-'}\$${_amountController.text.isEmpty ? '0.00' : _amountController.text}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedType == 'income'
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                  Text(
                                    _selectedType.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedType == 'income'
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
