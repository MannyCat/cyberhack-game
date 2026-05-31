import 'package:flutter/material.dart';

// ── Color Constants ──────────────────────────────────────────────────────

const _greenPrimary = Color(0xFF00ff88);
const _greenDark = Color(0xFF00cc6a);
const _cyanSecondary = Color(0xFF00d4ff);
const _dangerRed = Color(0xFFff4444);
const _dangerDark = Color(0xFFcc2222);
const _bgDark = Color(0xFF0a0e17);
const _surface = Color(0xFF111827);
const _surfaceVariant = Color(0xFF1a2332);

/// Defines the visual style variants for CyberButton.
enum CyberButtonVariant {
  /// Green gradient — primary action.
  primary,

  /// Dark background with cyan border — secondary action.
  secondary,

  /// Red gradient — destructive action.
  danger,

  /// Green gradient — identical to primary, used for semantic clarity.
  success,
}

/// A reusable styled button widget with cyberpunk aesthetics.
///
/// Supports four variants, hover effects, loading states, optional leading
/// icon, and automatic disabled styling when [onPressed] is null.
class CyberButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final CyberButtonVariant variant;
  final double? width;
  final double height;
  final bool isLoading;
  final IconData? icon;
  final EdgeInsets padding;

  const CyberButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = CyberButtonVariant.primary,
    this.width,
    this.height = 44,
    this.isLoading = false,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton> {
  bool _isHovered = false;

  bool get _isDisabled => widget.onPressed == null || widget.isLoading;

  // ── Variant Colors ─────────────────────────────────────────────────────

  BoxDecoration _buildDecoration() {
    final disabled = _isDisabled;
    final hovered = _isHovered && !disabled;

    switch (widget.variant) {
      case CyberButtonVariant.primary:
      case CyberButtonVariant.success:
        return BoxDecoration(
          gradient: disabled
              ? const LinearGradient(colors: [Colors.grey, Colors.grey])
              : LinearGradient(
                  colors: hovered
                      ? [_greenPrimary, _greenPrimary]
                      : [_greenPrimary, _greenDark],
                ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: !disabled
              ? [
                  BoxShadow(
                    color: _greenPrimary.withValues(alpha: hovered ? 0.4 : 0.2),
                    blurRadius: hovered ? 16 : 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        );

      case CyberButtonVariant.secondary:
        return BoxDecoration(
          color: hovered && !disabled ? _surfaceVariant : _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: disabled
                ? Colors.grey.shade700
                : hovered
                    ? _cyanSecondary
                    : _cyanSecondary.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: !disabled
              ? [
                  BoxShadow(
                    color: _cyanSecondary.withValues(alpha: hovered ? 0.15 : 0.05),
                    blurRadius: hovered ? 12 : 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        );

      case CyberButtonVariant.danger:
        return BoxDecoration(
          gradient: disabled
              ? const LinearGradient(colors: [Colors.grey, Colors.grey])
              : LinearGradient(
                  colors: hovered
                      ? [_dangerRed, _dangerRed]
                      : [_dangerRed, _dangerDark],
                ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: !disabled
              ? [
                  BoxShadow(
                    color: _dangerRed.withValues(alpha: hovered ? 0.4 : 0.2),
                    blurRadius: hovered ? 16 : 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        );
    }
  }

  Color _getTextColor() {
    if (_isDisabled) return Colors.grey.shade500;
    switch (widget.variant) {
      case CyberButtonVariant.primary:
      case CyberButtonVariant.success:
        return _bgDark;
      case CyberButtonVariant.secondary:
        return _cyanSecondary;
      case CyberButtonVariant.danger:
        return Colors.white;
    }
  }

  Color _getIconColor() {
    return _getTextColor();
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: _isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered && !_isDisabled ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: widget.width,
          height: widget.height,
          decoration: _buildDecoration(),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isDisabled ? null : widget.onPressed,
              borderRadius: BorderRadius.circular(8),
              splashColor: Colors.white.withValues(alpha: 0.1),
              highlightColor: Colors.white.withValues(alpha: 0.05),
              child: Center(
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_getTextColor()),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Загрузка...',
            style: TextStyle(
              color: _getTextColor(),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: _getIconColor(), size: 18),
          const SizedBox(width: 8),
        ],
        Text(
          widget.text,
          style: TextStyle(
            color: _getTextColor(),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
