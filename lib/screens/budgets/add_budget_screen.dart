import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/category_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/category.dart';
import '../../models/budget.dart';
import '../../widgets/redesign/redesign.dart';

class AddBudgetScreen extends StatefulWidget {
  final Budget? budget;
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
  final _descriptionController = TextEditingController();

  Category? _selectedCategory;
  String _selectedPeriod = 'monthly';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _loadExistingData();
    }
    _updateEndDate();
  }

  void _loadExistingData() {
    final budget = widget.budget!;
    _amountController.text = budget.amount.toStringAsFixed(2);
    _selectedPeriod = budget.period;
    _startDate = budget.startDate;
    _endDate = budget.endDate;
    _descriptionController.text = budget.description ?? '';

    // Load the category
    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );
    _selectedCategory = categoryProvider.getCategoryById(budget.categoryKey);
  }

  void _updateEndDate() {
    switch (_selectedPeriod) {
      case 'weekly':
        _endDate = _startDate.add(const Duration(days: 7));
        break;
      case 'monthly':
        _endDate =
            DateTime(_startDate.year, _startDate.month + 1, _startDate.day)
                .subtract(const Duration(days: 1));
        break;
      case 'yearly':
        _endDate =
            DateTime(_startDate.year + 1, _startDate.month, _startDate.day)
                .subtract(const Duration(days: 1));
        break;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
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

    try {
      final budgetProvider = Provider.of<BudgetProvider>(
        context,
        listen: false,
      );
      final amount = double.parse(_amountController.text);
      final description = _descriptionController.text.trim();

      // Check for conflicting budgets
      final hasConflict = budgetProvider.hasConflictingBudget(
        _selectedCategory!.key!,
        _startDate,
        _endDate,
        excludeBudgetKey: widget.budget?.key,
      );

      if (hasConflict) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A budget already exists for this category in the selected period',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      bool success;
      if (widget.budget == null) {
        // Creating new budget
        final budget = Budget(
          categoryId: _selectedCategory!.id!,
          amount: amount,
          period: _selectedPeriod,
          startDate: _startDate,
          endDate: _endDate,
          description: description.isEmpty ? null : description,
          createdAt: DateTime.now(),
        );
        success = await budgetProvider.addBudget(budget);
      } else {
        // Updating existing budget
        final updatedBudget = widget.budget!.copyWith(
          categoryId: _selectedCategory!.id!,
          amount: amount,
          period: _selectedPeriod,
          startDate: _startDate,
          endDate: _endDate,
          description: description.isEmpty ? null : description,
        );
        success = await budgetProvider.updateBudget(updatedBudget);
      }

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Budget ${widget.budget == null ? 'created' : 'updated'} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              budgetProvider.error ??
                  'Failed to ${widget.budget == null ? 'create' : 'update'} budget',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.budget != null;
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = context.watch<SettingsController>().currencySymbol;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('${isEditing ? 'Edit' : 'Add'} budget'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveEntry,
              child: Text(isEditing ? 'Update' : 'Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Category chips
            _FieldLabel('Category', colorScheme: colorScheme),
            const SizedBox(height: 6),
            Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                final categories = widget.isIncomeCategory
                    ? categoryProvider.incomeCategories
                    : categoryProvider.expenseCategories;

                if (categories.isEmpty) {
                  return const InfoBanner(
                    icon: '🏷️',
                    message: 'No categories yet. Add categories first.',
                  );
                }

                return FilterChipScroller(
                  options: [
                    for (final category in categories)
                      FilterChipOption(
                        value: category.key.toString(),
                        label: category.name,
                      ),
                  ],
                  selected: _selectedCategory?.key?.toString() ?? '',
                  onSelected: (value) {
                    final key = int.tryParse(value);
                    setState(() {
                      _selectedCategory = key == null
                          ? null
                          : categoryProvider.getCategoryById(key);
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Amount
            _FieldLabel('Budget amount', colorScheme: colorScheme),
            const SizedBox(height: 6),
            TextFormField(
              controller: _amountController,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: '0.00',
                prefixText: '$symbol ',
                prefixStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
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
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Period
            _FieldLabel('Period', colorScheme: colorScheme),
            const SizedBox(height: 6),
            FilterChipScroller(
              options: const [
                FilterChipOption(value: 'weekly', label: 'Weekly'),
                FilterChipOption(value: 'monthly', label: 'Monthly'),
                FilterChipOption(value: 'yearly', label: 'Yearly'),
              ],
              selected: _selectedPeriod,
              onSelected: (value) {
                setState(() {
                  _selectedPeriod = value;
                  _updateEndDate();
                });
              },
            ),
            const SizedBox(height: 16),

            // Start date
            _FieldLabel('Start date', colorScheme: colorScheme),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() {
                    _startDate = date;
                    _updateEndDate();
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('d MMMM y').format(_startDate),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // End date (auto-derived, read-only)
            _FieldLabel('End date', colorScheme: colorScheme),
            const SizedBox(height: 6),
            InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event),
              ),
              child: Text(
                DateFormat('d MMMM y').format(_endDate),
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description (optional)
            _FieldLabel('Description (optional)', colorScheme: colorScheme),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                hintText: 'Add a note about this budget…',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Conflict-warning / info banner
            const InfoBanner(
              icon: '💡',
              tone: InfoBannerTone.warning,
              message:
                  "End date is set automatically from the period. You'll be "
                  'warned if a budget already exists for this category + period.',
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {required this.colorScheme});

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
