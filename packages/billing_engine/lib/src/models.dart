import 'package:decimal/decimal.dart';

/// Type of discount applied to a line item or invoice.
enum DiscountType { percentage, fixed }

/// Represents whether catalog prices include tax or have tax added on top.
enum TaxMode { exclusive, inclusive }

/// Financial rounding strategy for the final payable amount.
enum RoundingStrategy { none, toNearestInteger }

/// Detail for a specific tax bracket in the invoice summary.
class TaxBreakdownDetail {
  final Decimal rate;
  final Decimal taxableAmount;
  final Decimal taxAmount;

  const TaxBreakdownDetail({
    required this.rate,
    required this.taxableAmount,
    required this.taxAmount,
  });
}

/// Represents a percentage or fixed amount discount.
class Discount {
  final DiscountType type;
  final Decimal value;

  const Discount.percentage(this.value) : type = DiscountType.percentage;
  const Discount.fixed(this.value) : type = DiscountType.fixed;

  /// Calculates the discount deduction against a given base amount.
  Decimal calculateDiscount(Decimal baseAmount) {
    if (baseAmount <= Decimal.zero || value <= Decimal.zero) {
      return Decimal.zero;
    }

    if (type == DiscountType.percentage) {
      if (value >= Decimal.fromInt(100)) {
        return baseAmount;
      }
      final rational = (baseAmount * value) / Decimal.fromInt(100);
      return rational.toDecimal(scaleOnInfinitePrecision: 4);
    } else {
      return value > baseAmount ? baseAmount : value;
    }
  }
}

/// Represents a line item input in the shopping cart.
class CartItemInput {
  final String productId;
  final String productName;
  final Decimal unitPrice;
  final Decimal quantity;
  final Discount? discount;
  final Decimal? taxRate;

  const CartItemInput({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.discount,
    this.taxRate,
  });
}

/// Calculation output for an individual line item.
class LineCalculationResult {
  final String productId;
  final String productName;
  final Decimal quantity;
  final Decimal unitPrice;
  final Decimal lineSubtotal;
  final Decimal lineDiscount;
  final Decimal taxableAmount;
  final Decimal taxRate;
  final Decimal taxAmount;
  final Decimal lineTotal;

  const LineCalculationResult({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineSubtotal,
    required this.lineDiscount,
    required this.taxableAmount,
    required this.taxRate,
    required this.taxAmount,
    required this.lineTotal,
  });
}

/// Overall calculation result for the invoice/cart.
class BillingCalculationResult {
  final List<LineCalculationResult> lineResults;
  final Decimal subtotal;
  final Decimal lineDiscountTotal;
  final Decimal invoiceDiscountAmount;
  final Decimal totalDiscount;
  final Decimal taxableAmount;
  final Decimal totalTax;
  final Map<String, TaxBreakdownDetail> taxBreakdown;
  final Decimal totalAmount;
  final Decimal roundedTotal;
  final Decimal roundingAdjustment;

  const BillingCalculationResult({
    required this.lineResults,
    required this.subtotal,
    required this.lineDiscountTotal,
    required this.invoiceDiscountAmount,
    required this.totalDiscount,
    required this.taxableAmount,
    required this.totalTax,
    required this.taxBreakdown,
    required this.totalAmount,
    required this.roundedTotal,
    required this.roundingAdjustment,
  });
}
