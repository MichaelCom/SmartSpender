import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart' as model;
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/currency.dart';
import '../../utils/budget_alerts.dart';
import '../../services/insights/categorization_engine.dart';
import '../../widgets/redesign/redesign.dart';

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
  final _noteController = TextEditingController();

  String _selectedType = 'expense';
  int? _selectedCategoryKey;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // Auto-categorization (A1): debounced suggestion computed from the
  // description, shown only while no category has been chosen.
  Timer? _suggestDebounce;
  CategorySuggestion? _categorySuggestion;
  static const Duration _suggestDelay = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      // Editing existing transaction
      _amountController.text = widget.transaction!.amount.toString();
      _descriptionController.text = widget.transaction!.description ?? '';
      _selectedType = widget.transaction!.type;
      _selectedCategoryKey = widget.transaction!.categoryKey;
      _selectedDate = widget.transaction!.date;
    }
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Debounced recompute of the category suggestion as the user types.
  void _onDescriptionChanged(String _) {
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(_suggestDelay, _recomputeSuggestion);
  }

  /// Recomputes [_categorySuggestion] from the current description, using the
  /// categories filtered to [_selectedType] and the user's transaction history.
  void _recomputeSuggestion() {
    if (!mounted) return;

    // No suggestion needed once a category is chosen.
    if (_selectedCategoryKey != null) {
      if (_categorySuggestion != null) {
        setState(() => _categorySuggestion = null);
      }
      return;
    }

    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );
    final transactionProvider = Provider.of<TransactionProvider>(
      context,
      listen: false,
    );
    final categories = _selectedType == 'income'
        ? categoryProvider.incomeCategories
        : categoryProvider.expenseCategories;

    final suggestion = CategorizationEngine.suggest(
      description: _descriptionController.text,
      categories: categories,
      history: transactionProvider.transactions,
      type: _selectedType,
    );

    if (!mounted) return;
    setState(() => _categorySuggestion = suggestion);
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

    if (_selectedCategoryKey == null) {
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
    final budgetProvider = Provider.of<BudgetProvider>(
      context,
      listen: false,
    );
    final settings = Provider.of<SettingsController>(
      context,
      listen: false,
    );

    final enteredAmount = double.parse(_amountController.text);
    final enteredCategoryKey = _selectedCategoryKey!;
    final enteredType = _selectedType;
    final enteredDate = _selectedDate;

    final transaction = model.Transaction(
      amount: enteredAmount,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      categoryId: _selectedCategoryKey!,
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
      // Ensure budget data is available for the warning check.
      if (enteredType == 'expense') {
        await budgetProvider.loadBudgets();
      }
      if (mounted) {
        // Non-blocking budget warning (expense with a category only).
        final warning = enteredType == 'expense'
            ? _buildBudgetWarning(
                budgetProvider: budgetProvider,
                transactionProvider: transactionProvider,
                settings: settings,
                categoryKey: enteredCategoryKey,
                enteredDate: enteredDate,
              )
            : null;

        Navigator.of(context).pop(true);
        final messenger = ScaffoldMessenger.of(context);
        if (warning != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(warning),
              backgroundColor: Colors.orange,
            ),
          );
        }
        messenger.showSnackBar(
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

  /// Builds a heads-up message when the just-saved expense pushes an active
  /// budget to [BudgetAlertLevel.nearing] or [BudgetAlertLevel.exceeded], else
  /// null. The transaction has already been persisted and the provider
  /// reloaded, so [transactionProvider] already reflects the new spend.
  String? _buildBudgetWarning({
    required BudgetProvider budgetProvider,
    required TransactionProvider transactionProvider,
    required SettingsController settings,
    required int categoryKey,
    required DateTime enteredDate,
  }) {
    final budget = budgetProvider.getActiveBudgetForCategory(categoryKey);
    if (budget == null) return null;

    // Projected spent = all expenses for this category within the budget period
    // (already includes the just-saved transaction after the provider reload).
    final transactions =
        transactionProvider.getTransactionsByCategory(categoryKey);
    final projectedSpent = transactions.where((t) {
      return t.type == 'expense' &&
          t.date.isAfter(budget.startDate.subtract(const Duration(days: 1))) &&
          t.date.isBefore(budget.endDate.add(const Duration(days: 1)));
    }).fold(0.0, (sum, t) => sum + t.amount);

    final status = BudgetAlerts.evaluate(
      spent: projectedSpent,
      limit: budget.amount,
      thresholdPercent: settings.budgetAlertThreshold,
    );

    final name = budget.categoryName ?? 'this';
    final symbol = settings.currencySymbol;
    if (status.isExceeded) {
      return 'Heads up: this puts your $name budget '
          '${CurrencyFormatter.format(symbol, status.overBy)} over.';
    }
    if (status.isNearing) {
      final remaining = budget.amount - projectedSpent;
      return 'Heads up: your $name budget is nearing its limit '
          '(${CurrencyFormatter.format(symbol, remaining)} left).';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = context.watch<SettingsController>().currencySymbol;
    final isEdit = widget.transaction != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(isEdit ? 'Edit transaction' : 'Add transaction'),
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
            TextButton(
              onPressed: _saveTransaction,
              child: Text(
                'Save',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Expense / Income toggle.
            IncomeExpenseSegment(
              value: _selectedType,
              onChanged: (type) {
                setState(() {
                  _selectedType = type;
                  _selectedCategoryKey = null; // Reset category selection
                  _categorySuggestion = null;
                });
                // Re-evaluate the suggestion for the new type.
                _recomputeSuggestion();
              },
            ),
            const SizedBox(height: 20),

            // Amount (large, centred).
            _FieldLabel('Amount', colorScheme: colorScheme),
            const SizedBox(height: 6),
            TextFormField(
              controller: _amountController,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.01,
              ),
              decoration: InputDecoration(
                prefixText: '$symbol ',
                hintText: '0.00',
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

            // Description.
            _FieldLabel('Description', colorScheme: colorScheme),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.notes),
                hintText: 'e.g. Woolworths',
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: _onDescriptionChanged,
            ),
            const SizedBox(height: 16),

            // Category chips.
            _FieldLabel('Category', colorScheme: colorScheme),
            const SizedBox(height: 6),
            Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                final categories = _selectedType == 'income'
                    ? categoryProvider.incomeCategories
                    : categoryProvider.expenseCategories;

                if (categories.isEmpty) {
                  return InfoBanner(
                    icon: '🏷️',
                    message:
                        'No $_selectedType categories yet. Add categories first.',
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
                  selected: _selectedCategoryKey?.toString() ?? '',
                  onSelected: (value) {
                    setState(() {
                      _selectedCategoryKey = int.tryParse(value);
                      // Chosen category clears the suggestion banner.
                      _categorySuggestion = null;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Date.
            _FieldLabel('Date', colorScheme: colorScheme),
            const SizedBox(height: 6),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today),
                  suffixIcon: Icon(Icons.arrow_forward_ios, size: 16),
                ),
                child: Text(
                  DateFormat('d MMMM y').format(_selectedDate),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Optional note.
            _FieldLabel('Note (optional)', colorScheme: colorScheme),
            const SizedBox(height: 6),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'Add a note…',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Smart-category suggestion banner (A1). Shown only when a
            // suggestion exists AND no category has been chosen yet. The
            // "Apply" action applies the suggested category.
            _buildSuggestionBanner(),
          ],
        ),
      ),
    );
  }

  /// Builds the auto-categorization suggestion banner, or an empty widget when
  /// there is nothing confident to suggest / a category is already chosen.
  Widget _buildSuggestionBanner() {
    final suggestion = _categorySuggestion;
    if (suggestion == null || _selectedCategoryKey != null) {
      return const SizedBox.shrink();
    }

    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );
    final category = categoryProvider.getCategoryById(suggestion.categoryId);
    if (category == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return InfoBanner(
      icon: '💡',
      messageWidget: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: colorScheme.onSurface,
          ),
          children: [
            const TextSpan(text: 'Suggested category: '),
            TextSpan(
              text: category.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      trailing: TextButton(
        onPressed: () {
          setState(() {
            _selectedCategoryKey = suggestion.categoryId;
            _categorySuggestion = null;
          });
        },
        child: const Text('Apply'),
      ),
    );
  }
}

/// A small field label matching the mockup `.m-field label` style.
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
