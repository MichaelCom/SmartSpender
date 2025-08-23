import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category.dart' as model;
import '../../providers/category_provider.dart';

class AddCategoryScreen extends StatefulWidget {
  final model.Category? category; // null for add, existing category for edit

  const AddCategoryScreen({super.key, this.category});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  String _selectedType = 'expense';
  String _selectedColor = '#FF6B6B';
  String _selectedIcon = 'category';
  bool _isLoading = false;

  // Available colors for categories
  final List<String> _colors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
    '#DDA0DD', '#98D8C8', '#F7DC6F', '#2ECC71', '#3498DB',
    '#9B59B6', '#E74C3C', '#F39C12', '#1ABC9C', '#34495E'
  ];

  // Available icons for categories
  final Map<String, IconData> _icons = {
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

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      // Editing existing category
      _nameController.text = widget.category!.name;
      _selectedType = widget.category!.type;
      _selectedColor = widget.category!.color ?? _selectedColor;
      _selectedIcon = widget.category!.icon ?? _selectedIcon;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    
    final category = model.Category(
      id: widget.category?.id,
      name: _nameController.text.trim(),
      type: _selectedType,
      color: _selectedColor,
      icon: _selectedIcon,
      createdAt: widget.category?.createdAt ?? DateTime.now(),
    );

    bool success;
    if (widget.category == null) {
      // Adding new category
      success = await categoryProvider.addCategory(category);
    } else {
      // Updating existing category
      success = await categoryProvider.updateCategory(category);
    }

    setState(() {
      _isLoading = false;
    });

    if (success) {
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.category == null 
                ? 'Category added successfully!' 
                : 'Category updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(categoryProvider.error ?? 'Failed to save category'),
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
        title: Text(widget.category == null ? 'Add Category' : 'Edit Category'),
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
            TextButton(
              onPressed: _saveCategory,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Category Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a category name';
                }
                if (value.trim().length < 2) {
                  return 'Category name must be at least 2 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Category Type
            const Text(
              'Category Type',
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
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Color Selection
            const Text(
              'Color',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colors.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _hexToColor(color),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 3)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 24),
            
            // Icon Selection
            const Text(
              'Icon',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.entries.map((entry) {
                final isSelected = entry.key == _selectedIcon;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = entry.key;
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected ? _hexToColor(_selectedColor) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                    child: Icon(
                      entry.value,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 32),
            
            // Preview
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preview',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _hexToColor(_selectedColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _icons[_selectedIcon],
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nameController.text.isEmpty 
                                    ? 'Category Name' 
                                    : _nameController.text,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
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
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
