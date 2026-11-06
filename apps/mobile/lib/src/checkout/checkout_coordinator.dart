import 'dart:convert';
import 'package:database/database.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import '../cart/cart_state.dart';
import 'cash_tender_calculator.dart';

/// Result summary of an atomically processed checkout transaction.
class CheckoutResult {
  final String invoiceId;
  final String invoiceNumber;
  final Decimal totalAmount;
  final Decimal tenderedAmount;
  final Decimal changeDue;
  final String paymentMethod;
  final DateTime createdAt;

  const CheckoutResult({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.tenderedAmount,
    required this.changeDue,
    required this.paymentMethod,
    required this.createdAt,
  });
}

/// Coordinates the atomic checkout transaction:
/// - Validates cart contents and tender amounts
/// - Creates immutable point-in-time invoice and line item records
/// - Records inventory deduction delta movements
/// - Enqueues an offline-first transaction into the sync queue
class CheckoutCoordinator {
  final AppDatabase database;

  const CheckoutCoordinator({required this.database});

  /// Atomically commits a completed checkout to SQLite.
  Future<CheckoutResult> processCheckout({
    required CartState cart,
    required String paymentMethod,
    required Decimal tenderedAmount,
    required String employeeId,
    required String deviceId,
    String? customerId,
  }) async {
    if (cart.items.isEmpty) {
      throw StateError('Cannot checkout an empty cart.');
    }

    final total = cart.roundedTotal;
    Decimal changeDue = Decimal.zero;

    if (paymentMethod == 'cash') {
      if (tenderedAmount < total) {
        throw ArgumentError('Tendered amount ($tenderedAmount) is less than total ($total).');
      }
      changeDue = CashTenderCalculator.calculateChange(
        netPayable: total,
        tendered: tenderedAmount,
      );
    } else {
      // For digital/card/credit payments, tendered equals total
      changeDue = Decimal.zero;
    }

    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final invoiceId = 'inv-$timestamp';
    final datePart = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePart = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final invoiceNumber = 'INV-$datePart-$timePart';

    // 1. Build InvoicesCompanion
    final invoiceCompanion = InvoicesCompanion.insert(
      id: invoiceId,
      invoiceNumber: invoiceNumber,
      deviceId: deviceId,
      employeeId: employeeId,
      customerId: Value(customerId),
      subtotal: double.parse(cart.subtotal.toString()),
      discount: Value(double.parse(cart.totalDiscount.toString())),
      taxAmount: Value(double.parse(cart.totalTax.toString())),
      totalAmount: double.parse(total.toString()),
      paymentMethod: paymentMethod,
      createdAt: now,
      syncStatus: const Value('pending'),
    );

    // 2. Build InvoiceItemsCompanion list
    final itemCompanions = <InvoiceItemsCompanion>[];
    final movementCompanions = <InventoryMovementsCompanion>[];
    final lineResults = cart.calculationResult.lineResults;

    for (int i = 0; i < cart.items.length; i++) {
      final item = cart.items[i];
      final itemId = 'inv-item-$timestamp-$i';
      final movementId = 'mov-$timestamp-$i';

      final calc = i < lineResults.length ? lineResults[i] : null;
      final lineDiscount = calc != null
          ? double.parse(calc.lineDiscount.toString())
          : (item.discount != null ? double.parse(item.discount!.value.toString()) : 0.0);
      final lineTax = calc != null
          ? double.parse(calc.taxAmount.toString())
          : (item.taxRate != null ? double.parse(item.taxRate!.toString()) : 0.0);
      final lineTotal = calc != null
          ? double.parse(calc.lineTotal.toString())
          : double.parse((item.unitPrice * item.quantity).toString());

      itemCompanions.add(
        InvoiceItemsCompanion.insert(
          id: itemId,
          invoiceId: invoiceId,
          productId: Value(item.productId),
          productName: item.productName,
          barcode: Value(item.barcode),
          quantity: double.parse(item.quantity.toString()),
          unitPrice: double.parse(item.unitPrice.toString()),
          discount: Value(lineDiscount),
          taxAmount: Value(lineTax),
          lineTotal: lineTotal,
        ),
      );

      movementCompanions.add(
        InventoryMovementsCompanion.insert(
          id: movementId,
          productId: item.productId,
          deltaQuantity: -double.parse(item.quantity.toString()),
          reason: 'sale',
          referenceId: Value(invoiceId),
          createdAt: now,
        ),
      );
    }

    // 3. Build SyncQueueCompanion
    final syncPayload = jsonEncode({
      'invoice': {
        'id': invoiceId,
        'invoiceNumber': invoiceNumber,
        'deviceId': deviceId,
        'employeeId': employeeId,
        'customerId': customerId,
        'subtotal': double.parse(cart.subtotal.toString()),
        'discount': double.parse(cart.totalDiscount.toString()),
        'taxAmount': double.parse(cart.totalTax.toString()),
        'totalAmount': double.parse(total.toString()),
        'paymentMethod': paymentMethod,
        'createdAt': now.toIso8601String(),
      },
      'items': [
        for (int i = 0; i < cart.items.length; i++)
          {
            'id': 'inv-item-$timestamp-$i',
            'productId': cart.items[i].productId,
            'productName': cart.items[i].productName,
            'barcode': cart.items[i].barcode,
            'quantity': double.parse(cart.items[i].quantity.toString()),
            'unitPrice': double.parse(cart.items[i].unitPrice.toString()),
            'discount': i < lineResults.length ? double.parse(lineResults[i].lineDiscount.toString()) : 0.0,
            'taxAmount': i < lineResults.length ? double.parse(lineResults[i].taxAmount.toString()) : 0.0,
            'lineTotal': i < lineResults.length
                ? double.parse(lineResults[i].lineTotal.toString())
                : double.parse((cart.items[i].unitPrice * cart.items[i].quantity).toString()),
          }
      ],
    });

    final syncQueueItem = SyncQueueCompanion.insert(
      id: 'sync-$timestamp',
      transactionId: invoiceId,
      operation: 'insert_invoice',
      payload: syncPayload,
      status: const Value('pending'),
      createdAt: now,
      updatedAt: now,
    );

    // 4. Atomic transaction execution
    await database.recordCheckoutTransaction(
      invoice: invoiceCompanion,
      items: itemCompanions,
      movements: movementCompanions,
      syncQueueItem: syncQueueItem,
    );

    return CheckoutResult(
      invoiceId: invoiceId,
      invoiceNumber: invoiceNumber,
      totalAmount: total,
      tenderedAmount: tenderedAmount,
      changeDue: changeDue,
      paymentMethod: paymentMethod,
      createdAt: now,
    );
  }
}

