import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/recurring_provider.dart';
import 'providers/settings_provider.dart';
import 'database/app_database.dart';
import 'repositories/repositories.dart';
import 'repositories/drift_repositories.dart';
import 'services/recurring_generator.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = await SettingsController.load();

  final database = AppDatabase();
  final repositories = DriftRepositories(database);

  // Catch up any missed recurring transactions before the first frame.
  try {
    await RecurringGenerator(repositories).generateDue();
  } catch (e) {
    debugPrint('Recurring generation error: $e');
  }

  runApp(SmartSpenderApp(repositories: repositories, settings: settings));
}

class SmartSpenderApp extends StatelessWidget {
  const SmartSpenderApp({
    super.key,
    required this.repositories,
    required this.settings,
  });

  final AppRepositories repositories;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppRepositories>.value(value: repositories),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider(
            create: (_) => CategoryProvider(repositories.categories)),
        ChangeNotifierProvider(
            create: (_) => TransactionProvider(repositories.transactions)),
        ChangeNotifierProvider(
            create: (_) => BudgetProvider(repositories.budgets)),
        ChangeNotifierProvider(
            create: (_) => RecurringProvider(repositories.recurring)),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: 'SmartSpender',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          home: const AppInitializer(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize providers and load initial data
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);

      // Load categories first
      await categoryProvider.loadCategories();
      
      // Initialize default categories if none exist
      await categoryProvider.initializeDefaultCategories();
      
      // Load transactions and budgets
      await Future.wait([
        transactionProvider.loadTransactions(),
        budgetProvider.loadBudgets(),
      ]);

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      // Handle initialization error
      debugPrint('App initialization error: $e');
      setState(() {
        _isInitialized = true; // Still proceed to avoid infinite loading
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Initializing SmartSpender...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
