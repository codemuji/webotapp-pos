import 'dart:io';
import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'src/cart/cart_screen.dart';
import 'src/cart/cart_state.dart';
import 'src/catalog/mobile_catalog_screen.dart';
import 'src/checkout/checkout_dialog.dart';
import 'src/providers.dart';
import 'src/scanner/barcode_scanner_screen.dart';
import 'src/sync/sync_status_sheet.dart';
import 'src/sync/terminal_pairing_screen.dart';
import 'src/theme/webotapp_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppDatabase? db;
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }
    final dbFile = File(p.join(docsDir.path, 'grocery_pos_mobile.db'));
    db = AppDatabase.fromFile(dbFile);
  } catch (e) {
    debugPrint('Could not initialize persistent mobile database: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        if (db != null) databaseProvider.overrideWithValue(db),
      ],
      child: const GroceryPosMobileApp(),
    ),
  );
}

class GroceryPosMobileApp extends ConsumerStatefulWidget {
  const GroceryPosMobileApp({super.key});

  @override
  ConsumerState<GroceryPosMobileApp> createState() => _GroceryPosMobileAppState();
}

class _GroceryPosMobileAppState extends ConsumerState<GroceryPosMobileApp> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final syncCoord = ref.watch(syncCoordinatorProvider);
    final storage = ref.watch(terminalStorageProvider);
    final cart = ref.watch(cartProvider);

    return MaterialApp(
      title: 'WebotApp POS Mobile',
      debugShowCheckedModeBanner: false,
      theme: WebotAppTheme.lightTheme,
      home: Builder(
        builder: (context) {
          final screens = [
            CartScreen(
              onScanPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BarcodeScannerScreen(
                      database: db,
                      syncCoordinator: syncCoord,
                    ),
                  ),
                );
              },
              onBrowseCatalogPressed: () {
                setState(() => _tabIndex = 1);
              },
              onPairPressed: () {
                showSyncStatusSheet(
                  context: context,
                  coordinator: syncCoord,
                  storage: storage,
                  onPairNewServer: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TerminalPairingScreen(
                          storage: storage,
                          pairingClient: ref.read(pairingClientProvider),
                          syncCoordinator: syncCoord,
                        ),
                      ),
                    );
                  },
                );
              },
              onCheckoutPressed: () {
                showTactileCheckoutDialog(
                  context: context,
                  database: db,
                  employeeId: 'emp-001',
                  deviceId: 'term-mobile-01',
                );
              },
            ),
            MobileCatalogScreen(
              database: db,
              syncCoordinator: syncCoord,
              terminalStorage: storage,
              isActiveTab: _tabIndex == 1,
            ),
          ];

          return Scaffold(
            body: IndexedStack(
              index: _tabIndex,
              children: screens,
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
              destinations: [
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: cart.items.isNotEmpty,
                    label: Text('${cart.items.length}'),
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: cart.items.isNotEmpty,
                    label: Text('${cart.items.length}'),
                    child: const Icon(Icons.shopping_cart),
                  ),
                  label: 'Counter POS',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Catalog',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
