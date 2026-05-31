import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/game_provider.dart';
import '../../widgets/cyber_button.dart';

// ── Color Constants ──────────────────────────────────────────────────────

const _bgDark = Color(0xFF0a0e17);
const _surface = Color(0xFF111827);
const _surfaceVariant = Color(0xFF1a2332);
const _greenPrimary = Color(0xFF00ff88);
const _greenDark = Color(0xFF00cc6a);
const _cyanSecondary = Color(0xFF00d4ff);
const _goldAccent = Color(0xFFFFD700);
const _dangerRed = Color(0xFFff4444);
const _purpleAccent = Color(0xFFa855f7);

// ── Market Category Data ──────────────────────────────────────────────────

class MarketCategoryInfo {
  final String key;
  final String labelRu;
  final IconData icon;
  final Color color;

  const MarketCategoryInfo({
    required this.key,
    required this.labelRu,
    required this.icon,
    required this.color,
  });
}

const _marketCategories = [
  MarketCategoryInfo(key: 'all', labelRu: 'Всё', icon: Icons.grid_view, color: Colors.grey),
  MarketCategoryInfo(key: 'hardware', labelRu: 'Оборудование', icon: Icons.memory, color: _cyanSecondary),
  MarketCategoryInfo(key: 'software', labelRu: 'Софт', icon: Icons.code, color: _greenPrimary),
  MarketCategoryInfo(key: 'exploits', labelRu: 'Эксплойты', icon: Icons.bug_report, color: _dangerRed),
  MarketCategoryInfo(key: 'tools', labelRu: 'Инструменты', icon: Icons.build, color: _goldAccent),
];

// ── Market Screen ───────────────────────────────────────────────────────

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  final _supabase = Supabase.instance.client;

  // ── State ───────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _inventory = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  // Track items currently being purchased
  final Set<String> _purchasingIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Data Loading ──────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      final results = await Future.wait([
        _supabase.from('market_items').select().order('name'),
        if (userId != null)
          _supabase
              .from('player_inventory')
              .select('*, market_items(*)')
              .eq('player_id', userId),
      ]);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(results[0]);
          _inventory = results.length > 1
              ? List<Map<String, dynamic>>.from(results[1])
              : [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _catRu(String cat) {
    switch (cat) {
      case 'hardware':
        return 'Оборудование';
      case 'software':
        return 'Софт';
      case 'exploits':
        return 'Эксплойты';
      case 'tools':
        return 'Инструменты';
      default:
        return cat;
    }
  }

  Color _catColor(String cat) {
    for (final c in _marketCategories) {
      if (c.key == cat) return c.color;
    }
    return Colors.grey;
  }

  IconData _catIcon(String cat) {
    for (final c in _marketCategories) {
      if (c.key == cat) return c.icon;
    }
    return Icons.category;
  }

  String _formatCredits(dynamic value) {
    final v = (value as num?)?.toInt() ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  /// Get inventory quantity for a specific market item.
  int _getInventoryQty(String itemId) {
    final entry = _inventory.firstWhere(
      (inv) => inv['market_items']?['id'] == itemId || inv['item_id'] == itemId,
      orElse: () => <String, dynamic>{},
    );
    return (entry['quantity'] as num?)?.toInt() ?? 0;
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _purchaseItem(Map<String, dynamic> item) async {
    final credits = ref.read(gameProvider).credits ?? 0;
    final price = (item['price'] as num?)?.toInt() ?? 0;
    if (credits < price) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Недостаточно кредитов (нужно ${_formatCredits(price)}, есть ${_formatCredits(credits)})'),
            backgroundColor: _dangerRed,
          ),
        );
      }
      return;
    }

    // Check stock
    final maxStock = (item['max_stock'] as num?)?.toInt() ?? -1;
    if (maxStock >= 0) {
      final currentStock = (item['current_stock'] as num?)?.toInt() ?? 0;
      if (currentStock <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Товар закончился на складе.'),
              backgroundColor: _dangerRed,
            ),
          );
        }
        return;
      }
    }

    setState(() => _purchasingIds.add(item['id'] as String));
    try {
      await _supabase.rpc('purchase_item', params: {
        'p_item_id': item['id'],
      });
      await ref.read(gameProvider.notifier).loadAllData();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Куплено: ${item['name']}'),
            backgroundColor: _greenPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка покупки: $e'),
            backgroundColor: _dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasingIds.remove(item['id'] as String));
    }
  }

  // ── Filtering ──────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedCategory == 'all') return _items;
    return _items.where((i) => i['category'] == _selectedCategory).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _greenPrimary),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page Header ───────────────────────────────────────────────
          const Row(
            children: [
              Icon(Icons.store, color: _greenPrimary, size: 22),
              SizedBox(width: 8),
              Text(
                'ЧЁРНЫЙ РЫНОК',
                style: TextStyle(
                  color: _greenPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Divider(color: _surfaceVariant, height: 1),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ════════════════════════════════════════════════════════════════
          // SECTION 1: MARKET ITEMS
          // ════════════════════════════════════════════════════════════════
          const Row(
            children: [
              Icon(Icons.shopping_bag_outlined, color: _cyanSecondary, size: 18),
              SizedBox(width: 8),
              Text(
                'ТОВАРЫ',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Divider(color: _surfaceVariant, height: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Category Filter Tabs ──────────────────────────────────────
          _buildFilterChips(),
          const SizedBox(height: 20),

          // ── Items Grid ────────────────────────────────────────────────
          _filteredItems.isEmpty
              ? _buildEmptyMarket()
              : Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: _filteredItems
                      .map((item) => _buildItemCard(item))
                      .toList(),
                ),

          const SizedBox(height: 32),

          // ════════════════════════════════════════════════════════════════
          // SECTION 2: PLAYER INVENTORY
          // ════════════════════════════════════════════════════════════════
          Row(
            children: [
              const Icon(Icons.work_outline, color: _goldAccent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'МОЙ ИНВЕНТАРЬ',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(color: _surfaceVariant, height: 1),
              ),
              // Count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _goldAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _goldAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${_inventory.length} шт.',
                  style: const TextStyle(
                    color: _goldAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildInventorySection(),
        ],
      ),
    );
  }

  // ── Filter Chips ───────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _marketCategories.map((cat) {
        final isSelected = _selectedCategory == cat.key;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? cat.color.withValues(alpha: 0.15)
                    : const Color(0xFF0d1420),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? cat.color.withValues(alpha: 0.5)
                      : _surfaceVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat.icon,
                    color: isSelected ? cat.color : Colors.grey.shade500,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat.labelRu,
                    style: TextStyle(
                      color: isSelected ? cat.color : Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Item Card ──────────────────────────────────────────────────────────

  Widget _buildItemCard(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? '—';
    final category = item['category'] as String? ?? '';
    final description = item['description'] as String? ?? '';
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final maxStock = (item['max_stock'] as num?)?.toInt() ?? -1;
    final currentStock = (item['current_stock'] as num?)?.toInt() ?? 0;
    final isLimited = maxStock >= 0;
    final isOutOfStock = isLimited && currentStock <= 0;
    final catColor = _catColor(category);
    final ownedQty = _getInventoryQty(item['id'] as String);

    return _MarketItemCardWidget(
      name: name,
      category: category,
      categoryRu: _catRu(category),
      categoryColor: catColor,
      categoryIcon: _catIcon(category),
      description: description,
      price: price,
      isLimited: isLimited,
      currentStock: currentStock,
      isOutOfStock: isOutOfStock,
      ownedQty: ownedQty,
      isPurchasing: _purchasingIds.contains(item['id'] as String),
      onBuy: isOutOfStock ? null : () => _purchaseItem(item),
    );
  }

  // ── Inventory Section ─────────────────────────────────────────────────

  Widget _buildInventorySection() {
    if (_inventory.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _surfaceVariant),
        ),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 48),
            SizedBox(height: 12),
            Text(
              'Инвентарь пуст',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Купите инструменты на рынке выше.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Horizontal scrolling inventory
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _inventory.map((inv) {
            final itemData = inv['market_items'] as Map<String, dynamic>?;
            if (itemData == null) return const SizedBox.shrink();

            final name = itemData['name'] as String? ?? '—';
            final category = itemData['category'] as String? ?? '';
            final qty = (inv['quantity'] as num?)?.toInt() ?? 1;
            final catColor = _catColor(category);
            final catIcon = _catIcon(category);

            return MouseRegion(
              cursor: SystemMouseCursors.basic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: catColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(catIcon, color: catColor, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _greenPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _greenPrimary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '×$qty',
                        style: const TextStyle(
                          color: _greenPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Empty Market State ─────────────────────────────────────────────────

  Widget _buildEmptyMarket() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront, color: Colors.grey.shade600, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Нет товаров в этой категории.',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Market Item Card Widget (stateful for hover) ─────────────────────────

class _MarketItemCardWidget extends StatefulWidget {
  final String name;
  final String category;
  final String categoryRu;
  final Color categoryColor;
  final IconData categoryIcon;
  final String description;
  final int price;
  final bool isLimited;
  final int currentStock;
  final bool isOutOfStock;
  final int ownedQty;
  final bool isPurchasing;
  final VoidCallback? onBuy;

  const _MarketItemCardWidget({
    required this.name,
    required this.category,
    required this.categoryRu,
    required this.categoryColor,
    required this.categoryIcon,
    required this.description,
    required this.price,
    required this.isLimited,
    required this.currentStock,
    required this.isOutOfStock,
    required this.ownedQty,
    required this.isPurchasing,
    this.onBuy,
  });

  @override
  State<_MarketItemCardWidget> createState() => _MarketItemCardWidgetState();
}

class _MarketItemCardWidgetState extends State<_MarketItemCardWidget> {
  bool _isHovered = false;

  String _formatCredits(dynamic value) {
    final v = (value as num?)?.toInt() ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onBuy != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 300,
        transform: _isHovered && widget.onBuy != null
            ? (Matrix4.identity()..scale(1.02))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered && widget.onBuy != null
                ? widget.categoryColor.withValues(alpha: 0.5)
                : _surfaceVariant,
            width: _isHovered && widget.onBuy != null ? 1.5 : 1,
          ),
          boxShadow: _isHovered && widget.onBuy != null
              ? [
                  BoxShadow(
                    color: widget.categoryColor.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: Icon + Name ──────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.categoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.categoryIcon,
                      color: widget.categoryColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Owned badge
                  if (widget.ownedQty > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _cyanSecondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _cyanSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'В инв.: ${widget.ownedQty}',
                        style: const TextStyle(
                          color: _cyanSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // ── Category Badge ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: widget.categoryColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  widget.categoryRu,
                  style: TextStyle(
                    color: widget.categoryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Description ──────────────────────────────────────────
              if (widget.description.isNotEmpty)
                Text(
                  widget.description,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              if (widget.description.isNotEmpty) const SizedBox(height: 12),

              // ── Price ────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.attach_money, color: _greenPrimary, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatCredits(widget.price)}',
                    style: const TextStyle(
                      color: _greenPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Stock indicator
                  if (widget.isLimited) ...[
                    Icon(
                      widget.isOutOfStock
                          ? Icons.block
                          : Icons.inventory_2_outlined,
                      color: widget.isOutOfStock
                          ? _dangerRed
                          : Colors.grey.shade500,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.isOutOfStock
                          ? 'Нет в наличии'
                          : 'Осталось: ${widget.currentStock}',
                      style: TextStyle(
                        color: widget.isOutOfStock
                            ? _dangerRed
                            : Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.all_inclusive, color: Colors.grey.shade600, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Неограниченно',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // ── Buy Button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: CyberButton(
                  text: widget.isOutOfStock ? 'НЕТ В НАЛИЧИИ' : 'КУПИТЬ',
                  icon: widget.isOutOfStock ? Icons.block : Icons.shopping_cart,
                  variant: widget.isOutOfStock
                      ? CyberButtonVariant.secondary
                      : CyberButtonVariant.primary,
                  height: 36,
                  isLoading: widget.isPurchasing,
                  onPressed: widget.onBuy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
