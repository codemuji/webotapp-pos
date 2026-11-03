import 'package:database/database.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/cart/cart_state.dart';
import 'package:mobile/src/checkout/checkout_dialog.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();

    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-rice',
            name: 'Basmati Rice 1kg',
            barcode: const Value('8901234567890'),
            sellingPrice: 120.0,
            stockQuantity: const Value(50.0),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('CheckoutDialog - Slice 4: Tactile Payment Modal & Emil Kowalski Standards', () {
    testWidgets('emerges from scale(0.95) with fade and displays payment options', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(cartProvider.notifier).addItem(
            productId: 'prod-rice',
            productName: 'Basmati Rice 1kg',
            unitPrice: Decimal.parse('120.00'),
            quantity: Decimal.parse('1'),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showTactileCheckoutDialog(
                    context: context,
                    database: db,
                    employeeId: 'emp-001',
                    deviceId: 'term-mobile-01',
                  ),
                  child: const Text('Open Checkout'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Checkout'));
      await tester.pump(); // Start opening transition

      // Verify Emil Kowalski dialog emerging scale starts around 0.95, not 0.0
      final scaleFinder = find.ancestor(
        of: find.byType(Dialog),
        matching: find.byType(ScaleTransition),
      );
      expect(scaleFinder, findsOneWidget);
      final ScaleTransition transition = tester.widget(scaleFinder);
      expect(transition.scale.value, greaterThanOrEqualTo(0.94));

      await tester.pumpAndSettle();

      // Verify UI elements
      expect(find.text('CHECKOUT'), findsOneWidget);
      expect(find.text('₹120.00'), findsWidgets);
      expect(find.text('CASH'), findsOneWidget);
      expect(find.text('UPI QR'), findsOneWidget);
      expect(find.text('CARD'), findsOneWidget);
      expect(find.text('Complete Sale'), findsOneWidget);
    });

    testWidgets('calculates cash change and enables checkout upon entering cash tender', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(cartProvider.notifier).addItem(
            productId: 'prod-rice',
            productName: 'Basmati Rice 1kg',
            unitPrice: Decimal.parse('120.00'),
            quantity: Decimal.parse('1'),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showTactileCheckoutDialog(
                    context: context,
                    database: db,
                    employeeId: 'emp-001',
                    deviceId: 'term-mobile-01',
                  ),
                  child: const Text('Open Checkout'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Checkout'));
      await tester.pumpAndSettle();

      // Quick tender button: tap '₹200'
      final pill200 = find.text('₹200');
      expect(pill200, findsOneWidget);
      await tester.tap(pill200);
      await tester.pump();

      // Verify change calculation: 200 - 120 = ₹80.00
      expect(find.text('₹80.00'), findsOneWidget);

      // Tap Complete Sale
      await tester.tap(find.text('Complete Sale'));
      await tester.pumpAndSettle();

      // Should show success view with receipt actions
      expect(find.text('Sale Completed!'), findsOneWidget);
      expect(find.text('Print Receipt'), findsOneWidget);
      expect(find.text('Share via WhatsApp'), findsOneWidget);
      expect(find.text('New Sale'), findsOneWidget);

      // Verify cart was cleared after successful sale
      expect(container.read(cartProvider).items, isEmpty);
    });
  });
}
