import 'package:billing_engine/billing_engine.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a line item inside the mobile shopping cart.
class CartLineItem {
  final String productId;
  final String productName;
  final Decimal unitPrice;
  final Decimal quantity;
  final String? barcode;
  final String unit;
  final Discount? discount;
  final Decimal? taxRate;

  const CartLineItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.barcode,
    this.unit = 'pcs',
    this.discount,
    this.taxRate,
  });

  CartLineItem copyWith({
    String? productId,
    String? productName,
    Decimal? unitPrice,
    Decimal? quantity,
    String? barcode,
    String? unit,
    Discount? discount,
    Decimal? taxRate,
  }) {
    return CartLineItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      discount: discount ?? this.discount,
      taxRate: taxRate ?? this.taxRate,
    );
  }

  CartItemInput toBillingInput() {
    return CartItemInput(
      productId: productId,
      productName: productName,
      unitPrice: unitPrice,
      quantity: quantity,
      discount: discount,
      taxRate: taxRate,
    );
  }
}

/// Immutable state snapshot of the active cashier cart.
class CartState {
  final List<CartLineItem> items;
  final Discount? invoiceDiscount;
  final TaxMode taxMode;
  final RoundingStrategy roundingStrategy;
  final BillingCalculationResult calculationResult;

  CartState({
    required this.items,
    this.invoiceDiscount,
    this.taxMode = TaxMode.exclusive,
    this.roundingStrategy = RoundingStrategy.toNearestInteger,
    BillingCalculationResult? calculationResult,
  }) : calculationResult = calculationResult ??
            BillingEngine.calculate(
              items: items.map((i) => i.toBillingInput()).toList(),
              invoiceDiscount: invoiceDiscount,
              taxMode: taxMode,
              roundingStrategy: roundingStrategy,
            );

  int get itemCount => items.length;

  Decimal get totalQuantity => items.fold(
        Decimal.zero,
        (sum, item) => sum + item.quantity,
      );

  Decimal get subtotal => calculationResult.subtotal;
  Decimal get totalDiscount => calculationResult.totalDiscount;
  Decimal get totalTax => calculationResult.totalTax;
  Decimal get totalAmount => calculationResult.totalAmount;
  Decimal get roundedTotal => calculationResult.roundedTotal;
  Decimal get netPayable => roundedTotal;
  Decimal get roundingAdjustment => calculationResult.roundingAdjustment;

  CartState copyWith({
    List<CartLineItem>? items,
    Discount? invoiceDiscount,
    TaxMode? taxMode,
    RoundingStrategy? roundingStrategy,
  }) {
    final newItems = items ?? this.items;
    final newInvoiceDiscount = invoiceDiscount ?? this.invoiceDiscount;
    final newTaxMode = taxMode ?? this.taxMode;
    final newRoundingStrategy = roundingStrategy ?? this.roundingStrategy;

    return CartState(
      items: newItems,
      invoiceDiscount: newInvoiceDiscount,
      taxMode: newTaxMode,
      roundingStrategy: newRoundingStrategy,
    );
  }
}

/// Riverpod StateNotifier managing the cart lifecycle optimistically.
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState(items: const []));

  /// Adds a product to the cart. If already present, increments quantity.
  void addItem({
    required String productId,
    required String productName,
    required Decimal unitPrice,
    Decimal? quantity,
    String? barcode,
    String? unit,
    Discount? discount,
    Decimal? taxRate,
  }) {
    final addQty = quantity ?? Decimal.one;
    final existingIndex = state.items.indexWhere((i) => i.productId == productId);

    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final updated = existing.copyWith(quantity: existing.quantity + addQty);
      final updatedList = List<CartLineItem>.from(state.items);
      updatedList[existingIndex] = updated;
      state = state.copyWith(items: updatedList);
    } else {
      final newItem = CartLineItem(
        productId: productId,
        productName: productName,
        unitPrice: unitPrice,
        quantity: addQty,
        barcode: barcode,
        unit: unit ?? 'pcs',
        discount: discount,
        taxRate: taxRate,
      );
      state = state.copyWith(items: [...state.items, newItem]);
    }
  }

  /// Increments item quantity by given step (default 1).
  void incrementQuantity(String productId, [Decimal? step]) {
    final delta = step ?? Decimal.one;
    final index = state.items.indexWhere((i) => i.productId == productId);
    if (index >= 0) {
      final item = state.items[index];
      final updatedList = List<CartLineItem>.from(state.items);
      updatedList[index] = item.copyWith(quantity: item.quantity + delta);
      state = state.copyWith(items: updatedList);
    }
  }

  /// Decrements item quantity. If quantity drops <= 0, item is removed.
  void decrementQuantity(String productId, [Decimal? step]) {
    final delta = step ?? Decimal.one;
    final index = state.items.indexWhere((i) => i.productId == productId);
    if (index >= 0) {
      final item = state.items[index];
      final remaining = item.quantity - delta;
      if (remaining <= Decimal.zero) {
        removeItem(productId);
      } else {
        final updatedList = List<CartLineItem>.from(state.items);
        updatedList[index] = item.copyWith(quantity: remaining);
        state = state.copyWith(items: updatedList);
      }
    }
  }

  /// Sets item quantity directly (e.g. from Numpad input).
  void setQuantity(String productId, Decimal newQuantity) {
    if (newQuantity <= Decimal.zero) {
      removeItem(productId);
      return;
    }
    final index = state.items.indexWhere((i) => i.productId == productId);
    if (index >= 0) {
      final updatedList = List<CartLineItem>.from(state.items);
      updatedList[index] = state.items[index].copyWith(quantity: newQuantity);
      state = state.copyWith(items: updatedList);
    }
  }

  /// Removes an item from the cart.
  void removeItem(String productId) {
    final updatedList = state.items.where((i) => i.productId != productId).toList();
    state = state.copyWith(items: updatedList);
  }

  /// Empties all items from the cart.
  void clearCart() {
    state = state.copyWith(items: const []);
  }

  /// Sets an overall invoice-level discount.
  void setInvoiceDiscount(Discount? discount) {
    state = state.copyWith(invoiceDiscount: discount);
  }
}

/// Global provider for the active cashier cart.
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

