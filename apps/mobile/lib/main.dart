import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/cart/cart_screen.dart';
import 'src/checkout/checkout_dialog.dart';
import 'src/providers.dart';
import 'src/scanner/barcode_scanner_screen.dart';
import 'src/sync/terminal_pairing_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: GroceryPosMobileApp(),
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
                ),
              ),
            );
          },
          onPairPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TerminalPairingScreen(
                  storage: ref.read(terminalStorageProvider),
                  pairingClient: ref.read(pairingClientProvider),
                ),
              ),
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
