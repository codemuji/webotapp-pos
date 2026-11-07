import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/webotapp_logo.dart';
import '../theme/webotapp_theme.dart';
import 'admin_auth_service.dart';

/// Full-screen tactile security lock view presented when the desktop app launches or is locked by the user.
/// Supports both physical keyboard input (Numpad, Top row, Backspace, Enter) and on-screen mouse keypad.
class AdminLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AdminLockScreen({
    super.key,
    required this.onUnlocked,
  });

  @override
  State<AdminLockScreen> createState() => _AdminLockScreenState();
}

class _AdminLockScreenState extends State<AdminLockScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_isLoading) return;
    if (_pin.length >= 6) return;

    setState(() {
      _pin += digit;
      _errorMessage = null;
    });

    if (_pin.length == 4) {
      _attemptUnlock();
    }
  }

  void _onBackspace() {
    if (_isLoading || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  void _onClear() {
    if (_isLoading) return;
    setState(() {
      _pin = '';
      _errorMessage = null;
    });
  }

  Future<void> _attemptUnlock() async {
    if (_pin.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isValid = await AdminAuthService.instance.verifyPin(_pin);

    if (!mounted) return;

    if (isValid) {
      setState(() => _isLoading = false);
      widget.onUnlocked();
    } else {
      _shakeController.forward(from: 0.0);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Incorrect PIN. Please try again.';
        _pin = '';
      });
    }
  }

  void _showChangePinDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            title: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF6366F1), size: 22),
                SizedBox(width: 10),
                Text(
                  'Change Admin PIN',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set a secure 4-6 digit numeric passcode to protect your store console.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F1D1D).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDC2626)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFFCA5A5), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dialogError!,
                              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _buildDialogTextField(
                    controller: currentCtrl,
                    label: 'Current PIN (Default: 1234)',
                    hint: '••••',
                  ),
                  const SizedBox(height: 12),
                  _buildDialogTextField(
                    controller: newCtrl,
                    label: 'New PIN (4-6 digits)',
                    hint: '••••',
                  ),
                  const SizedBox(height: 12),
                  _buildDialogTextField(
                    controller: confirmCtrl,
                    label: 'Confirm New PIN',
                    hint: '••••',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final cur = currentCtrl.text.trim();
                  final n = newCtrl.text.trim();
                  final conf = confirmCtrl.text.trim();

                  if (n != conf) {
                    setDialogState(() => dialogError = 'New PIN and Confirm PIN do not match.');
                    return;
                  }
                  if (n.length < 4 || n.length > 6) {
                    setDialogState(() => dialogError = 'New PIN must be 4 to 6 digits.');
                    return;
                  }

                  final success = await AdminAuthService.instance.changeAdminPin(
                    currentPin: cur,
                    newPin: n,
                  );

                  if (success) {
                    Navigator.of(dialogCtx).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ Admin PIN successfully updated!'),
                          backgroundColor: Color(0xFF059669),
                        ),
                      );
                    }
                  } else {
                    setDialogState(() => dialogError = 'Current PIN is incorrect.');
                  }
                },
                child: const Text('Save New PIN'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 3),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF64748B), letterSpacing: 3),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
        _onDigit('0');
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
        _onDigit('1');
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
        _onDigit('2');
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
        _onDigit('3');
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
        _onDigit('4');
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
        _onDigit('5');
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
        _onDigit('6');
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
        _onDigit('7');
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
        _onDigit('8');
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
        _onDigit('9');
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.backspace) {
        _onBackspace();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.escape) {
        _onClear();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        _attemptUnlock();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Stack(
          children: [
            // Subtle ambient backdrop glows
            Positioned(
              top: -120,
              right: -100,
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -100,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 440,
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF334155), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 36,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // WebotApp Brand Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: const Center(
                              child: WebotAppLogoMark(size: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: -0.2,
                              ),
                              children: [
                                TextSpan(text: '⚡ WEBOT', style: TextStyle(color: Colors.white)),
                                TextSpan(text: 'APP', style: TextStyle(color: Color(0xFF00C853))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Lock Security Icon
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.2),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Color(0xFF818CF8),
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Store Console Locked',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter your Manager or Store Admin PIN to unlock',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Animated PIN Dot Indicators with Shake Animation on Error
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          final offset = sin(_shakeAnimation.value * pi * 4) * 10;
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: child,
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final isFilled = index < _pin.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled ? const Color(0xFF6366F1) : const Color(0xFF0F172A),
                                border: Border.all(
                                  color: isFilled ? const Color(0xFF818CF8) : const Color(0xFF475569),
                                  width: 2,
                                ),
                                boxShadow: isFilled
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF6366F1).withOpacity(0.5),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ),

                      // Error message or loading indicator
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 22,
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                              )
                            : (_errorMessage != null
                                ? Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFF87171),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : const SizedBox.shrink()),
                      ),
                      const SizedBox(height: 12),

                      // Tactile Keypad (1 - 9, Clear, 0, Backspace)
                      _buildKeypad(),

                      const SizedBox(height: 24),

                      // Bottom Action Links (Default PIN hint & Change PIN)
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline, size: 12, color: Color(0xFF94A3B8)),
                                SizedBox(width: 5),
                                Text(
                                  'Default PIN: 1234',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _showChangePinDialog,
                            icon: const Icon(Icons.key_rounded, size: 14, color: Color(0xFF818CF8)),
                            label: const Text(
                              'Change PIN',
                              style: TextStyle(
                                color: Color(0xFF818CF8),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('1'),
            const SizedBox(width: 14),
            _buildKeypadButton('2'),
            const SizedBox(width: 14),
            _buildKeypadButton('3'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('4'),
            const SizedBox(width: 14),
            _buildKeypadButton('5'),
            const SizedBox(width: 14),
            _buildKeypadButton('6'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('7'),
            const SizedBox(width: 14),
            _buildKeypadButton('8'),
            const SizedBox(width: 14),
            _buildKeypadButton('9'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadIconButton(
              icon: Icons.clear_rounded,
              tooltip: 'Clear',
              onTap: _onClear,
            ),
            const SizedBox(width: 14),
            _buildKeypadButton('0'),
            const SizedBox(width: 14),
            _buildKeypadIconButton(
              icon: Icons.backspace_outlined,
              tooltip: 'Backspace',
              onTap: _onBackspace,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String label) {
    return SizedBox(
      width: 72,
      height: 52,
      child: Material(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _onDigit(label),
          borderRadius: BorderRadius.circular(12),
          hoverColor: const Color(0xFF6366F1).withOpacity(0.15),
          splashColor: const Color(0xFF6366F1).withOpacity(0.3),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 72,
      height: 52,
      child: Material(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: const Color(0xFFEF4444).withOpacity(0.15),
          splashColor: const Color(0xFFEF4444).withOpacity(0.3),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: const Color(0xFF94A3B8),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
