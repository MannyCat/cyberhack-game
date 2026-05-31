import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';

// ── Color Constants ──────────────────────────────────────────────────────

const _bgDark = Color(0xFF0a0e17);
const _surface = Color(0xFF111827);
const _surfaceVariant = Color(0xFF1a2332);
const _greenPrimary = Color(0xFF00ff88);
const _cyanSecondary = Color(0xFF00d4ff);

class ResourceBar extends ConsumerWidget {
  const ResourceBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final profile = game.profile;

    final credits = (profile?['credits'] as num?)?.toInt() ?? 0;
    final power = (profile?['power'] as num?)?.toInt() ?? 0;
    final maxPower = (profile?['max_power'] as num?)?.toInt() ?? 200;
    final heat = (profile?['heat'] as num?)?.toInt() ?? 0;
    final level = (profile?['level'] as num?)?.toInt() ?? 1;

    // Count active operations
    final activeOps = game.operations
        .where((op) => op['status'] == 'active' || op['status'] == 'planning')
        .length;

    return Container(
      height: 60,
      color: const Color(0xFF0d1117),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _surfaceVariant, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Credits
          _ResourceItem(
            icon: Icons.attach_money,
            iconColor: _greenPrimary,
            label: 'Кредиты',
            value: _formatNumber(credits),
            valueColor: _greenPrimary,
          ),
          _buildSeparator(),
          // Power
          _ResourceItem(
            icon: Icons.bolt,
            iconColor: _cyanSecondary,
            label: 'Энергия',
            value: '$power/$maxPower',
            valueColor: _cyanSecondary,
            childBelow: _PowerBar(
              current: power,
              max: maxPower,
            ),
          ),
          _buildSeparator(),
          // Heat
          _ResourceItem(
            icon: Icons.local_fire_department,
            iconColor: _heatColor(heat),
            label: 'Теплота',
            value: '$heat',
            valueColor: _heatColor(heat),
          ),
          _buildSeparator(),
          // Level
          _ResourceItem(
            icon: Icons.star,
            iconColor: const Color(0xFFFFD700),
            label: 'Уровень',
            value: '$level',
            valueColor: const Color(0xFFFFD700),
          ),
          _buildSeparator(),
          // Operations
          _ResourceItem(
            icon: Icons.explore_outlined,
            iconColor: _greenPrimary,
            label: 'Операции',
            value: '$activeOps активных',
            valueColor: _greenPrimary,
          ),
        ],
      ),
    );
  }

  /// Builds a vertical separator line between resource items.
  Widget _buildSeparator() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: _surfaceVariant,
    );
  }

  /// Formats large numbers with K/M suffixes for readability.
  String _formatNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  /// Returns the appropriate heat color based on severity.
  static Color _heatColor(int heat) {
    if (heat >= 80) return const Color(0xFFff2222);
    if (heat >= 50) return const Color(0xFFFF8C00);
    if (heat >= 20) return const Color(0xFFFFD700);
    return const Color(0xFF00ff88);
  }
}

// ── Resource Item Widget ─────────────────────────────────────────────────

class _ResourceItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final Widget? childBelow;

  const _ResourceItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    this.childBelow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        if (childBelow != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 22), // Align with icon + spacing
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: childBelow!,
          ),
        ] else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 22),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ── Power Progress Bar ───────────────────────────────────────────────────

class _PowerBar extends StatelessWidget {
  final int current;
  final int max;

  const _PowerBar({required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    final ratio = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;

    Color barColor;
    if (ratio >= 0.6) {
      barColor = const Color(0xFF00d4ff);
    } else if (ratio >= 0.3) {
      barColor = const Color(0xFFFFD700);
    } else {
      barColor = const Color(0xFFFF4444);
    }

    return SizedBox(
      width: 100,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: ratio,
          backgroundColor: const Color(0xFF1a2332),
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
          minHeight: 4,
        ),
      ),
    );
  }
}
