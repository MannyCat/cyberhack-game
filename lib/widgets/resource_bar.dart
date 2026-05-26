import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Displays Credits / CPU / Bandwidth in a horizontal bar.
/// Supports compact and expanded modes with animated value transitions.
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
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.height = 44.0,
  });

  @override
  State<ResourceBar> createState() => _ResourceBarState();
}

class _ResourceBarState extends State<ResourceBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
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
      _creditsAnim = Tween<double>(
        begin: _prevCredits.toDouble(),
        end: widget.credits.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

      _cpuAnim = Tween<double>(
        begin: _prevCpu.toDouble(),
        end: widget.cpu.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

      _bandwidthAnim = Tween<double>(
        begin: _prevBandwidth.toDouble(),
        end: widget.bandwidth.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

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
        label: 'CRD',
        value: widget.credits,
        maxValue: widget.maxCredits,
        icon: Icons.monetization_on,
        activeColor: const Color(0xFFFFD700),
        dimColor: const Color(0xFF5C4D1A),
      ),
      ResourceEntry(
        label: 'CPU',
        value: widget.cpu,
        maxValue: widget.maxCpu,
        icon: Icons.memory,
        activeColor: const Color(0xFF00E5FF),
        dimColor: const Color(0xFF0A2A30),
      ),
      ResourceEntry(
        label: 'NET',
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

  Widget _buildCompact(
      List<ResourceEntry> resources, List<Animation<double>> animations) {
    return Container(
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2F45), width: 1),
      ),
      child: Row(
        children: List.generate(resources.length, (i) {
          final r = resources[i];
          final anim = animations[i];
          return Expanded(
            child: ListenableBuilder(
              listenable: anim,
              builder: (context, _) {
                final ratio = r.maxValue > 0
                    ? math.min(anim.value / r.maxValue, 1.0)
                    : 0.0;
                return Row(
                  children: [
                    Icon(r.icon, color: r.activeColor, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.label}: ${_formatNumber(anim.value)}',
                            style: TextStyle(
                              color: r.activeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
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
            ),
          );
        }),
      ),
    );
  }

  Widget _buildExpanded(
      List<ResourceEntry> resources, List<Animation<double>> animations) {
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2F45), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(resources.length, (i) {
          final r = resources[i];
          final anim = animations[i];
          if (i > 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _buildExpandedRow(r, anim),
            );
          }
          return _buildExpandedRow(r, anim);
        }),
      ),
    );
  }

  Widget _buildExpandedRow(ResourceEntry r, Animation<double> anim) {
    return ListenableBuilder(
      listenable: anim,
      builder: (context, _) {
        final ratio = r.maxValue > 0
            ? math.min(anim.value / r.maxValue, 1.0)
            : 0.0;
        return Row(
          children: [
            Icon(r.icon, color: r.activeColor, size: 20),
            const SizedBox(width: 10),
            SizedBox(
              width: 40,
              child: Text(
                r.label,
                style: TextStyle(
                  color: r.activeColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatNumber(anim.value),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_formatNumber(r.maxValue.toDouble())} max',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: r.dimColor,
                      valueColor: AlwaysStoppedAnimation<Color>(r.activeColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
