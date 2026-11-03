import 'package:billing_engine/billing_engine.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('BillingEngine - Slice 1: Line Subtotals & Decimal Precision', () {
    test('calculates exact line item totals and overall subtotal without floating point drift', () {
      final items = [
        CartItemInput(
          productId: 'prod-1',
          productName: 'Tomatoes',
          unitPrice: Decimal.parse('14.50'),
          quantity: Decimal.parse('2.5'),
        ),
        CartItemInput(
          productId: 'prod-2',
          productName: 'Bread',
          unitPrice: Decimal.parse('19.99'),
          quantity: Decimal.parse('3'),
        ),
        CartItemInput(
          productId: 'prod-3',
          productName: 'Matchbox',
          unitPrice: Decimal.parse('0.10'),
          quantity: Decimal.parse('3'),
        ),
      ];

      final result = BillingEngine.calculate(items: items);

      expect(result.lineResults.length, equals(3));
      expect(result.lineResults[0].lineSubtotal, equals(Decimal.parse('36.25')));
      expect(result.lineResults[1].lineSubtotal, equals(Decimal.parse('59.97')));
      expect(result.lineResults[2].lineSubtotal, equals(Decimal.parse('0.30')));
      expect(result.subtotal, equals(Decimal.parse('96.52')));
      expect(result.totalAmount, equals(Decimal.parse('96.52')));
    });

    test('handles empty cart', () {
      final result = BillingEngine.calculate(items: []);
      expect(result.lineResults, isEmpty);
      expect(result.subtotal, equals(Decimal.zero));
      expect(result.totalAmount, equals(Decimal.zero));
    });
  });

  group('BillingEngine - Slice 2: Line-Item Discounts', () {
    test('applies percentage line discount correctly', () {
      final items = [
        CartItemInput(
          productId: 'p1',
          productName: 'Rice Bag',
          unitPrice: Decimal.parse('100.00'),
          quantity: Decimal.parse('2'),
          discount: Discount.percentage(Decimal.parse('10')),
        ),
      ];

      final result = BillingEngine.calculate(items: items);

      expect(result.lineResults.first.lineSubtotal, equals(Decimal.parse('200.00')));
      expect(result.lineResults.first.lineDiscount, equals(Decimal.parse('20.00')));
      expect(result.lineResults.first.lineTotal, equals(Decimal.parse('180.00')));
      expect(result.subtotal, equals(Decimal.parse('200.00')));
      expect(result.totalDiscount, equals(Decimal.parse('20.00')));
      expect(result.totalAmount, equals(Decimal.parse('180.00')));
    });

    test('applies fixed line discount correctly', () {
      final items = [
        CartItemInput(
          productId: 'p2',
          productName: 'Cooking Oil',
          unitPrice: Decimal.parse('50.00'),
          quantity: Decimal.parse('1'),
          discount: Discount.fixed(Decimal.parse('15.00')),
        ),
      ];

      final result = BillingEngine.calculate(items: items);

      expect(result.lineResults.first.lineDiscount, equals(Decimal.parse('15.00')));
      expect(result.lineResults.first.lineTotal, equals(Decimal.parse('35.00')));
      expect(result.totalDiscount, equals(Decimal.parse('15.00')));
      expect(result.totalAmount, equals(Decimal.parse('35.00')));
    });

    test('clamps fixed discount to line subtotal when discount exceeds subtotal', () {
      final items = [
        CartItemInput(
          productId: 'p3',
          productName: 'Biscuit',
          unitPrice: Decimal.parse('10.00'),
          quantity: Decimal.parse('1'),
          discount: Discount.fixed(Decimal.parse('25.00')),
        ),
      ];

      final result = BillingEngine.calculate(items: items);

      expect(result.lineResults.first.lineDiscount, equals(Decimal.parse('10.00')));
      expect(result.lineResults.first.lineTotal, equals(Decimal.zero));
      expect(result.totalDiscount, equals(Decimal.parse('10.00')));
      expect(result.totalAmount, equals(Decimal.zero));
    });

    test('handles 100% discount correctly', () {
      final items = [
        CartItemInput(
          productId: 'p4',
          productName: 'Promo Sample',
          unitPrice: Decimal.parse('45.00'),
          quantity: Decimal.parse('2'),
          discount: Discount.percentage(Decimal.parse('100')),
        ),
      ];

      final result = BillingEngine.calculate(items: items);

      expect(result.lineResults.first.lineDiscount, equals(Decimal.parse('90.00')));
      expect(result.lineResults.first.lineTotal, equals(Decimal.zero));
      expect(result.totalAmount, equals(Decimal.zero));
    });
  });

  group('BillingEngine - Slice 3: Invoice-Level Discounts', () {
    test('applies invoice percentage discount on post-line-discount amount', () {
      final items = [
        CartItemInput(
          productId: 'p1',
          productName: 'Item 1',
          unitPrice: Decimal.parse('100.00'),
          quantity: Decimal.parse('1'),
          discount: Discount.fixed(Decimal.parse('10.00')),
        ),
        CartItemInput(
          productId: 'p2',
          productName: 'Item 2',
          unitPrice: Decimal.parse('100.00'),
          quantity: Decimal.parse('1'),
        ),
      ];

      final result = BillingEngine.calculate(
        items: items,
        invoiceDiscount: Discount.percentage(Decimal.parse('10')),
      );

      expect(result.subtotal, equals(Decimal.parse('200.00')));
      expect(result.lineDiscountTotal, equals(Decimal.parse('10.00')));
      expect(result.invoiceDiscountAmount, equals(Decimal.parse('19.00')));
      expect(result.totalDiscount, equals(Decimal.parse('29.00')));
      expect(result.totalAmount, equals(Decimal.parse('171.00')));
    });

    test('applies fixed invoice discount and clamps to post-line-discount amount', () {
      final items = [
        CartItemInput(
          productId: 'p1',
          productName: 'Sugar',
          unitPrice: Decimal.parse('40.00'),
          quantity: Decimal.parse('1'),
        ),
      ];

      final result = BillingEngine.calculate(
        items: items,
        invoiceDiscount: Discount.fixed(Decimal.parse('50.00')),
      );

      expect(result.subtotal, equals(Decimal.parse('40.00')));
      expect(result.invoiceDiscountAmount, equals(Decimal.parse('40.00')));
      expect(result.totalDiscount, equals(Decimal.parse('40.00')));
      expect(result.totalAmount, equals(Decimal.zero));
    });
  });

  group('BillingEngine - Slice 4: Tax Calculations (GST Slabs)', () {
    test('calculates tax-exclusive pricing correctly', () {
      final items = [
        CartItemInput(
          productId: 't1',
          productName: 'Shampoo',
          unitPrice: Decimal.parse('100.00'),
          quantity: Decimal.parse('1'),
          taxRate: Decimal.parse('18'),
        ),
      ];

      final result = BillingEngine.calculate(
        items: items,
        taxMode: TaxMode.exclusive,
      );

      expect(result.subtotal, equals(Decimal.parse('100.00')));
      expect(result.taxableAmount, equals(Decimal.parse('100.00')));
      expect(result.totalTax, equals(Decimal.parse('18.00')));
      expect(result.totalAmount, equals(Decimal.parse('118.00')));
      expect(result.lineResults.first.taxAmount, equals(Decimal.parse('18.00')));
      expect(result.lineResults.first.lineTotal, equals(Decimal.parse('118.00')));
    });

    test('calculates tax-inclusive pricing correctly', () {
      final items = [
        CartItemInput(
          productId: 't2',
          productName: 'Detergent',
          unitPrice: Decimal.parse('118.00'),
          quantity: Decimal.parse('1'),
          taxRate: Decimal.parse('18'),
        ),
      ];

      final result = BillingEngine.calculate(
        items: items,
        taxMode: TaxMode.inclusive,
      );

      expect(result.subtotal, equals(Decimal.parse('118.00')));
      expect(result.taxableAmount, equals(Decimal.parse('100.00')));
      expect(result.totalTax, equals(Decimal.parse('18.00')));
      expect(result.totalAmount, equals(Decimal.parse('118.00')));
      expect(result.lineResults.first.taxAmount, equals(Decimal.parse('18.00')));
      expect(result.lineResults.first.lineTotal, equals(Decimal.parse('118.00')));
    });

    test('groups multi-tier tax breakdown by slab', () {
      final items = [
        CartItemInput(
          productId: 'm1',
          productName: 'Milk',
          unitPrice: Decimal.parse('50.00'),
          quantity: Decimal.parse('1'),
          taxRate: Decimal.zero,
        ),
        CartItemInput(
          productId: 'm2',
          productName: 'Cooking Butter',
          unitPrice: Decimal.parse('100.00'),
          quantity: Decimal.parse('1'),
          taxRate: Decimal.parse('5'),
        ),
        CartItemInput(
          productId: 'm3',
          productName: 'Chocolates',
          unitPrice: Decimal.parse('200.00'),
          quantity: Decimal.parse('1'),
          taxRate: Decimal.parse('18'),
        ),
      ];

      final result = BillingEngine.calculate(
        items: items,
        taxMode: TaxMode.exclusive,
      );

      expect(result.subtotal, equals(Decimal.parse('350.00')));
      expect(result.totalTax, equals(Decimal.parse('41.00')));
      expect(result.totalAmount, equals(Decimal.parse('391.00')));
      expect(result.taxBreakdown.containsKey('5%'), isTrue);
      expect(result.taxBreakdown['5%']!.taxAmount, equals(Decimal.parse('5.00')));
      expect(result.taxBreakdown.containsKey('18%'), isTrue);
      expect(result.taxBreakdown['18%']!.taxAmount, equals(Decimal.parse('36.00')));
    });
  });

  group('BillingEngine - Slice 5: Rounding & Edge Cases', () {
    test('rounds up to nearest whole currency unit when fractional part >= 0.50', () {
      // 96.52 -> roundedTotal: 97.00, roundingAdjustment: +0.48
      final items = [
        CartItemInput(
          productId: 'r1',
          productName: 'Item A',
          unitPrice: Decimal.parse('96.52'),
          quantity: Decimal.parse('1'),
        ),
      ];

      final result = BillingEngine.calculate(
        items: items,
        roundingStrategy: RoundingStrategy.toNearestInteger,
      );

      expect(result.totalAmount, equals(Decimal.parse('96.52')));
      expect(result.roundedTotal, equals(Decimal.parse('97')));
      expect(result.roundingAdjustment, equals(Decimal.parse('0.48')));
    });

    test('rounds down to nearest whole currency unit when fractional part < 0.50', () {
      // 96.42 -> roundedTotal: 96.00, roundingAdjustment: -0.42
      final items = [
        CartItemInput(
          productId: 'r2',
          productName: 'Item B',
          unitPrice: Decimal.parse('96.42'),
          quantity: Decimal.parse('1'),
        ),
      ];

      final result = BillingEngine.calculate(
        items: items,
        roundingStrategy: RoundingStrategy.toNearestInteger,
      );

      expect(result.totalAmount, equals(Decimal.parse('96.42')));
      expect(result.roundedTotal, equals(Decimal.parse('96')));
      expect(result.roundingAdjustment, equals(Decimal.parse('-0.42')));
    });

    test('handles fractional grocery weights (e.g. 0.375 kg of Ginger)', () {
      // 0.375 kg @ 120.00/kg = 45.00 exactly
      final items = [
        CartItemInput(
          productId: 'r3',
          productName: 'Fresh Ginger',
          unitPrice: Decimal.parse('120.00'),
          quantity: Decimal.parse('0.375'),
        ),
      ];

      final result = BillingEngine.calculate(items: items);

      expect(result.lineResults.first.lineSubtotal, equals(Decimal.parse('45.00')));
      expect(result.totalAmount, equals(Decimal.parse('45.00')));
    });

    test('handles zero price and zero quantity items safely without errors', () {
      final items = [
        CartItemInput(
          productId: 'z1',
          productName: 'Free Plastic Bag',
          unitPrice: Decimal.zero,
          quantity: Decimal.parse('2'),
        ),
        CartItemInput(
          productId: 'z2',
          productName: 'Zero Quantity Entry',
          unitPrice: Decimal.parse('100.00'),
          quantity: Decimal.zero,
        ),
      ];

      final result = BillingEngine.calculate(items: items);

      expect(result.subtotal, equals(Decimal.zero));
      expect(result.totalAmount, equals(Decimal.zero));
      expect(result.roundedTotal, equals(Decimal.zero));
    });
  });
}
