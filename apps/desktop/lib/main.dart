import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/catalog/product_catalog_screen.dart';
import 'src/dashboard/admin_dashboard_screen.dart';
import 'src/employees/employee_management_screen.dart';

final adminDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.inMemory();
  ref.onDispose(() => db.close());
  return db;
});

void main() {
  runApp(
    const ProviderScope(
      child: GroceryPosDesktopAdminApp(),
    ),
  );
}

class GroceryPosDesktopAdminApp extends ConsumerWidget {
  const GroceryPosDesktopAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Grocery POS - Store Admin Node',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981), // Emerald
          primary: const Color(0xFF10B981),
        ),
        fontFamily: 'Roboto',
      ),
      home: const AdminShellView(),
    );
  }
}

class AdminShellView extends ConsumerStatefulWidget {
  const AdminShellView({super.key});

  @override
  ConsumerState<AdminShellView> createState() => _AdminShellViewState();
}

class _AdminShellViewState extends ConsumerState<AdminShellView> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(adminDatabaseProvider);

    final screens = [
      AdminDashboardScreen(database: db),
      ProductCatalogScreen(database: db),
      EmployeeManagementScreen(database: db),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'FreshMart',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Catalog'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.badge_outlined),
                selectedIcon: Icon(Icons.badge),
                label: Text('Employees'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFE2E8F0)),
          Expanded(child: screens[_selectedIndex]),
        ],
      ),
    );
  }
}
