import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/cart/cart_screen.dart';
import 'package:mobile/src/cart/cart_state.dart';

void main() {
  group('CartScreen - Slice 3: Fixed-Height List & Instant Totals Bar UI', () {
    testWidgets('displays empty state message when cart has no items', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CartScreen(),
          ),
        ),
      );

      expect(find.text('Cart is empty'), findsOneWidget);
      expect(find.text('Scan products or browse catalog to begin checkout'), findsOneWidget);
    });

    testWidgets('renders items with fixed-height rows and instant totals', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(cartProvider.notifier).addItem(
            productId: 'p-bread',
            productName: 'Brown Bread',
            unitPrice: Decimal.parse('45.00'),
            quantity: Decimal.parse('2'),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CartScreen(),
          ),
        ),
      );

      expect(find.text('Brown Bread'), findsOneWidget);
      expect(find.text('₹90.00'), findsWidgets); // Line total and final total

      // Row height check (fixed height 72dp for zero layout shift)
      final rowFinder = find.byKey(const Key('cart_item_p-bread'));
      expect(rowFinder, findsOneWidget);
      final size = tester.getSize(rowFinder);
      expect(size.height, equals(72.0));
    });

    testWidgets('tapping increment updates cart quantity and totals immediately', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(cartProvider.notifier).addItem(
            productId: 'p-milk',
            productName: 'Toned Milk',
            unitPrice: Decimal.parse('30.00'),
            quantity: Decimal.parse('1'),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CartScreen(),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('₹30.00'), findsWidgets);

      // Tap '+' button
      await tester.tap(find.byKey(const Key('btn_increment_p-milk')));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('₹60.00'), findsWidgets);
    });
  });
}

