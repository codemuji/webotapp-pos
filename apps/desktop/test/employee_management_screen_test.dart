import 'package:database/database.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/src/employees/employee_management_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();

    await db.upsertEmployee(
      EmployeesCompanion.insert(
        id: 'emp-01',
        name: 'Aarav Sharma',
        pinHash: '1234',
        role: const Value('cashier'),
        createdAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('EmployeeManagementScreen - Slice 4: Employee PIN & Role Access Management', () {
    testWidgets('renders employees list and role badges', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: EmployeeManagementScreen(database: db),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Employee & Security Management'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('cashier'), findsOneWidget);
      expect(find.text('Add Employee'), findsOneWidget);
    });

    testWidgets('adds a new employee with 4-digit PIN and cashier role', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: EmployeeManagementScreen(database: db),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Add Employee dialog
      await tester.tap(find.text('Add Employee'));
      await tester.pumpAndSettle();

      expect(find.text('New Employee Registration'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('input_employee_name')), 'Kiran Patel');
      await tester.enterText(find.byKey(const Key('input_employee_pin')), '5678');

      await tester.tap(find.text('Save Employee'));
      await tester.pumpAndSettle();

      expect(find.text('Kiran Patel'), findsOneWidget);

      // Verify PIN verification works in database
      final employees = await db.getAllEmployees();
      final kiran = employees.firstWhere((e) => e.name == 'Kiran Patel');
      final isPinValid = await db.verifyEmployeePin(kiran.id, '5678');
      expect(isPinValid, isTrue);
    });
  });
}

