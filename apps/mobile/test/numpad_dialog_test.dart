import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/cart/quantity_numpad_dialog.dart';

void main() {
  group('QuantityNumpadDialog - Slice 4: Emil Kowalski Dialog Standards & Keypad', () {
    testWidgets('dialog scales from 0.95 with opacity fade on entrance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showQuantityNumpadDialog(
                  context: context,
                  productName: 'Tomatoes',
                  initialQuantity: Decimal.one,
                  unit: 'kg',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Tap to open dialog
      await tester.tap(find.text('Open'));
      await tester.pump(); // Start dialog transition frame

      // Find the ScaleTransition used for the dialog entry
      final scaleFinder = find.ancestor(
        of: find.byType(Dialog),
        matching: find.byType(ScaleTransition),
      );
      expect(scaleFinder, findsOneWidget);

      final ScaleTransition scaleTransition = tester.widget(scaleFinder);
      // Verify initial scale starts at 0.95 (never from scale 0.0)
      expect(scaleTransition.scale.value, closeTo(0.95, 0.01));

      // Settle animation
      await tester.pumpAndSettle();
      expect(scaleTransition.scale.value, closeTo(1.0, 0.005));
    });

    testWidgets('typing numbers and decimal updates displayed quantity and confirms value', (tester) async {
      Decimal? confirmedQuantity;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  confirmedQuantity = await showQuantityNumpadDialog(
                    context: context,
                    productName: 'Fresh Ginger',
                    initialQuantity: Decimal.one,
                    unit: 'kg',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Clear existing input
      await tester.tap(find.byKey(const Key('numpad_clear')));
      await tester.pump();

      // Type 0 . 3 7 5
      await tester.tap(find.byKey(const Key('numpad_0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('numpad_dot')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('numpad_3')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('numpad_7')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('numpad_5')));
      await tester.pump();

      expect(find.text('0.375 kg'), findsOneWidget);

      // Confirm
      await tester.tap(find.byKey(const Key('numpad_confirm')));
      await tester.pumpAndSettle();

      expect(confirmedQuantity, equals(Decimal.parse('0.375')));
    });
  });
}
