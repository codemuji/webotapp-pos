import 'package:database/database.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/cart/cart_state.dart';
import 'package:mobile/src/checkout/checkout_coordinator.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();

    // Insert test products into catalog
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-milk',
            name: 'Cow Milk 500ml',
            barcode: const Value('8901262010001'),
            sellingPrice: 32.0,
            stockQuantity: const Value(50.0),
            updatedAt: DateTime.now(),
          ),
        );
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-eggs',
            name: 'Farm Eggs 6pk',
            barcode: const Value('8901262010002'),
            sellingPrice: 48.0,
            stockQuantity: const Value(20.0),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('CheckoutCoordinator - Slice 2: Atomic Checkout Transaction & Sync Queue Entry', () {
    test('commits invoice, items, delta movements, and sync queue entry atomically', () async {
      final cart = CartState(
        items: [
          CartLineItem(
            productId: 'prod-milk',
            productName: 'Cow Milk 500ml',
            unitPrice: Decimal.parse('32.00'),
            quantity: Decimal.parse('2'),
          ),
          CartLineItem(
            productId: 'prod-eggs',
            productName: 'Farm Eggs 6pk',
            unitPrice: Decimal.parse('48.00'),
            quantity: Decimal.parse('1'),
          ),
        ],
      );

      final coordinator = CheckoutCoordinator(database: db);

      final result = await coordinator.processCheckout(
        cart: cart,
        paymentMethod: 'cash',
        tenderedAmount: Decimal.parse('200.00'),
        employeeId: 'emp-001',
        deviceId: 'term-mobile-01',
      );

      expect(result.invoiceNumber, startsWith('INV-'));
      expect(result.totalAmount, equals(Decimal.parse('112.00')));
      expect(result.tenderedAmount, equals(Decimal.parse('200.00')));
      expect(result.changeDue, equals(Decimal.parse('88.00')));

      // Verify invoice in database
      final savedInvoice = await (db.select(db.invoices)..where((i) => i.id.equals(result.invoiceId))).getSingle();
      expect(savedInvoice.totalAmount, equals(112.00));
      expect(savedInvoice.paymentMethod, equals('cash'));
      expect(savedInvoice.syncStatus, equals('pending'));

      // Verify invoice items
      final savedItems = await db.getItemsForInvoice(result.invoiceId);
      expect(savedItems.length, equals(2));
      expect(savedItems.any((i) => i.productId == 'prod-milk' && i.quantity == 2.0), isTrue);
      expect(savedItems.any((i) => i.productId == 'prod-eggs' && i.quantity == 1.0), isTrue);

      // Verify delta inventory movements
      final movements = await (db.select(db.inventoryMovements)..where((m) => m.referenceId.equals(result.invoiceId))).get();
      expect(movements.length, equals(2));
      expect(movements.any((m) => m.productId == 'prod-milk' && m.deltaQuantity == -2.0), isTrue);
      expect(movements.any((m) => m.productId == 'prod-eggs' && m.deltaQuantity == -1.0), isTrue);

      // Verify pending sync queue entry
      final pendingSyncs = await db.getPendingSyncItems();
      expect(pendingSyncs.length, equals(1));
      expect(pendingSyncs.first.transactionId, equals(result.invoiceId));
      expect(pendingSyncs.first.operation, equals('insert_invoice'));
      expect(pendingSyncs.first.status, equals('pending'));
    });

    test('rejects checkout when cart is empty', () async {
      final cart = CartState(items: const []);
      final coordinator = CheckoutCoordinator(database: db);

      expect(
        () => coordinator.processCheckout(
          cart: cart,
          paymentMethod: 'cash',
          tenderedAmount: Decimal.parse('100.00'),
          employeeId: 'emp-001',
          deviceId: 'term-mobile-01',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects cash checkout when tendered amount is less than total', () async {
      final cart = CartState(
        items: [
          CartLineItem(
            productId: 'prod-milk',
            productName: 'Cow Milk 500ml',
            unitPrice: Decimal.parse('32.00'),
            quantity: Decimal.parse('1'),
          ),
        ],
      );

      final coordinator = CheckoutCoordinator(database: db);

      expect(
        () => coordinator.processCheckout(
          cart: cart,
          paymentMethod: 'cash',
          tenderedAmount: Decimal.parse('20.00'), // Less than ₹32
          employeeId: 'emp-001',
          deviceId: 'term-mobile-01',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
