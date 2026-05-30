import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MarketScreen — PC Desktop
// ═══════════════════════════════════════════════════════════════════════════════
// Wide layout inside game_shell (sidebar already present).
// • Section toggle (Магазин / Инвентарь) as styled header buttons
// • Category row as horizontal tab bar (no TabBar widget)
// • Items in 3-column grid with wider cards
// • Item detail side-panel on the right when selected
// • Purchase confirmation as desktop AlertDialog
// • MouseRegion hover, neon cyberpunk on Color(0xFF0a0e17)
// • All game logic and Provider usage preserved
// ═══════════════════════════════════════════════════════════════════════════════

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  // ── View mode: shop or inventory ──
  bool _showInventory = false;

  // ── Selected item for detail panel ──
  Map<String, dynamic>? _selectedItem;

  // ── Category filter ──
  String _selectedCategory = 'Все';
  final List<String> _categories = const [
    'Все', 'Оборудование', 'Софт', 'Эксплойты', 'Инструменты',
  ];

  // ── Category metadata ──
  static const Map<String, String> _categoryMap = {
    'Оборудование': 'hardware',
    'Софт': 'software',
    'Эксплойты': 'exploits',
    'Инструменты': 'tools',
  };

  static const Map<String, String> _categoryDisplayNames = {
    'hardware': 'ОБОРУДОВАНИЕ',
    'software': 'СОФТ',
    'exploits': 'ЭКСПЛОЙТЫ',
    'tools': 'ИНСТРУМЕНТЫ',
  };

  // ── State ──
  List<Map<String, dynamic>> _marketItems = [];
  List<Map<String, dynamic>> _inventory = [];
  bool _isLoadingItems = false;
  bool _isLoadingInventory = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Data loading
  // ═════════════════════════════════════════════════════════════════════════════

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    _loadMarketItems();
  }

  Future<void> _loadMarketItems() async {
    setState(() {
      _isLoadingItems = true;
      _errorMessage = null;
      _selectedItem = null;
    });
    final game = context.read<GameProvider>();
    final category = _selectedCategory == 'Все'
        ? null
        : (_categoryMap[_selectedCategory] ?? _selectedCategory.toLowerCase());
    final items = await game.getMarketItems(category: category);
    if (!mounted) return;
    setState(() {
      _marketItems = items;
      _isLoadingItems = false;
    });
  }

  Future<void> _loadInventory() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    setState(() => _isLoadingInventory = true);
    final game = context.read<GameProvider>();
    final inv = await game.getPlayerInventory(auth.userId!);
    if (!mounted) return;
    setState(() {
      _inventory = inv;
      _isLoadingInventory = false;
    });
  }

  Future<void> _switchToInventory() {
    setState(() {
      _showInventory = true;
      _selectedItem = null;
    });
    _loadInventory();
  }

  Future<void> _switchToShop() {
    setState(() {
      _showInventory = false;
      _selectedItem = null;
    });
    _loadMarketItems();
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Purchase logic
  // ═════════════════════════════════════════════════════════════════════════════

  Future<void> _purchaseItem(Map<String, dynamic> item) async {
    final auth = context.read<AuthProvider>();
    final game = context.read<GameProvider>();
    if (auth.userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _PurchaseConfirmDialog(item: item, credits: game.credits),
    );
    if (confirmed != true) return;

    final success = await game.purchaseItem(
      playerId: auth.userId!,
      itemId: item['id'] as String,
      price: (item['price'] as num).toInt(),
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Куплено ${item['name'] ?? "Товар"}!'),
          backgroundColor: const Color(0xFF39FF14).withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadMarketItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(game.errorMessage ?? 'Покупка не удалась'),
          backgroundColor: const Color(0xFFFF0040).withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Helpers
  // ═════════════════════════════════════════════════════════════════════════════

  Color _categoryColor(String? category) {
    return switch (category?.toLowerCase()) {
      'оборудование' || 'hardware' => const Color(0xFFFF9800),
      'софт' || 'software' => const Color(0xFF00B0FF),
      'эксплойты' || 'exploits' => const Color(0xFFFF0040),
      'инструменты' || 'tools' => const Color(0xFF39FF14),
      _ => const Color(0xFF5a6578),
    };
  }

  IconData _categoryIcon(String? category) {
    return switch (category?.toLowerCase()) {
      'оборудование' || 'hardware' => Icons.memory_rounded,
      'софт' || 'software' => Icons.apps_rounded,
      'эксплойты' || 'exploits' => Icons.bug_report_rounded,
      'инструменты' || 'tools' => Icons.build_rounded,
      _ => Icons.category_rounded,
    };
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Build
  // ═════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: title + section toggle + credits ──
          _buildHeader(),
          const SizedBox(height: 16),

          // ── Category filter row (shop only) ──
          if (!_showInventory) _buildCategoryRow(),
          if (!_showInventory) const SizedBox(height: 12),

          // ── Content: grid + optional detail panel ──
          Expanded(
            child: _showInventory
                ? _buildInventoryContent()
                : _buildShopContent(),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Header
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    final game = context.watch<GameProvider>();

    return Row(
      children: [
        // ── Title ──
        const Text(
          'ЧЁРНЫЙ РЫНОК',
          style: TextStyle(
            color: Color(0xFFFF9800),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.5,
            fontFamily: 'monospace',
            shadows: [Shadow(color: Color(0x80FF9800), blurRadius: 12)],
          ),
        ),

        const SizedBox(width: 20),

        // ── Section toggle buttons ──
        _SectionToggle(
          label: 'МАГАЗИН',
          icon: Icons.storefront_rounded,
          isSelected: !_showInventory,
          color: const Color(0xFFFF9800),
          onTap: _switchToShop,
        ),
        const SizedBox(width: 8),
        _SectionToggle(
          label: 'ИНВЕНТАРЬ',
          icon: Icons.inventory_2_rounded,
          isSelected: _showInventory,
          color: const Color(0xFF00B0FF),
          onTap: _switchToInventory,
        ),

        const Spacer(),

        // ── Credits display ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 20),
              const SizedBox(width: 6),
              Text(
                '${game.credits}',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'CR',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Category row (horizontal row at top)
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildCategoryRow() {
    return Row(
      children: _categories.map((cat) {
        final isSelected = cat == _selectedCategory;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: _CategoryButton(
            label: cat.toUpperCase(),
            icon: cat == 'Все' ? Icons.select_all_rounded : _categoryIcon(cat),
            color: cat == 'Все'
                ? const Color(0xFF00F0FF)
                : _categoryColor(cat),
            isSelected: isSelected,
            onTap: () {
              if (_selectedCategory != cat) {
                setState(() => _selectedCategory = cat);
                _loadMarketItems();
              }
            },
          ),
        );
      }).toList(),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Shop content: grid + detail panel
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildShopContent() {
    if (_isLoadingItems) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF9800)),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_marketItems.isEmpty) {
      return _buildEmptyState(
        Icons.storefront_outlined,
        'Нет товаров в этой категории',
        'Попробуйте другой фильтр или зайдите позже',
      );
    }

    final game = context.watch<GameProvider>();

    return Row(
      children: [
        // ── 3-column grid ──
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
            ),
            itemCount: _marketItems.length,
            itemBuilder: (context, index) {
              final item = _marketItems[index];
              final isSelected = _selectedItem != null &&
                  _selectedItem!['id'] == item['id'];
              return _MarketItemCard(
                item: item,
                isSelected: isSelected,
                onTap: () => setState(() => _selectedItem = item),
                onBuy: () => _purchaseItem(item),
                canAfford: game.credits >= ((item['price'] as num?)?.toInt() ?? 0),
                categoryColor: _categoryColor(item['category'] as String?),
                categoryIcon: _categoryIcon(item['category'] as String?),
              );
            },
          ),
        ),

        // ── Detail side panel ──
        if (_selectedItem != null) ...[
          const SizedBox(width: 16),
          _ItemDetailPanel(
            item: _selectedItem!,
            categoryColor: _categoryColor(_selectedItem!['category'] as String?),
            categoryIcon: _categoryIcon(_selectedItem!['category'] as String?),
            canAfford: game.credits >=
                ((_selectedItem!['price'] as num?)?.toInt() ?? 0),
            onBuy: () => _purchaseItem(_selectedItem!),
            onClose: () => setState(() => _selectedItem = null),
          ),
        ],
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Inventory content
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildInventoryContent() {
    if (_isLoadingInventory) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00B0FF)),
      );
    }

    if (_inventory.isEmpty) {
      return _buildEmptyState(
        Icons.inventory_2_outlined,
        'Инвентарь пуст',
        'Купите товары на вкладке Магазин',
      );
    }

    // Desktop inventory: 2-column grid of wider cards
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 3.2,
      ),
      itemCount: _inventory.length,
      itemBuilder: (context, index) {
        final invItem = _inventory[index];
        final marketItem = invItem['market_items'] as Map<String, dynamic>?;
        final quantity = (invItem['quantity'] as num?)?.toInt() ?? 1;
        final cat = marketItem?['category'] as String?;
        final catColor = _categoryColor(cat);
        final catIcon = _categoryIcon(cat);

        return _InventoryCard(
          name: marketItem?['name'] as String? ?? 'Неизвестный товар',
          description: marketItem?['description'] as String? ?? 'Нет описания',
          quantity: quantity,
          categoryLabel:
              (_categoryDisplayNames[cat] ?? cat ?? 'Н/Д').toUpperCase(),
          categoryColor: catColor,
          categoryIcon: catIcon,
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Empty / Error states
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: const Color(0xFF3a4555)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6a7080),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF3a4555), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFFF0040)),
          const SizedBox(height: 12),
          Text(_errorMessage!, style: const TextStyle(color: Color(0xFFe0e6ed))),
          const SizedBox(height: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _loadMarketItems,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0040).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF0040).withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'ПОВТОРИТЬ',
                  style: TextStyle(
                    color: Color(0xFFFF0040),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Section toggle button (Магазин / Инвентарь)
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionToggle extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _SectionToggle({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SectionToggle> createState() => _SectionToggleState();
}

class _SectionToggleState extends State<_SectionToggle> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.color.withValues(alpha: 0.12)
                : (_isHovered
                    ? widget.color.withValues(alpha: 0.05)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? widget.color.withValues(alpha: 0.4)
                  : widget.color.withValues(alpha: (_isHovered ? 0.2 : 0.08)),
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.2),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isSelected
                    ? widget.color
                    : const Color(0xFF5a6578),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: widget.isSelected
                      ? widget.color
                      : const Color(0xFF6a7080),
                  fontFamily: 'monospace',
                  shadows: widget.isSelected
                      ? [Shadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 8)]
                      : [],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Category button (horizontal row at top)
// ═══════════════════════════════════════════════════════════════════════════════

class _CategoryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CategoryButton> createState() => _CategoryButtonState();
}

class _CategoryButtonState extends State<_CategoryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.color.withValues(alpha: 0.15)
                : (_isHovered
                    ? const Color(0xFF1e2a3a).withValues(alpha: 0.6)
                    : const Color(0xFF0d1220)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isSelected
                  ? widget.color.withValues(alpha: 0.5)
                  : const Color(0xFF1e2a3a),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.isSelected ? widget.color : const Color(0xFF5a6578),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: widget.isSelected
                      ? widget.color
                      : const Color(0xFF6a7080),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Market item card (grid tile with hover + selection)
// ═══════════════════════════════════════════════════════════════════════════════

class _MarketItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onBuy;
  final bool canAfford;
  final Color categoryColor;
  final IconData categoryIcon;

  const _MarketItemCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onBuy,
    required this.canAfford,
    required this.categoryColor,
    required this.categoryIcon,
  });

  @override
  State<_MarketItemCard> createState() => _MarketItemCardState();
}

class _MarketItemCardState extends State<_MarketItemCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.item['name'] as String? ?? 'Неизвестный товар';
    final description = widget.item['description'] as String? ?? '';
    final price = (widget.item['price'] as num?)?.toInt() ?? 0;
    final stock = (widget.item['stock'] as num?)?.toInt() ?? 0;
    final category = widget.item['category'] as String? ?? '';
    final outOfStock = stock <= 0;
    final borderColor = widget.isSelected
        ? widget.categoryColor
        : (_isHovered
            ? widget.categoryColor.withValues(alpha: 0.35)
            : const Color(0xFF1e2a3a));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.categoryColor.withValues(alpha: 0.08)
                : (_isHovered
                    ? const Color(0xFF111827)
                    : const Color(0xFF0d1220)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: widget.isSelected ? 1.5 : 1),
            boxShadow: [
              if (widget.isSelected)
                BoxShadow(
                  color: widget.categoryColor.withValues(alpha: 0.15),
                  blurRadius: 16,
                ),
              if (_isHovered && !widget.isSelected)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header strip ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.categoryColor.withValues(alpha: 0.06),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: Row(
                  children: [
                    Icon(widget.categoryIcon, color: widget.categoryColor, size: 18),
                    const Spacer(),
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: widget.categoryColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    // Stock indicator
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (outOfStock
                            ? const Color(0xFFFF0040).withValues(alpha: 0.12)
                            : const Color(0xFF39FF14).withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        outOfStock ? 'НЕТ' : '$stock шт',
                        style: TextStyle(
                          color: outOfStock
                              ? const Color(0xFFFF0040)
                              : const Color(0xFF39FF14),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Item info ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFFe0e6ed),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Color(0xFF5a6578),
                          fontSize: 12,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Price row + buy ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF1e2a3a))),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(9)),
                ),
                child: Row(
                  children: [
                    // Price
                    const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$price',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    // Buy button
                    MouseRegion(
                      cursor: widget.canAfford && !outOfStock
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.forbidden,
                      child: GestureDetector(
                        onTap: widget.canAfford && !outOfStock ? widget.onBuy : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.canAfford && !outOfStock
                                ? widget.categoryColor.withValues(alpha: 0.15)
                                : const Color(0xFF1e2a3a).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: widget.canAfford && !outOfStock
                                  ? widget.categoryColor.withValues(alpha: 0.4)
                                  : const Color(0xFF1e2a3a),
                            ),
                          ),
                          child: Text(
                            'КУПИТЬ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontFamily: 'monospace',
                              color: widget.canAfford && !outOfStock
                                  ? widget.categoryColor
                                  : const Color(0xFF3a4555),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Item detail side panel (right side when selected)
// ═══════════════════════════════════════════════════════════════════════════════

class _ItemDetailPanel extends StatelessWidget {
  final Map<String, dynamic> item;
  final Color categoryColor;
  final IconData categoryIcon;
  final bool canAfford;
  final VoidCallback onBuy;
  final VoidCallback onClose;

  const _ItemDetailPanel({
    required this.item,
    required this.categoryColor,
    required this.categoryIcon,
    required this.canAfford,
    required this.onBuy,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? 'Неизвестный товар';
    final description = item['description'] as String? ?? '';
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final stock = (item['stock'] as num?)?.toInt() ?? 0;
    final category = item['category'] as String? ?? '';
    final rarity = item['rarity'] as String? ?? 'Обычный';
    final outOfStock = stock <= 0;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF0d1220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withValues(alpha: 0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Panel header ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(categoryIcon, color: categoryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: categoryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(color: categoryColor.withValues(alpha: 0.4), blurRadius: 8),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: categoryColor.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1e2a3a).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Color(0xFF6a7080),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rarity
                  _DetailRow(
                    label: 'РЕДКОСТЬ',
                    value: rarity,
                    valueColor: const Color(0xFF00F0FF),
                  ),
                  const SizedBox(height: 12),

                  // Stock
                  _DetailRow(
                    label: 'НА СКЛАДЕ',
                    value: outOfStock ? 'Нет в наличии' : '$stock шт',
                    valueColor: outOfStock
                        ? const Color(0xFFFF0040)
                        : const Color(0xFF39FF14),
                  ),
                  const SizedBox(height: 12),

                  // Price
                  _DetailRow(
                    label: 'ЦЕНА',
                    value: '$price CR',
                    valueColor: const Color(0xFFFFD700),
                    icon: Icons.monetization_on_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  const Divider(color: Color(0xFF1e2a3a), height: 24),

                  // Description
                  const Text(
                    'ОПИСАНИЕ',
                    style: TextStyle(
                      color: Color(0xFF3a4555),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description.isEmpty ? 'Описание недоступно' : description,
                    style: const TextStyle(
                      color: Color(0xFF8a95a5),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),

                  if (!canAfford && !outOfStock) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0040).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFF0040).withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFFF0040), size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Недостаточно кредитов!',
                            style: TextStyle(
                              color: Color(0xFFFF0040),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Buy button ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1e2a3a))),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
            ),
            child: MouseRegion(
              cursor: canAfford && !outOfStock
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.forbidden,
              child: GestureDetector(
                onTap: canAfford && !outOfStock ? onBuy : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: canAfford && !outOfStock
                        ? categoryColor.withValues(alpha: 0.15)
                        : const Color(0xFF1e2a3a).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: canAfford && !outOfStock
                          ? categoryColor.withValues(alpha: 0.5)
                          : const Color(0xFF1e2a3a),
                    ),
                    boxShadow: canAfford && !outOfStock
                        ? [
                            BoxShadow(
                              color: categoryColor.withValues(alpha: 0.2),
                              blurRadius: 12,
                            ),
                          ]
                        : [],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_rounded,
                        size: 16,
                        color: canAfford && !outOfStock
                            ? categoryColor
                            : const Color(0xFF3a4555),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        outOfStock ? 'НЕТ В НАЛИЧИИ' : 'КУПИТЬ ЗА $price CR',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                          color: canAfford && !outOfStock
                              ? categoryColor
                              : const Color(0xFF3a4555),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Detail panel row helper
// ═══════════════════════════════════════════════════════════════════════════════

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final IconData? icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5a6578),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontFamily: 'monospace',
          ),
        ),
        const Spacer(),
        if (icon != null) ...[
          Icon(icon, color: valueColor, size: 14),
          const SizedBox(width: 4),
        ],
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Inventory card (desktop wider row)
// ═══════════════════════════════════════════════════════════════════════════════

class _InventoryCard extends StatefulWidget {
  final String name;
  final String description;
  final int quantity;
  final String categoryLabel;
  final Color categoryColor;
  final IconData categoryIcon;

  const _InventoryCard({
    required this.name,
    required this.description,
    required this.quantity,
    required this.categoryLabel,
    required this.categoryColor,
    required this.categoryIcon,
  });

  @override
  State<_InventoryCard> createState() => _InventoryCardState();
}

class _InventoryCardState extends State<_InventoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.default,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isHovered
              ? const Color(0xFF111827)
              : const Color(0xFF0d1220),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isHovered
                ? widget.categoryColor.withValues(alpha: 0.3)
                : const Color(0xFF1e2a3a),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.categoryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.categoryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                widget.categoryIcon,
                color: widget.categoryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Name + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      color: Color(0xFFe0e6ed),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.description,
                    style: const TextStyle(
                      color: Color(0xFF5a6578),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Category label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.categoryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: widget.categoryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                widget.categoryLabel,
                style: TextStyle(
                  color: widget.categoryColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Quantity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: widget.categoryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.categoryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'x${widget.quantity}',
                style: TextStyle(
                  color: widget.categoryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Purchase confirmation dialog (desktop style)
// ═══════════════════════════════════════════════════════════════════════════════

class _PurchaseConfirmDialog extends StatelessWidget {
  final Map<String, dynamic> item;
  final int credits;

  const _PurchaseConfirmDialog({required this.item, required this.credits});

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? 'Неизвестный товар';
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final canAfford = credits >= price;
    final description = item['description'] as String? ?? '';
    final stock = (item['stock'] as num?)?.toInt() ?? 0;
    final outOfStock = stock <= 0;

    return Dialog(
      backgroundColor: const Color(0xFF0d1220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFF9800), width: 1),
        // Neon glow border via shadow
      ),
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF9800).withValues(alpha: 0.08),
              blurRadius: 30,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Dialog header ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_rounded,
                      color: Color(0xFFFF9800),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'ПОДТВЕРДИТЬ ПОКУПКУ',
                      style: TextStyle(
                        color: Color(0xFFFF9800),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                        shadows: [
                          Shadow(color: Color(0x80FF9800), blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                  // Close button
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1e2a3a).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFF6a7080),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item name
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFFe0e6ed),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF6a7080),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Price box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ЦЕНА',
                          style: TextStyle(
                            color: Color(0xFF5a6578),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.monetization_on_rounded,
                                color: Color(0xFFFFD700), size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '$price CR',
                              style: TextStyle(
                                color: canAfford
                                    ? const Color(0xFFFFD700)
                                    : const Color(0xFFFF0040),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Balance
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1e2a3a).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1e2a3a)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'БАЛАНС',
                          style: TextStyle(
                            color: Color(0xFF5a6578),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          '$credits CR',
                          style: TextStyle(
                            color: canAfford
                                ? const Color(0xFF39FF14)
                                : const Color(0xFFFF0040),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error message
                  if (!canAfford) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0040).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFF0040).withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFFF0040), size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Недостаточно кредитов!',
                            style: TextStyle(
                              color: Color(0xFFFF0040),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (outOfStock && canAfford) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.inventory_2_rounded,
                              color: Color(0xFFFF9800), size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Товар закончился на складе!',
                            style: TextStyle(
                              color: Color(0xFFFF9800),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Actions ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  // Cancel
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1e2a3a).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF1e2a3a)),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'ОТМЕНА',
                            style: TextStyle(
                              color: Color(0xFF6a7080),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Buy
                  Expanded(
                    child: MouseRegion(
                      cursor: canAfford && !outOfStock
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.forbidden,
                      child: GestureDetector(
                        onTap: canAfford && !outOfStock
                            ? () => Navigator.pop(context, true)
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: canAfford && !outOfStock
                                ? const Color(0xFFFF9800).withValues(alpha: 0.15)
                                : const Color(0xFF1e2a3a).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: canAfford && !outOfStock
                                  ? const Color(0xFFFF9800).withValues(alpha: 0.5)
                                  : const Color(0xFF1e2a3a),
                            ),
                            boxShadow: canAfford && !outOfStock
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF9800)
                                          .withValues(alpha: 0.2),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'ПОКУПИТЬ',
                            style: TextStyle(
                              color: Color(0xFFFF9800),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
