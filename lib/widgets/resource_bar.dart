import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Displays Credits / CPU / Bandwidth in a horizontal desktop top bar.
/// PC-sized, no mobile sizing, hover effects on each resource tile.
enum ResourceBarMode { compact, expanded }

class ResourceEntry {
  final String label;
  final int value;
  final int maxValue;
  final IconData icon;
  final Color activeColor;
  final Color dimColor;

  const ResourceEntry({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.icon,
    required this.activeColor,
    required this.dimColor,
  });
}

class ResourceBar extends StatefulWidget {
  final int credits;
  final int maxCredits;
  final int cpu;
  final int maxCpu;
  final int bandwidth;
  final int maxBandwidth;
  final ResourceBarMode mode;
  final EdgeInsetsGeometry padding;
  final double height;

  const ResourceBar({
    super.key,
    this.credits = 0,
    this.maxCredits = 1000000,
    this.cpu = 0,
    this.maxCpu = 256,
    this.bandwidth = 0,
    this.maxBandwidth = 1024,
    this.mode = ResourceBarMode.compact,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.height = 56.0,
  });

  @override
  State<ResourceBar> createState() => _ResourceBarState();
}

class _ResourceBarState extends State<ResourceBar>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  CurvedAnimation? _curvedCredits;
  CurvedAnimation? _curvedCpu;
  CurvedAnimation? _curvedBandwidth;
  late Animation<double> _creditsAnim;
  late Animation<double> _cpuAnim;
  late Animation<double> _bandwidthAnim;
  int _prevCredits = 0;
  int _prevCpu = 0;
  int _prevBandwidth = 0;

  @override
  void initState() {
    super.initState();
    _prevCredits = widget.credits;
    _prevCpu = widget.cpu;
    _prevBandwidth = widget.bandwidth;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _creditsAnim = AlwaysStoppedAnimation(widget.credits.toDouble());
    _cpuAnim = AlwaysStoppedAnimation(widget.cpu.toDouble());
    _bandwidthAnim = AlwaysStoppedAnimation(widget.bandwidth.toDouble());
  }

  @override
  void didUpdateWidget(ResourceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool changed = false;

    if (oldWidget.credits != widget.credits ||
        oldWidget.cpu != widget.cpu ||
        oldWidget.bandwidth != widget.bandwidth) {
      _curvedCredits?.dispose();
      _curvedCpu?.dispose();
      _curvedBandwidth?.dispose();

      _curvedCredits = CurvedAnimation(
          parent: _controller, curve: Curves.easeOutCubic);
      _curvedCpu = CurvedAnimation(
          parent: _controller, curve: Curves.easeOutCubic);
      _curvedBandwidth = CurvedAnimation(
          parent: _controller, curve: Curves.easeOutCubic);

      _creditsAnim = Tween<double>(
        begin: _prevCredits.toDouble(),
        end: widget.credits.toDouble(),
      ).animate(_curvedCredits!);

      _cpuAnim = Tween<double>(
        begin: _prevCpu.toDouble(),
        end: widget.cpu.toDouble(),
      ).animate(_curvedCpu!);

      _bandwidthAnim = Tween<double>(
        begin: _prevBandwidth.toDouble(),
        end: widget.bandwidth.toDouble(),
      ).animate(_curvedBandwidth!);

      _prevCredits = widget.credits;
      _prevCpu = widget.cpu;
      _prevBandwidth = widget.bandwidth;
      changed = true;
    }

    if (changed) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curvedCredits?.dispose();
    _curvedCpu?.dispose();
    _curvedBandwidth?.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(double v) {
    final n = v.round();
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final resources = [
      ResourceEntry(
        label: 'КРЕДИТЫ',
        value: widget.credits,
        maxValue: widget.maxCredits,
        icon: Icons.monetization_on,
        activeColor: const Color(0xFFFFD700),
        dimColor: const Color(0xFF5C4D1A),
      ),
      ResourceEntry(
        label: 'ЦПУ',
        value: widget.cpu,
        maxValue: widget.maxCpu,
        icon: Icons.memory,
        activeColor: const Color(0xFF00E5FF),
        dimColor: const Color(0xFF0A2A30),
      ),
      ResourceEntry(
        label: 'СЕТЬ',
        value: widget.bandwidth,
        maxValue: widget.maxBandwidth,
        icon: Icons.wifi,
        activeColor: const Color(0xFF00FF41),
        dimColor: const Color(0xFF0A2A12),
      ),
    ];

    final animations = [_creditsAnim, _cpuAnim, _bandwidthAnim];

    if (widget.mode == ResourceBarMode.compact) {
      return _buildCompact(resources, animations);
    }
    return _buildExpanded(resources, animations);
  }

  /// Compact: single horizontal bar with icon + label + thin progress.
  Widget _buildCompact(
      List<ResourceEntry> resources, List<Animation<double>> animations) {
    return Container(
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2F45), width: 1),
      ),
      child: Row(
        children: List.generate(resources.length, (i) {
          final r = resources[i];
          final anim = animations[i];
          if (i > 0) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _buildCompactTile(r, anim),
              ),
            );
          }
          return Expanded(child: _buildCompactTile(r, anim));
        }),
      ),
    );
  }

  Widget _buildCompactTile(ResourceEntry r, Animation<double> anim) {
    return _HoverTile(
      activeColor: r.activeColor,
      builder: (isHovered, _) {
        return ListenableBuilder(
          listenable: anim,
          builder: (context, _) {
            final ratio = r.maxValue > 0
                ? math.min(anim.value / r.maxValue, 1.0)
                : 0.0;
            return Row(
              children: [
                // Icon
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: r.activeColor.withValues(alpha: isHovered ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: r.activeColor.withValues(alpha: isHovered ? 0.4 : 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(r.icon, color: r.activeColor, size: 16),
                ),
                const SizedBox(width: 8),
                // Label + Value
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            r.label,
                            style: TextStyle(
                              color: r.activeColor.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatNumber(anim.value),
                            style: TextStyle(
                              color: r.activeColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 3,
                          backgroundColor: r.dimColor,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(r.activeColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Expanded: horizontal row of wider cards with label, value, max, progress bar.
  Widget _buildExpanded(
      List<ResourceEntry> resources, List<Animation<double>> animations) {
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2F45), width: 1),
      ),
      child: Row(
        children: List.generate(resources.length, (i) {
          final r = resources[i];
          final anim = animations[i];
          if (i > 0) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _buildExpandedTile(r, anim),
              ),
            );
          }
          return Expanded(child: _buildExpandedTile(r, anim));
        }),
      ),
    );
  }

  Widget _buildExpandedTile(ResourceEntry r, Animation<double> anim) {
    return _HoverTile(
      activeColor: r.activeColor,
      builder: (isHovered, _) {
        return ListenableBuilder(
          listenable: anim,
          builder: (context, _) {
            final ratio = r.maxValue > 0
                ? math.min(anim.value / r.maxValue, 1.0)
                : 0.0;
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: r.activeColor.withValues(alpha: isHovered ? 0.08 : 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      r.activeColor.withValues(alpha: isHovered ? 0.35 : 0.15),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(r.icon, color: r.activeColor, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        r.label,
                        style: TextStyle(
                          color: r.activeColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatNumber(anim.value),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        '${_formatNumber(r.maxValue.toDouble())} макс',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: r.dimColor,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(r.activeColor),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Reusable hover wrapper — applies MouseRegion with cursor + optional
/// animated border glow on mouse enter / exit.
class _HoverTile extends StatefulWidget {
  final Color activeColor;
  final Widget Function(bool isHovered, Color color) builder;

  const _HoverTile({
    required this.activeColor,
    required this.builder,
  });

  @override
  State<_HoverTile> createState() => _HoverTileState();
}

class _HoverTileState extends State<_HoverTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.builder(_isHovered, widget.activeColor),
    );
  }
}
