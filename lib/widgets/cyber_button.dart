import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

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

class _CyberButtonState extends State<CyberButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isPrimary ? AppColors.accent : AppColors.bgMid;
    final borderColor = widget.isPrimary ? AppColors.accent : AppColors.border;
    final textColor = widget.isPrimary ? AppColors.textBright : AppColors.textPrimary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (!widget.isLoading) widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
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
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
