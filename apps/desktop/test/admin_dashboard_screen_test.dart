import 'package:database/database.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/src/dashboard/admin_dashboard_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();

    final now = DateTime.now();

    // Seed test invoices
    await db.into(db.invoices).insert(
          InvoicesCompanion.insert(
            id: 'inv-101',
            invoiceNumber: 'INV-20261104-001',
            deviceId: 'term-mobile-01',
            employeeId: 'emp-aarav',
            subtotal: 1250.0,
            totalAmount: 1250.0,
            paymentMethod: 'upi_qr',
            createdAt: now,
          ),
        );

    await db.into(db.invoices).insert(
          InvoicesCompanion.insert(
            id: 'inv-102',
            invoiceNumber: 'INV-20261104-002',
            deviceId: 'term-mobile-01',
            employeeId: 'emp-priya',
            subtotal: 750.0,
            totalAmount: 750.0,
            paymentMethod: 'cash',
            createdAt: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('AdminDashboardScreen - Slice 2: Executive Revenue & Metrics View', () {
    testWidgets('renders revenue, orders, AOV metric cards and payment breakdown', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AdminDashboardScreen(database: db),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify dashboard header
      expect(find.text('Store Executive Dashboard'), findsOneWidget);

      // Total Revenue = 1250 + 750 = ₹2,000.00
      expect(find.text('₹2000.00'), findsOneWidget);
      expect(find.text('Total Revenue'), findsOneWidget);

      // Order count = 2
      expect(find.text('2'), findsWidgets);
      expect(find.text('Orders Completed'), findsOneWidget);

      // Average Order Value = ₹1,000.00
      expect(find.text('₹1000.00'), findsOneWidget);
      expect(find.text('Average Bill Value'), findsOneWidget);

      // Payment Breakdown: UPI (₹1250.00), Cash (₹750.00)
      expect(find.text('UPI QR'), findsOneWidget);
      expect(find.text('₹1250.00'), findsWidgets);
      expect(find.text('CASH'), findsOneWidget);
      expect(find.text('₹750.00'), findsWidgets);

      // Cashier breakdown
      expect(find.text('emp-aarav'), findsOneWidget);
      expect(find.text('emp-priya'), findsOneWidget);
    });
  });
}
