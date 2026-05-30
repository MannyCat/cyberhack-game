import 'dart:async';
import 'package:flutter/material.dart';

/// Cyberpunk-styled button for PC desktop — glowing border, pulse animation,
/// multiple variants, loading state, optional icon.
/// Wider defaults, hover glow, pointer cursor.
enum CyberButtonVariant { primary, danger, secondary }

class CyberButton extends StatefulWidget {
  final String label;
  final CyberButtonVariant variant;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final bool enabled;

  const CyberButton({
    super.key,
    required this.label,
    this.variant = CyberButtonVariant.primary,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 52.0,
    this.borderRadius = 8.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
    this.fontSize = 15.0,
    this.enabled = true,
  });

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isHovered = false;

  // ── Colour maps ──────────────────────────────────────────────
  static const Map<CyberButtonVariant, Color> _glowColors = {
    CyberButtonVariant.primary: Color(0xFF00FF41),
    CyberButtonVariant.danger: Color(0xFFFF0040),
    CyberButtonVariant.secondary: Color(0xFF00E5FF),
  };

  static const Map<CyberButtonVariant, Color> _borderColors = {
    CyberButtonVariant.primary: Color(0xFF00CC33),
    CyberButtonVariant.danger: Color(0xFFCC0033),
    CyberButtonVariant.secondary: Color(0xFF00B8CC),
  };

  static const Map<CyberButtonVariant, Color> _bgColors = {
    CyberButtonVariant.primary: Color(0xFF0D2818),
    CyberButtonVariant.danger: Color(0xFF2A0A10),
    CyberButtonVariant.secondary: Color(0xFF0A1E26),
  };

  Color get _glow => _glowColors[widget.variant]!;
  Color get _border => _borderColors[widget.variant]!;
  Color get _bg => _bgColors[widget.variant]!;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.isLoading || !widget.enabled || widget.onPressed == null) {
      return;
    }
    await _pulseController.forward();
    await _pulseController.reverse();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.isLoading || !widget.enabled;

    return ListenableBuilder(
      listenable: _pulseAnimation,
      builder: (context, _) {
        return MouseRegion(
          cursor: isDisabled
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedScale(
            scale: _pulseAnimation.value,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: isDisabled
                    ? const Color(0xFF12162A)
                    : _isHovered
                        ? _bg.withValues(alpha: 1.0)
                        : _bg,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: isDisabled
                      ? const Color(0xFF2A2F45)
                      : _border.withValues(
                          alpha: _isHovered ? 1.0 : 0.6),
                  width: _isHovered ? 2.0 : 1.5,
                ),
                boxShadow: [
                  if (_isHovered && !isDisabled)
                    BoxShadow(
                      color: _glow.withValues(alpha: 0.45),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  if (_isHovered && !isDisabled)
                    BoxShadow(
                      color: _glow.withValues(alpha: 0.15),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  if (!isDisabled && !_isHovered)
                    BoxShadow(
                      color: _glow.withValues(alpha: 0.08),
                      blurRadius: 8,
                    ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleTap,
                  borderRadius:
                      BorderRadius.circular(widget.borderRadius),
                  child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            height: widget.fontSize + 6,
                            width: widget.fontSize + 6,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(_glow),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(
                                  widget.icon,
                                  color: isDisabled
                                      ? Colors.white24
                                      : _glow,
                                  size: widget.fontSize + 6,
                                ),
                                const SizedBox(width: 10),
                              ],
                              Text(
                                widget.label,
                                style: TextStyle(
                                  color: isDisabled
                                      ? Colors.white24
                                      : _glow,
                                  fontSize: widget.fontSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
