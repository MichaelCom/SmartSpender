import 'demo_data_seeder.dart';

void main() async {
  print('🚀 Starting SmartSpender Demo Data Seeder...');
  print('');
  
  try {
    await seedDemoData();
    print('');
    print('🎉 Demo data has been successfully created!');
    print('');
    print('Your SmartSpender app now includes:');
    print('• 18 realistic categories (12 expense + 6 income)');
    print('• 6 months of transaction history');
    print('• Monthly budgets for major expense categories');
    print('• Varied transaction amounts and descriptions');
    print('');
    print('You can now run your Flutter app to see the demo data in action!');
  } catch (e) {
    print('❌ Error seeding demo data: $e');
  }
}
