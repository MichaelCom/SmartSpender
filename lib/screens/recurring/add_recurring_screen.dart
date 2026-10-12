import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/category_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/category.dart';
import '../../models/recurring_transaction.dart';
import '../../utils/currency.dart';
import '../../widgets/redesign/redesign.dart';

class AddRecurringScreen extends StatefulWidget {
  final RecurringTransaction? recurring;

  const AddRecurringScreen({super.key, this.recurring});

  @override
  State<AddRecurringScreen> createState() => _AddRecurringScreenState();
}

class _AddRecurringScreenState extends State<AddRecurringScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _type = 'expense';
  Category? _selectedCategory;
  String _frequency = 'monthly';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.recurring != null) {
      // Defer category lookup until providers are available.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadExistingData();
      });
    }
  }

  void _loadExistingData() {
    final r = widget.recurring!;
    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );
    setState(() {
      _amountController.text = r.amount.toStringAsFixed(2);
      _descriptionController.text = r.description ?? '';
      _type = r.type;
      _frequency = r.frequency;
      _startDate = r.startDate;
      _endDate = r.endDate;
      _selectedCategory = r.categoryId == null
          ? null
          : categoryProvider.getCategoryById(r.categoryId!);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<RecurringProvider>(context, listen: false);
      final amount = double.parse(_amountController.text);
      final description = _descriptionController.text.trim();

      bool success;
      if (widget.recurring == null) {
        final rule = RecurringTransaction(
          amount: amount,
          description: description.isEmpty ? null : description,
          categoryId: _selectedCategory?.id,
          type: _type,
          frequency: _frequency,
          startDate: _startDate,
          endDate: _endDate,
          lastGeneratedDate: null,
          createdAt: DateTime.now(),
        );
        success = await provider.addRecurring(rule);
      } else {
        final updated = widget.recurring!.copyWith(
          amount: amount,
          description: description.isEmpty ? null : description,
          categoryId: _selectedCategory?.id,
          type: _type,
          frequency: _frequency,
          startDate: _startDate,
          endDate: _endDate,
        );
        success = await provider.updateRecurring(updated);
      }

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recurring transaction ${widget.recurring == null ? 'created' : 'updated'} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.error ?? 'Failed to save recurring transaction',
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Builds a plain-language summary of the recurring rule for the InfoBanner.
  String _buildSummary(String symbol) {
    final amountText = _amountController.text.trim();
    final parsed = amountText.isEmpty ? null : double.tryParse(amountText);
    final amount =
        parsed == null ? null : CurrencyFormatter.format(symbol, parsed);
    final target = _selectedCategory?.name ?? 'your account';
    final verb = _type == 'income' ? 'Adds' : 'Records';

    final freqPhrase = switch (_frequency) {
      'daily' => 'every day',
      'weekly' => 'every week',
      'monthly' => 'every month',
      'yearly' => 'every year',
      _ => _frequency,
    };

    final startPhrase = 'starting ${DateFormat('d MMM y').format(_startDate)}';
    final endPhrase = _endDate == null
        ? 'repeats indefinitely'
        : 'until ${DateFormat('d MMM y').format(_endDate!)}';

    final amountPart = amount ?? 'this amount';
    return '$verb $amountPart to $target $freqPhrase, $startPhrase ($endPhrase).';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.recurring != null;
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = context.watch<SettingsController>().currencySymbol;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('${isEditing ? 'Edit' : 'Add'} recurring'),
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
              onPressed: _save,
              child: Text(isEditing ? 'Update' : 'Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type segment
            IncomeExpenseSegment(
              value: _type,
              onChanged: (value) {
                setState(() {
                  _type = value;
                  // Reset category when switching type.
                  _selectedCategory = null;
                });
              },
            ),
            const SizedBox(height: 16),

            // Amount
            _FieldLabel('Amount', colorScheme: colorScheme),
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
              onChanged: (_) => setState(() {}),
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

            // Description
            _FieldLabel('Description', colorScheme: colorScheme),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                hintText: 'e.g. Rent, Salary, Subscription…',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Category chips (optional)
            _FieldLabel('Category (optional)', colorScheme: colorScheme),
            const SizedBox(height: 6),
            Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                final categories = _type == 'income'
                    ? categoryProvider.incomeCategories
                    : categoryProvider.expenseCategories;

                if (categories.isEmpty) {
                  return const InfoBanner(
                    icon: '🏷️',
                    message:
                        'No categories yet — this rule will be uncategorised.',
                  );
                }

                // Keep selection valid for the current type.
                final valid = _selectedCategory != null &&
                    categories.any((c) => c.id == _selectedCategory!.id);

                return FilterChipScroller(
                  options: [
                    for (final category in categories)
                      FilterChipOption(
                        value: category.key.toString(),
                        label: category.name,
                      ),
                  ],
                  selected: valid
                      ? _selectedCategory!.key.toString()
                      : '',
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

            // Frequency chips
            _FieldLabel('Frequency', colorScheme: colorScheme),
            const SizedBox(height: 6),
            FilterChipScroller(
              options: const [
                FilterChipOption(value: 'daily', label: 'Daily'),
                FilterChipOption(value: 'weekly', label: 'Weekly'),
                FilterChipOption(value: 'monthly', label: 'Monthly'),
                FilterChipOption(value: 'yearly', label: 'Yearly'),
              ],
              selected: _frequency,
              onSelected: (value) {
                setState(() => _frequency = value);
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
                  lastDate: DateTime(2035),
                );
                if (date != null) {
                  setState(() => _startDate = date);
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

            // End date (optional)
            _FieldLabel('End date (optional)', colorScheme: colorScheme),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate:
                      _endDate ?? _startDate.add(const Duration(days: 30)),
                  firstDate: _startDate,
                  lastDate: DateTime(2040),
                );
                if (date != null) {
                  setState(() => _endDate = date);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.event),
                  suffixIcon: _endDate == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _endDate = null),
                        ),
                ),
                child: Text(
                  _endDate == null
                      ? 'No end date — repeats indefinitely'
                      : DateFormat('d MMMM y').format(_endDate!),
                  style: TextStyle(
                    fontSize: 15,
                    color: _endDate == null
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Plain-language summary banner
            InfoBanner(icon: '🔁', message: _buildSummary(symbol)),
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
