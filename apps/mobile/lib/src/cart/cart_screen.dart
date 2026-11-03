import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/tactile_button.dart';
import 'cart_state.dart';
import 'quantity_numpad_dialog.dart';

/// Cashier Cart Screen featuring Emil Kowalski's design engineering principles:
/// Zero-layout-shift fixed rows, tactile micro-feedback on buttons, and high-contrast totals.
class CartScreen extends ConsumerWidget {
  final VoidCallback? onCheckoutPressed;

  const CartScreen({
    super.key,
    this.onCheckoutPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      appBar: AppBar(
        title: const Text(
          'Counter POS',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          if (cart.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TactileButton(
                onPressed: () => ref.read(cartProvider.notifier).clearCart(),
                minWidth: 44,
                minHeight: 44,
                child: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444)),
              ),
            ),
        ],
      ),
      body: cart.items.isEmpty
          ? const _EmptyCartView()
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return _CartItemRow(
                        key: Key('cart_item_${item.productId}'),
                        item: item,
                      );
                    },
                  ),
                ),
                _CartBottomBar(
                  cart: cart,
                  onCheckoutPressed: onCheckoutPressed,
                ),
              ],
            ),
    );
  }
}

class _EmptyCartView extends StatelessWidget {
  const _EmptyCartView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_basket_outlined,
              size: 48,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Cart is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Scan products or search to begin checkout',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemRow extends ConsumerWidget {
  final CartLineItem item;

  const _CartItemRow({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lineTotal = item.unitPrice * item.quantity;

    return Container(
      height: 72.0, // Fixed height for zero layout shifts
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // Stepper controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TactileButton(
                key: Key('btn_decrement_${item.productId}'),
                minWidth: 36,
                minHeight: 36,
                onPressed: () {
                  ref.read(cartProvider.notifier).decrementQuantity(item.productId);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.remove, size: 16, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () async {
                  final newQty = await showQuantityNumpadDialog(
                    context: context,
                    productName: item.productName,
                    initialQuantity: item.quantity,
                    unit: item.unit,
                  );
                  if (newQty != null) {
                    ref.read(cartProvider.notifier).setQuantity(item.productId, newQty);
                  }
                },
                child: Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.quantity.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TactileButton(
                key: Key('btn_increment_${item.productId}'),
                minWidth: 36,
                minHeight: 36,
                onPressed: () {
                  ref.read(cartProvider.notifier).incrementQuantity(item.productId);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, size: 16, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Line total
          SizedBox(
            width: 76,
            child: Text(
              '₹${lineTotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartBottomBar extends StatelessWidget {
  final CartState cart;
  final VoidCallback? onCheckoutPressed;

  const _CartBottomBar({
    required this.cart,
    this.onCheckoutPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtotal',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
                Text(
                  '₹${cart.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ],
            ),
            if (cart.totalTax > Decimal.zero) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Taxes (GST)',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  Text(
                    '₹${cart.totalTax.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL PAYABLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '₹${cart.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                TactileButton(
                  onPressed: cart.items.isEmpty ? null : onCheckoutPressed,
                  minWidth: 160,
                  minHeight: 52,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: cart.items.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Checkout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
