import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'Все';
  final List<String> _categories = const ['Все', 'Оборудование', 'Софт', 'Эксплойты', 'Инструменты'];

  List<Map<String, dynamic>> _marketItems = [];
  List<Map<String, dynamic>> _inventory = [];
  bool _isLoadingItems = false;
  bool _isLoadingInventory = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      _loadInventory();
    }
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    _loadMarketItems();
  }

  Future<void> _loadMarketItems() async {
    setState(() {
      _isLoadingItems = true;
      _errorMessage = null;
    });
    final game = context.read<GameProvider>();
    final category = _selectedCategory == 'Все' ? null : _selectedCategory.toLowerCase();
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
          backgroundColor: Colors.greenAccent.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadMarketItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(game.errorMessage ?? 'Покупка не удалась'),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _categoryColor(String? category) {
    return switch (category?.toLowerCase()) {
      'оборудование' || 'hardware' => Colors.orangeAccent,
      'софт' || 'software' => Colors.blueAccent,
      'эксплойты' || 'exploits' => Colors.redAccent,
      'инструменты' || 'tools' => Colors.greenAccent,
      _ => Colors.grey,
    };
  }

  IconData _categoryIcon(String? category) {
    return switch (category?.toLowerCase()) {
      'оборудование' || 'hardware' => Icons.memory,
      'софт' || 'software' => Icons.apps,
      'эксплойты' || 'exploits' => Icons.bug_report,
      'инструменты' || 'tools' => Icons.build,
      _ => Icons.category,
    };
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ЧЁРНЫЙ РЫНОК'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'МАГАЗИН', icon: Icon(Icons.storefront, size: 18)),
            Tab(text: 'ИНВЕНТАРЬ', icon: Icon(Icons.inventory_2, size: 18)),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          indicatorSize: TabBarIndicatorSize.tab,
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amberAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: Colors.amberAccent, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${game.credits}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildShopTab(theme, game),
          _buildInventoryTab(theme),
        ],
      ),
    );
  }

  Widget _buildShopTab(ThemeData theme, GameProvider game) {
    return Column(
      children: [
        // ── Category Filter Chips ──
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = cat == _selectedCategory;
              return FilterChip(
                label: Text(
                  cat.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedCategory = cat);
                  _loadMarketItems();
                },
                selectedColor: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                side: BorderSide(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              );
            },
          ),
        ),
        const Divider(height: 1),

        // ── Items Grid ──
        Expanded(
          child: _isLoadingItems
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _loadMarketItems, child: const Text('ПОВТОРИТЬ')),
                        ],
                      ),
                    )
                  : _marketItems.isEmpty
                      ? _buildEmptyState(theme, Icons.storefront_outlined, 'Нет товаров в этой категории', 'Попробуйте другой фильтр или зайдите позже')
                      : RefreshIndicator(
                          onRefresh: _loadMarketItems,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: _marketItems.length,
                            itemBuilder: (context, index) {
                              return _MarketItemCard(
                                item: _marketItems[index],
                                onBuy: () => _purchaseItem(_marketItems[index]),
                                canAfford: game.credits >= ((_marketItems[index]['price'] as num?)?.toInt() ?? 0),
                                categoryColor: _categoryColor(_marketItems[index]['category'] as String?),
                                categoryIcon: _categoryIcon(_marketItems[index]['category'] as String?),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildInventoryTab(ThemeData theme) {
    return _isLoadingInventory
        ? const Center(child: CircularProgressIndicator())
        : _inventory.isEmpty
            ? _buildEmptyState(theme, Icons.inventory_2_outlined, 'Инвентарь пуст', 'Купите товары на вкладке Магазин')
            : RefreshIndicator(
                onRefresh: _loadInventory,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _inventory.length,
                  itemBuilder: (context, index) {
                    final invItem = _inventory[index];
                    final marketItem = invItem['market_items'] as Map<String, dynamic>?;
                    final quantity = (invItem['quantity'] as num?)?.toInt() ?? 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _categoryColor(marketItem?['category'] as String?).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _categoryIcon(marketItem?['category'] as String?),
                              color: _categoryColor(marketItem?['category'] as String?),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      marketItem?['name'] as String? ?? 'Неизвестный товар',
                                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _categoryColor(marketItem?['category'] as String?).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'x$quantity',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: _categoryColor(marketItem?['category'] as String?),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  marketItem?['description'] as String? ?? 'Нет описания',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _categoryColor(marketItem?['category'] as String?).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _categoryColor(marketItem?['category'] as String?).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              (marketItem?['category'] as String?)?.toUpperCase() ?? 'Н/Д',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _categoryColor(marketItem?['category'] as String?),
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
  }

  Widget _buildEmptyState(ThemeData theme, IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

class _MarketItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onBuy;
  final bool canAfford;
  final Color categoryColor;
  final IconData categoryIcon;

  const _MarketItemCard({
    required this.item,
    required this.onBuy,
    required this.canAfford,
    required this.categoryColor,
    required this.categoryIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = item['name'] as String? ?? 'Неизвестный товар';
    final description = item['description'] as String? ?? '';
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final stock = (item['stock'] as num?)?.toInt() ?? 0;
    final category = item['category'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header with icon and category badge ──
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(categoryIcon, color: categoryColor, size: 20),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: categoryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Item Info ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    'На складе: $stock',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: stock > 5 ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Price + Buy ──
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amberAccent, size: 14),
                    const SizedBox(width: 2),
                    Text(
                      '$price',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    onPressed: canAfford && stock > 0 ? onBuy : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: canAfford
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.outline,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('КУПИТЬ'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseConfirmDialog extends StatelessWidget {
  final Map<String, dynamic> item;
  final int credits;

  const _PurchaseConfirmDialog({required this.item, required this.credits});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = item['name'] as String? ?? 'Неизвестный товар';
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final canAfford = credits >= price;
    final description = item['description'] as String? ?? '';

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      title: Row(
        children: [
          Icon(Icons.shopping_cart, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 10),
          const Text('Подтвердить Покупку'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Цена:', style: theme.textTheme.bodyMedium),
                Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amberAccent, size: 18),
                    const SizedBox(width: 4),
                    Text('$price CR', style: theme.textTheme.bodyMedium?.copyWith(
                      color: canAfford ? Colors.amberAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Баланс: $credits CR',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (!canAfford)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '⚠ Недостаточно кредитов!',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ОТМЕНА'),
        ),
        ElevatedButton(
          onPressed: canAfford ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
          ),
          child: const Text('ПОКУПИТЬ'),
        ),
      ],
    );
  }
}
