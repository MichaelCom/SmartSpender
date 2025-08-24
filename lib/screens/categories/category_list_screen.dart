import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../models/category.dart' as model;
import 'add_category_screen.dart';
import '../../widgets/logo_widget.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  String _selectedFilter = 'all'; // 'all', 'income', 'expense'

  @override
  void initState() {
    super.initState();
    // Load categories when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryProvider>(context, listen: false).loadCategories();
    });
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

  List<model.Category> _getFilteredCategories(List<model.Category> categories) {
    switch (_selectedFilter) {
      case 'income':
        return categories.where((cat) => cat.type == 'income').toList();
      case 'expense':
        return categories.where((cat) => cat.type == 'expense').toList();
      default:
        return categories;
    }
  }

  Future<void> _deleteCategory(model.Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
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
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final success = await categoryProvider.deleteCategory(category.id!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? 'Category deleted successfully' 
                : categoryProvider.error ?? 'Failed to delete category'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const LogoWidget(width: 60, height: 60),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All Categories'),
              ),
              const PopupMenuItem(
                value: 'income',
                child: Text('Income Categories'),
              ),
              const PopupMenuItem(
                value: 'expense',
                child: Text('Expense Categories'),
              ),
            ],
            child: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: Consumer<CategoryProvider>(
        builder: (context, categoryProvider, child) {
          if (categoryProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (categoryProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${categoryProvider.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => categoryProvider.loadCategories(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final filteredCategories = _getFilteredCategories(categoryProvider.categories);

          if (filteredCategories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFilter == 'all' 
                        ? 'No categories found'
                        : 'No ${_selectedFilter} categories found',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the + button to add a category',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => categoryProvider.loadCategories(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredCategories.length,
              itemBuilder: (context, index) {
                final category = filteredCategories[index];
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
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      category.type.toUpperCase(),
                      style: TextStyle(
                        color: category.type == 'income' 
                            ? Colors.green 
                            : Colors.red,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        switch (value) {
                          case 'edit':
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => AddCategoryScreen(category: category),
                              ),
                            );
                            if (result == true) {
                              // Category was updated, refresh the list
                              categoryProvider.loadCategories();
                            }
                            break;
                          case 'delete':
                            await _deleteCategory(category);
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
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddCategoryScreen(),
            ),
          );
          if (result == true) {
            // Category was added, refresh the list
            Provider.of<CategoryProvider>(context, listen: false).loadCategories();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
