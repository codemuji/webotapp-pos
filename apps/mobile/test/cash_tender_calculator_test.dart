import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/checkout/cash_tender_calculator.dart';

void main() {
  group('CashTenderCalculator - Slice 1: Change Calculation & Quick Tender Suggestions', () {
    test('calculates exact change due when tendered amount exceeds net payable', () {
      final netPayable = Decimal.parse('342.50');
      final tendered = Decimal.parse('500.00');

      final change = CashTenderCalculator.calculateChange(
        netPayable: netPayable,
        tendered: tendered,
      );

      expect(change, equals(Decimal.parse('157.50')));
    });

    test('returns Decimal.zero change when exact amount tendered', () {
      final netPayable = Decimal.parse('250.00');
      final tendered = Decimal.parse('250.00');

      final change = CashTenderCalculator.calculateChange(
        netPayable: netPayable,
        tendered: tendered,
      );

      expect(change, equals(Decimal.zero));
    });

    test('throws ArgumentError when tendered amount is less than net payable', () {
      final netPayable = Decimal.parse('500.00');
      final tendered = Decimal.parse('400.00');

      expect(
        () => CashTenderCalculator.calculateChange(
          netPayable: netPayable,
          tendered: tendered,
        ),
        throwsArgumentError,
      );
    });

    test('generates quick tender denominations based on bill total', () {
      // For net payable of ₹184.00, suggestions should include:
      // Exact (₹184), nearest ₹50 (₹200), nearest ₹500 (₹500)
      final suggestions = CashTenderCalculator.getQuickTenderSuggestions(
        Decimal.parse('184.00'),
      );

      expect(suggestions, contains(Decimal.parse('184.00'))); // Exact
      expect(suggestions, contains(Decimal.parse('200.00'))); // Round up to 50/100
      expect(suggestions, contains(Decimal.parse('500.00'))); // Standard currency note
      expect(suggestions.every((s) => s >= Decimal.parse('184.00')), isTrue);
    });

    test('isSufficient returns true only if tendered amount is greater than or equal to net payable', () {
      final netPayable = Decimal.parse('120.00');

      expect(CashTenderCalculator.isSufficient(netPayable: netPayable, tendered: Decimal.parse('100.00')), isFalse);
      expect(CashTenderCalculator.isSufficient(netPayable: netPayable, tendered: Decimal.parse('120.00')), isTrue);
      expect(CashTenderCalculator.isSufficient(netPayable: netPayable, tendered: Decimal.parse('200.00')), isTrue);
    });
  });
}
