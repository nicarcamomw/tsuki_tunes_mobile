import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import 'haptics.dart';

class CyberButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final double? width;
  final double height;
  final bool isLoading;

  const CyberButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.isPrimary = true,
    this.width,
    this.height = 46,
    this.isLoading = false,
  });

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  bool _reduceMotion = false;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _scaleController,
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
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isPrimary ? AppColors.accent : AppColors.bgMid;
    final borderColor = widget.isPrimary ? AppColors.accent : AppColors.border;
    final textColor = widget.isPrimary ? AppColors.textBright : AppColors.textPrimary;

    return Semantics(
      button: true,
      label: widget.text,
      child: GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        if (!_reduceMotion) _scaleController.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (!_reduceMotion) _scaleController.reverse();
        if (!widget.isLoading) {
          Haptics.tap();
          widget.onPressed();
        }
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        if (!_reduceMotion) _scaleController.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: widget.width,
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: _isPressed ? bgColor.withValues(alpha: 0.8) : bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _isPressed ? AppColors.neonCyan : borderColor,
            width: 1.2,
          ),
          boxShadow: widget.isPrimary && !_isPressed
              ? [
                  const BoxShadow(
                    color: AppColors.accentGlow,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isLoading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.textBright),
                ),
              ),
              const SizedBox(width: 8),
            ] else if (widget.icon != null) ...[
              Icon(widget.icon, size: 18, color: textColor),
              const SizedBox(width: 8),
            ],
            Text(
              widget.text.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: AppFontSize.body,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      ),
    ),
    );
  }
}
