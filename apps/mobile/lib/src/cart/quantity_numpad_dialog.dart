import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import '../widgets/tactile_button.dart';

/// Opens the Quantity Numpad modal implementing Emil Kowalski's dialog emergence standard:
/// starts from scale(0.95) with simultaneous opacity fade (never pops from scale 0).
Future<Decimal?> showQuantityNumpadDialog({
  required BuildContext context,
  required String productName,
  required Decimal initialQuantity,
  String unit = 'pcs',
}) {
  return showGeneralDialog<Decimal>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, anim, secondaryAnim) => const SizedBox(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutCubic,
      );

      final scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(curved);
      final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(curved);

      return FadeTransition(
        opacity: fadeAnim,
        child: ScaleTransition(
          scale: scaleAnim,
          child: _QuantityNumpadDialogContent(
            productName: productName,
            initialQuantity: initialQuantity,
            unit: unit,
          ),
        ),
      );
    },
  );
}

class _QuantityNumpadDialogContent extends StatefulWidget {
  final String productName;
  final Decimal initialQuantity;
  final String unit;

  const _QuantityNumpadDialogContent({
    required this.productName,
    required this.initialQuantity,
    required this.unit,
  });

  @override
  State<_QuantityNumpadDialogContent> createState() => _QuantityNumpadDialogContentState();
}

class _QuantityNumpadDialogContentState extends State<_QuantityNumpadDialogContent> {
  late String _input;

  @override
  void initState() {
    super.initState();
    _input = widget.initialQuantity.toString();
  }

  void _onDigitPressed(String digit) {
    setState(() {
      if (_input == '0' && digit != '.') {
        _input = digit;
      } else {
        _input += digit;
      }
    });
  }

  void _onDotPressed() {
    if (!_input.contains('.')) {
      setState(() {
        if (_input.isEmpty) {
          _input = '0.';
        } else {
          _input += '.';
        }
      });
    }
  }

  void _onBackspacePressed() {
    setState(() {
      if (_input.length > 1) {
        _input = _input.substring(0, _input.length - 1);
      } else {
        _input = '0';
      }
    });
  }

  void _onClearPressed() {
    setState(() {
      _input = '';
    });
  }

  void _onConfirm() {
    final parsed = Decimal.tryParse(_input) ?? Decimal.zero;
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title & Product Name
            Text(
              widget.productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            // Display box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_input.isEmpty ? '0' : _input} ${widget.unit}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Numpad Grid
            Column(
              children: [
                _buildRow(['1', '2', '3']),
                const SizedBox(height: 8),
                _buildRow(['4', '5', '6']),
                const SizedBox(height: 8),
                _buildRow(['7', '8', '9']),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumpadKey(
                        keyName: 'numpad_dot',
                        label: '.',
                        onTap: _onDotPressed,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildNumpadKey(
                        keyName: 'numpad_0',
                        label: '0',
                        onTap: () => _onDigitPressed('0'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildNumpadKey(
                        keyName: 'numpad_backspace',
                        label: '⌫',
                        onTap: _onBackspacePressed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TactileButton(
                    key: const Key('numpad_clear'),
                    onPressed: _onClearPressed,
                    minHeight: 48,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TactileButton(
                    key: const Key('numpad_confirm'),
                    onPressed: _onConfirm,
                    minHeight: 48,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
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

  Widget _buildRow(List<String> digits) {
    return Row(
      children: digits
          .map(
            (d) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildNumpadKey(
                  keyName: 'numpad_$d',
                  label: d,
                  onTap: () => _onDigitPressed(d),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildNumpadKey({
    required String keyName,
    required String label,
    required VoidCallback onTap,
  }) {
    return TactileButton(
      key: Key(keyName),
      onPressed: onTap,
      minHeight: 48,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}
