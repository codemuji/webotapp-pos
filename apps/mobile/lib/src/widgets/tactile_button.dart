import 'package:flutter/material.dart';

/// Interactive button implementing Emil Kowalski's tactile scale-on-press feedback.
/// Scales down to `scaleFactor` (default 0.97) over `duration` (default 120ms) using
/// `Curves.easeOutCubic`, providing crisp tactile feedback without sluggishness.
class TactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double scaleFactor;
  final Duration duration;
  final double minWidth;
  final double minHeight;

  const TactileButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.scaleFactor = 0.97,
    this.duration = const Duration(milliseconds: 120),
    this.minWidth = 48.0,
    this.minHeight = 48.0,
  });

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.onPressed != null) {
      _controller.forward();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (widget.onPressed != null) {
      _controller.reverse();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (widget.onPressed != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minWidth,
        minHeight: widget.minHeight,
      ),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: ScaleTransition(
            scale: _scaleAnimation,
            alignment: Alignment.center,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
