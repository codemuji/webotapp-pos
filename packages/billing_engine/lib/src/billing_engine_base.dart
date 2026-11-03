import 'package:decimal/decimal.dart';
import 'models.dart';

/// Pure Dart deterministic calculation engine for Grocery POS.
class BillingEngine {
  BillingEngine._();

  /// Calculates invoice totals, line subtotals, discounts, taxes, and overall amounts using Decimal precision.
  static BillingCalculationResult calculate({
    required List<CartItemInput> items,
    Discount? invoiceDiscount,
    TaxMode taxMode = TaxMode.exclusive,
    RoundingStrategy roundingStrategy = RoundingStrategy.none,
  }) {
    var subtotal = Decimal.zero;
    var lineDiscountTotal = Decimal.zero;
    var totalTaxable = Decimal.zero;
    var totalTax = Decimal.zero;
    final taxBreakdown = <String, TaxBreakdownDetail>{};
    final lineResults = <LineCalculationResult>[];

    for (final item in items) {
      final lineSubtotal = item.quantity * item.unitPrice;
      subtotal += lineSubtotal;

      final lineDiscount = item.discount?.calculateDiscount(lineSubtotal) ?? Decimal.zero;
      lineDiscountTotal += lineDiscount;

      final netBeforeTax = lineSubtotal - lineDiscount;
      final rate = item.taxRate ?? Decimal.zero;

      Decimal lineTaxable;
      Decimal lineTax;
      Decimal lineTotal;

      if (taxMode == TaxMode.exclusive) {
        lineTaxable = netBeforeTax;
        if (rate > Decimal.zero) {
          final rationalTax = (lineTaxable * rate) / Decimal.fromInt(100);
          lineTax = rationalTax.toDecimal(scaleOnInfinitePrecision: 4);
        } else {
          lineTax = Decimal.zero;
        }
        lineTotal = lineTaxable + lineTax;
      } else {
        // Tax Inclusive
        if (rate > Decimal.zero) {
          final rateMultiplier = Decimal.one + ((rate / Decimal.fromInt(100)).toDecimal(scaleOnInfinitePrecision: 6));
          final rationalTaxable = netBeforeTax / rateMultiplier;
          lineTaxable = rationalTaxable.toDecimal(scaleOnInfinitePrecision: 4);
          lineTax = netBeforeTax - lineTaxable;
        } else {
          lineTaxable = netBeforeTax;
          lineTax = Decimal.zero;
        }
        lineTotal = netBeforeTax;
      }

      totalTaxable += lineTaxable;
      totalTax += lineTax;

      // Group tax breakdown by rate
      if (rate > Decimal.zero) {
        final rateKey = '${rate.toString()}%';
        final existing = taxBreakdown[rateKey];
        if (existing == null) {
          taxBreakdown[rateKey] = TaxBreakdownDetail(
            rate: rate,
            taxableAmount: lineTaxable,
            taxAmount: lineTax,
          );
        } else {
          taxBreakdown[rateKey] = TaxBreakdownDetail(
            rate: rate,
            taxableAmount: existing.taxableAmount + lineTaxable,
            taxAmount: existing.taxAmount + lineTax,
          );
        }
      }

      lineResults.add(
        LineCalculationResult(
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          lineSubtotal: lineSubtotal,
          lineDiscount: lineDiscount,
          taxableAmount: lineTaxable,
          taxRate: rate,
          taxAmount: lineTax,
          lineTotal: lineTotal,
        ),
      );
    }

    final postLineDiscountTotal = subtotal - lineDiscountTotal;
    final invoiceDiscountAmount = invoiceDiscount != null
        ? invoiceDiscount.calculateDiscount(postLineDiscountTotal)
        : Decimal.zero;

    final totalDiscount = lineDiscountTotal + invoiceDiscountAmount;

    Decimal totalAmount;
    if (taxMode == TaxMode.exclusive) {
      totalAmount = (subtotal - totalDiscount) + totalTax;
    } else {
      totalAmount = subtotal - totalDiscount;
    }

    if (totalAmount < Decimal.zero) {
      totalAmount = Decimal.zero;
    }

    Decimal roundedTotal;
    Decimal roundingAdjustment;

    if (roundingStrategy == RoundingStrategy.toNearestInteger) {
      if (totalAmount == Decimal.zero) {
        roundedTotal = Decimal.zero;
        roundingAdjustment = Decimal.zero;
      } else {
        final roundedBigInt = (totalAmount + Decimal.parse('0.5')).toBigInt();
        roundedTotal = Decimal.fromBigInt(roundedBigInt);
        roundingAdjustment = roundedTotal - totalAmount;
      }
    } else {
      roundedTotal = totalAmount;
      roundingAdjustment = Decimal.zero;
    }

    return BillingCalculationResult(
      lineResults: lineResults,
      subtotal: subtotal,
      lineDiscountTotal: lineDiscountTotal,
      invoiceDiscountAmount: invoiceDiscountAmount,
      totalDiscount: totalDiscount,
      taxableAmount: totalTaxable,
      totalTax: totalTax,
      taxBreakdown: taxBreakdown,
      totalAmount: totalAmount,
      roundedTotal: roundedTotal,
      roundingAdjustment: roundingAdjustment,
    );
  }
}
