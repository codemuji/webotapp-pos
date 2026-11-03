import 'package:decimal/decimal.dart';

/// Pure calculator for cash tender amounts, change due, and quick tender denomination suggestions.
class CashTenderCalculator {
  /// Calculates change due from tendered cash amount against net payable.
  /// Throws [ArgumentError] if tendered is strictly less than netPayable.
  static Decimal calculateChange({
    required Decimal netPayable,
    required Decimal tendered,
  }) {
    if (tendered < netPayable) {
      throw ArgumentError('Tendered amount ($tendered) cannot be less than net payable ($netPayable).');
    }
    return tendered - netPayable;
  }

  /// Checks if tendered cash is sufficient to satisfy the net payable.
  static bool isSufficient({
    required Decimal netPayable,
    required Decimal tendered,
  }) {
    return tendered >= netPayable;
  }

  /// Generates intuitive quick-tender cash denominations tailored to the bill amount:
  /// 1. Exact bill amount
  /// 2. Next multiple of 50 or 100
  /// 3. Next standard currency notes (₹100, ₹200, ₹500, ₹1000, ₹2000)
  static List<Decimal> getQuickTenderSuggestions(Decimal netPayable) {
    if (netPayable <= Decimal.zero) {
      return [Decimal.zero];
    }

    final suggestions = <Decimal>{netPayable};
    final netDouble = double.parse(netPayable.toString());

    // Next multiple of 50
    final next50 = ((netDouble / 50.0).ceil() * 50).toDouble();
    if (next50 >= netDouble) {
      suggestions.add(Decimal.parse(next50.toStringAsFixed(2)));
    }

    // Next multiple of 100
    final next100 = ((netDouble / 100.0).ceil() * 100).toDouble();
    if (next100 >= netDouble) {
      suggestions.add(Decimal.parse(next100.toStringAsFixed(2)));
    }

    // Standard cash notes: 100, 200, 500, 1000, 2000
    const standardNotes = [100.0, 200.0, 500.0, 1000.0, 2000.0];
    for (final note in standardNotes) {
      if (note >= netDouble) {
        suggestions.add(Decimal.parse(note.toStringAsFixed(2)));
      }
    }

    final sortedList = suggestions.toList()..sort((a, b) => a.compareTo(b));
    return sortedList;
  }
}
