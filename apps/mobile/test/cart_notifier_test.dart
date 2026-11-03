import 'package:billing_engine/billing_engine.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/cart/cart_state.dart';

void main() {
  group('CartNotifier - Slice 1: Optimistic Cart State & BillingEngine Integration', () {
    test('starts with an empty cart and zero totals', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(cartProvider);
      expect(state.items, isEmpty);
      expect(state.totalAmount, equals(Decimal.zero));
      expect(state.totalQuantity, equals(Decimal.zero));
    });

    test('adds new item and automatically computes subtotals via BillingEngine', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      notifier.addItem(
        productId: 'prod-milk',
        productName: 'Fresh Milk 1L',
        unitPrice: Decimal.parse('60.00'),
        barcode: '8901234',
      );

      final state = container.read(cartProvider);
      expect(state.items.length, equals(1));
      expect(state.items.first.quantity, equals(Decimal.one));
      expect(state.items.first.productName, equals('Fresh Milk 1L'));
      expect(state.subtotal, equals(Decimal.parse('60.00')));
      expect(state.totalAmount, equals(Decimal.parse('60.00')));
    });

    test('scanning/adding an existing product increments quantity instead of adding duplicate line', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      notifier.addItem(
        productId: 'prod-bread',
        productName: 'Whole Wheat Bread',
        unitPrice: Decimal.parse('40.00'),
      );
      notifier.addItem(
        productId: 'prod-bread',
        productName: 'Whole Wheat Bread',
        unitPrice: Decimal.parse('40.00'),
      );

      final state = container.read(cartProvider);
      expect(state.items.length, equals(1));
      expect(state.items.first.quantity, equals(Decimal.parse('2')));
      expect(state.subtotal, equals(Decimal.parse('80.00')));
    });

    test('increments, decrements, and sets fractional quantities', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      notifier.addItem(
        productId: 'prod-apples',
        productName: 'Apples',
        unitPrice: Decimal.parse('120.00'),
        quantity: Decimal.parse('0.5'),
        unit: 'kg',
      );

      expect(container.read(cartProvider).totalAmount, equals(Decimal.parse('60.00')));

      // Set quantity to 1.5 kg
      notifier.setQuantity('prod-apples', Decimal.parse('1.5'));
      expect(container.read(cartProvider).totalAmount, equals(Decimal.parse('180.00')));

      // Decrement by 1
      notifier.decrementQuantity('prod-apples');
      expect(container.read(cartProvider).items.first.quantity, equals(Decimal.parse('0.5')));

      // Decrement below 0 removes item
      notifier.decrementQuantity('prod-apples', Decimal.one);
      expect(container.read(cartProvider).items, isEmpty);
    });

    test('removes item and clears cart', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      notifier.addItem(
        productId: 'p1',
        productName: 'Item 1',
        unitPrice: Decimal.parse('10.00'),
      );
      notifier.addItem(
        productId: 'p2',
        productName: 'Item 2',
        unitPrice: Decimal.parse('20.00'),
      );

      expect(container.read(cartProvider).items.length, equals(2));

      notifier.removeItem('p1');
      expect(container.read(cartProvider).items.length, equals(1));
      expect(container.read(cartProvider).items.first.productId, equals('p2'));

      notifier.clearCart();
      expect(container.read(cartProvider).items, isEmpty);
      expect(container.read(cartProvider).totalAmount, equals(Decimal.zero));
    });
  });
}

