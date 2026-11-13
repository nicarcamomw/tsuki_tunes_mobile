import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/design_tokens.dart';
import 'haptics.dart';

class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final String? semanticLabel;

  /// The feel of a tap: [Haptics.tap] for things that open or start,
  /// [Haptics.selection] for picking or toggling, null for none.
  final VoidCallback? haptic;

  /// The smallest area that answers a touch (Material's 48 dp): a small
  /// icon keeps its look, centred in it. Bigger children are untouched.
  final double minTouchSize;

  /// Material's minimum touch target.
  static const double minTouchTarget = 48;

  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.90,
    this.semanticLabel,
    this.haptic = Haptics.tap,
    this.minTouchSize = minTouchTarget,
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.micro,
      reverseDuration: AppMotion.normal,
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!_reduceMotion) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (!_reduceMotion) {
      if (_controller.isAnimating) {
        // A quick tap: finish the press so it's seen, then spring back,
        // without holding the action until the animation is done.
        _controller.forward().whenCompleteOrCancel(() {
          if (mounted) _controller.reverse();
        });
      } else {
        _controller.reverse();
      }
    }
    if (widget.onTap != null) widget.haptic?.call();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    if (!_reduceMotion) _controller.reverse();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
         event.logicalKey == LogicalKeyboardKey.space)) {
      widget.onTap?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    Widget result = Focus(
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onLongPress: widget.onLongPress != null
            ? () {
                _controller.reverse();
                Haptics.longPress();
                widget.onLongPress?.call();
              }
            : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: widget.minTouchSize, minHeight: widget.minTouchSize),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: AnimatedBuilder(
              animation: _scale,
              builder: (context, child) => Transform.scale(
                scale: _scale.value,
                child: child,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
    if (widget.semanticLabel != null) {
      result = Semantics(
        button: true,
        label: widget.semanticLabel,
        child: result,
      );
    }
    return result;
  }
}
