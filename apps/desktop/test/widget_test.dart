import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/main.dart';

void main() {
  testWidgets('GroceryPosDesktopAdminApp launches to lock screen, unlocks with PIN, navigates sections, and locks again', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: GroceryPosDesktopAdminApp(initialLocked: true),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Starts on Lock Screen
    expect(find.text('Store Console Locked'), findsOneWidget);
    expect(find.text('Enter your Manager or Store Admin PIN to unlock'), findsOneWidget);
    expect(find.text('Default PIN: 1234'), findsOneWidget);

    // 2. Unlock with Default PIN: '1', '2', '3', '4'
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();

    // 3. Unlocked: on Dashboard
    expect(find.text('Store Executive Dashboard'), findsOneWidget);
    expect(find.text('DEPARTMENTAL POS'), findsOneWidget);

    // Verify Employees tab is removed
    expect(find.text('Employees'), findsNothing);

    // Switch to Sales
    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();
    expect(find.text('Sales & Invoices History'), findsOneWidget);

    // Switch to Catalog
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();
    expect(find.text('Product & Category Catalog'), findsOneWidget);

    // Switch to Terminals
    await tester.tap(find.text('Terminals'));
    await tester.pumpAndSettle();
    expect(find.text('Terminal Pairing & Sync Server'), findsOneWidget);

    // Switch to Backups
    await tester.tap(find.text('Backups'));
    await tester.pumpAndSettle();
    expect(find.text('Database Backup & Restore'), findsOneWidget);

    // 4. Lock Console again
    await tester.tap(find.text('Lock Console'));
    await tester.pumpAndSettle();
    expect(find.text('Store Console Locked'), findsOneWidget);
  });
}
