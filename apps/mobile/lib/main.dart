import 'dart:io';
import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'src/cart/cart_screen.dart';
import 'src/checkout/checkout_dialog.dart';
import 'src/providers.dart';
import 'src/scanner/barcode_scanner_screen.dart';
import 'src/sync/sync_status_sheet.dart';
import 'src/sync/terminal_pairing_screen.dart';

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

class GroceryPosMobileApp extends ConsumerWidget {
  const GroceryPosMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return MaterialApp(
      title: 'Grocery POS Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981), // Emerald
          primary: const Color(0xFF10B981),
        ),
        fontFamily: 'Roboto',
      ),
      home: Builder(
        builder: (context) => CartScreen(
          onScanPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BarcodeScannerScreen(
                  database: db,
                  syncCoordinator: ref.read(syncCoordinatorProvider),
                ),
              ),
            );
          },
          onPairPressed: () {
            showSyncStatusSheet(
              context: context,
              coordinator: ref.read(syncCoordinatorProvider),
              storage: ref.read(terminalStorageProvider),
              onPairNewServer: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TerminalPairingScreen(
                      storage: ref.read(terminalStorageProvider),
                      pairingClient: ref.read(pairingClientProvider),
                      syncCoordinator: ref.read(syncCoordinatorProvider),
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
      ),
    );
  }
}
