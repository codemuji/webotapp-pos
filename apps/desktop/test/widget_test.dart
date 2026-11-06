import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/main.dart';

void main() {
  testWidgets('GroceryPosDesktopAdminApp launches and navigates between admin sections', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: GroceryPosDesktopAdminApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Starts on Dashboard
    expect(find.text('Store Executive Dashboard'), findsOneWidget);
    expect(find.text('DEPARTMENTAL POS'), findsOneWidget);

    // Switch to Sales
    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();
    expect(find.text('Sales & Invoices History'), findsOneWidget);

    // Switch to Catalog
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();
    expect(find.text('Product & Category Catalog'), findsOneWidget);

    // Switch to Employees
    await tester.tap(find.text('Employees'));
    await tester.pumpAndSettle();
    expect(find.text('Employee & Security Management'), findsOneWidget);

    // Switch to Backups
    await tester.tap(find.text('Backups'));
    await tester.pumpAndSettle();
    expect(find.text('Database Backup & Restore'), findsOneWidget);
  });
}
