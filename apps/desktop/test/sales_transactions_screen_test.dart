import 'package:database/database.dart';
import 'package:desktop/src/sales/invoice_detail_dialog.dart';
import 'package:desktop/src/sales/sales_transactions_screen.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('SalesTransactionsScreen renders empty state when no sales exist', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SalesTransactionsScreen(database: db),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sales & Invoices History'), findsOneWidget);
    expect(find.text('No Sales Transactions Found'), findsOneWidget);
    expect(find.text('Filtered Orders'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('SalesTransactionsScreen renders synced sales and opens detailed breakdown dialog', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Seed a synced invoice with 2 items, including discount and tax
    final now = DateTime.now();
    await db.into(db.invoices).insert(
          InvoicesCompanion.insert(
            id: 'inv-sync-001',
            invoiceNumber: 'INV-20261105-001',
            deviceId: 'term-mobile-01',
            employeeId: 'emp-cashier-1',
            subtotal: 350.0,
            discount: const Value(35.0),
            taxAmount: const Value(15.75),
            totalAmount: 330.75,
            paymentMethod: 'cash',
            createdAt: now,
            syncStatus: const Value('synced'),
          ),
        );

    await db.into(db.invoiceItems).insert(
          InvoiceItemsCompanion.insert(
            id: 'item-001-1',
            invoiceId: 'inv-sync-001',
            productName: 'Aashirvaad Atta 5kg',
            barcode: const Value('8901030383786'),
            quantity: 1.0,
            unitPrice: 250.0,
            discount: const Value(25.0),
            taxAmount: const Value(0.0),
            lineTotal: 225.0,
          ),
        );

    await db.into(db.invoiceItems).insert(
          InvoiceItemsCompanion.insert(
            id: 'item-001-2',
            invoiceId: 'inv-sync-001',
            productName: 'Tata Salt 1kg',
            barcode: const Value('8901058852331'),
            quantity: 4.0,
            unitPrice: 25.0,
            discount: const Value(10.0),
            taxAmount: const Value(15.75),
            lineTotal: 105.75,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: SalesTransactionsScreen(database: db),
      ),
    );
    await tester.pumpAndSettle();

    // Verify row displays
    expect(find.text('INV-20261105-001'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('₹350.00'), findsWidgets); // subtotal
    expect(find.text('-₹35.00'), findsOneWidget); // discount
    expect(find.text('₹330.75'), findsWidgets); // total amount
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);

    // Tap View Details icon button
    final viewIcon = find.byTooltip('View Sale Breakdown & Products');
    expect(viewIcon, findsOneWidget);
    await tester.ensureVisible(viewIcon);
    await tester.tap(viewIcon);
    await tester.pumpAndSettle();

    // Verify modal dialog opened
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Purchased Products & Offers Breakdown'), findsOneWidget);
    expect(find.text('Aashirvaad Atta 5kg'), findsOneWidget);
    expect(find.text('[8901030383786]'), findsNothing); // It's in the data table
    expect(find.text('Tata Salt 1kg'), findsOneWidget);
    expect(find.text('Print Thermal Receipt (80mm)'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
