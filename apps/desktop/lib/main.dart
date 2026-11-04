import 'dart:io';
import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'src/backup/backup_restore_screen.dart';
import 'src/catalog/product_catalog_screen.dart';
import 'src/dashboard/admin_dashboard_screen.dart';
import 'src/employees/employee_management_screen.dart';
import 'src/sync/sync_server_screen.dart';

final adminDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.inMemory();
  ref.onDispose(() => db.close());
  return db;
});

final desktopSyncServerProvider = Provider<SyncServer>((ref) {
  final db = ref.watch(adminDatabaseProvider);
  final server = SyncServer(database: db, storeName: 'FreshMart Store');
  // Auto-start server in background across all views (skipped in widget tests to avoid port conflicts)
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    server.start(host: InternetAddress.anyIPv4, port: 8085).catchError((e) {
      debugPrint('Auto-start sync server error on port 8085: $e');
    });
  }
  ref.onDispose(() {
    server.stop();
  });
  return server;
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppDatabase? db;
  try {
    final appDir = await getApplicationSupportDirectory();
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    final dbFile = File(p.join(appDir.path, 'grocery_pos_admin.db'));
    db = AppDatabase.fromFile(dbFile);
  } catch (e) {
    debugPrint('Could not initialize persistent admin database: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        if (db != null) adminDatabaseProvider.overrideWithValue(db),
      ],
      child: const GroceryPosDesktopAdminApp(),
    ),
  );
}

class GroceryPosDesktopAdminApp extends ConsumerWidget {
  const GroceryPosDesktopAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep sync server alive globally
    ref.watch(desktopSyncServerProvider);

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
    final server = ref.watch(desktopSyncServerProvider);

    final screens = [
      AdminDashboardScreen(database: db),
      ProductCatalogScreen(database: db),
      EmployeeManagementScreen(database: db),
      SyncServerScreen(database: db, storeName: 'FreshMart Store', server: server),
      BackupRestoreScreen(database: db, isSimulationMode: true),
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
              NavigationRailDestination(
                icon: Icon(Icons.sync_rounded),
                selectedIcon: Icon(Icons.sync),
                label: Text('Terminals'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.backup_outlined),
                selectedIcon: Icon(Icons.backup),
                label: Text('Backups'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: screens,
            ),
          ),
        ],
      ),
    );
  }
}
