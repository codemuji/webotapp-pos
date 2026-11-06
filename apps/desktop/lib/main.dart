import 'dart:async';
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
import 'src/sales/sales_transactions_screen.dart';
import 'src/sync/sync_server_screen.dart';
import 'src/theme/webotapp_logo.dart';
import 'src/theme/webotapp_theme.dart';

void _logCrash(Object error, StackTrace stack) {
  try {
    getApplicationSupportDirectory().then((dir) {
      final file = File(p.join(dir.path, 'desktop_crash.log'));
      file.writeAsStringSync('CRASH [${DateTime.now()}]: $error\n$stack\n', mode: FileMode.append);
    });
  } catch (_) {}
}

final adminDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.inMemory();
  ref.onDispose(() => db.close());
  return db;
});

final desktopSyncServerProvider = Provider<SyncServer>((ref) {
  final db = ref.watch(adminDatabaseProvider);
  final server = SyncServer(database: db, storeName: 'WebotApp Store');
  // Auto-start server in background across all views (skipped in widget tests to avoid port conflicts)
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    server.start(host: InternetAddress.anyIPv4, port: 8085).catchError((e, st) {
      _logCrash(e, st);
      debugPrint('Auto-start sync server error on port 8085: $e');
    });
  }
  ref.onDispose(() {
    server.stop();
  });
  return server;
});

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      _logCrash(details.exception, details.stack ?? StackTrace.current);
    };

    AppDatabase? db;
    try {
      final appDir = await getApplicationSupportDirectory();
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      final dbFile = File(p.join(appDir.path, 'grocery_pos_admin.db'));
      db = AppDatabase.fromFile(dbFile);
    } catch (e, st) {
      _logCrash(e, st);
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
  }, (error, stack) {
    _logCrash(error, stack);
  });
}

class GroceryPosDesktopAdminApp extends ConsumerWidget {
  const GroceryPosDesktopAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep sync server alive globally
    ref.watch(desktopSyncServerProvider);

    return MaterialApp(
      title: 'WebotApp POS — Store Admin Node',
      debugShowCheckedModeBanner: false,
      theme: WebotAppTheme.lightTheme,
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
      AdminDashboardScreen(
        database: db,
        onNavigateToSales: () => setState(() => _selectedIndex = 1),
      ),
      SalesTransactionsScreen(database: db),
      ProductCatalogScreen(database: db),
      EmployeeManagementScreen(database: db),
      SyncServerScreen(database: db, storeName: 'WebotApp Store', server: server),
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
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: WebotAppTheme.darkSlate,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: WebotAppTheme.darkSlate.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: WebotAppLogoMark(size: 26),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: -0.3,
                      ),
                      children: [
                        TextSpan(
                          text: 'WEBOT',
                          style: TextStyle(color: WebotAppTheme.darkSlate),
                        ),
                        TextSpan(
                          text: 'APP',
                          style: TextStyle(color: WebotAppTheme.primaryGreen),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'POS SYSTEM',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 8,
                      letterSpacing: 1.0,
                      color: WebotAppTheme.slate500,
                    ),
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
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: Text('Sales'),
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
