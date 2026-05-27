import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatMessage {
  final String id;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isOwn;
  final bool isSystem;
  final String? senderClanTag;

  _ChatMessage({
    required this.id,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isOwn,
    this.isSystem = false,
    this.senderClanTag,
  });
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final List<_ChatMessage> _globalMessages = [];
  final List<_ChatMessage> _clanMessages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  int _onlineCount = 247;
  bool _isTyping = false;
  final _random = Random();

  // Simulated users for demo messages
  static const _botNames = [
    ('NetRunner_X', null),
    ('PhantomGhost', '[SYN]'),
    ('ByteStorm', null),
    ('DarkPulse', '[NMX]'),
    ('CyberViper', null),
    ('ZeroCool', '[DFT]'),
    ('IcePhreak', null),
    ('NeonShadow', null),
    ('DataWraith', '[SYN]'),
    ('HexHunter', null),
  ];

  static const _sampleMessages = [
    'Кто хочет обменять модули ЦПУ?',
    'Только что получил эксплойт нулевого дня с рынка!',
    'Остерегайтесь PhantomGhost — сильная защита сети.',
    'Ищу рекрутов в клан. Пишите в личку.',
    'SQL-инъекция сработала идеально на моей последней цели.',
    'Кто знает хорошую стратегию брутфорса?',
    'Чёрный рынок пополнился! Загляните.',
    'Только что достиг 25 уровня, чувствую силу.',
    'DDoS-атака на сектор 7...',
    'Новый клан создан — ищем опытных хакеров.',
    'Мой малварный груз принёс 5000 кредитов!',
    'Кто контролирует узлы в центре?',
    'Совет: всегда улучшайте канал перед атакой.',
    'Этот фишинговый набор невероятен — 90% успеха.',
    'Кто продаёт железо со скидкой?',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Seed initial messages
    final now = DateTime.now();
    for (int i = 0; i < 8; i++) {
      final (name, tag) = _botNames[i % _botNames.length];
      _globalMessages.add(_ChatMessage(
        id: 'init_$i',
        senderName: name,
        content: _sampleMessages[i % _sampleMessages.length],
        timestamp: now.subtract(Duration(minutes: 30 - i * 3)),
        isOwn: false,
        senderClanTag: tag,
      ));
    }

    // Seed system messages
    _globalMessages.insert(0, _ChatMessage(
      id: 'sys_1',
      senderName: 'SYSTEM',
      content: 'Добро пожаловать в общий канал связи. Будьте бдительны, оставайтесь анонимны.',
      timestamp: now.subtract(const Duration(hours: 1)),
      isOwn: false,
      isSystem: true,
    ));

    // Seed a couple clan messages
    _clanMessages.add(_ChatMessage(
      id: 'clan_sys_1',
      senderName: 'SYSTEM',
      content: 'Клан-канал — только координация. Никаких утечек.',
      timestamp: now.subtract(const Duration(minutes: 45)),
      isOwn: false,
      isSystem: true,
    ));
    _clanMessages.add(_ChatMessage(
      id: 'clan_msg_1',
      senderName: 'PhantomGhost',
      content: 'Рейд в 22:00. Все готовы?',
      timestamp: now.subtract(const Duration(minutes: 20)),
      isOwn: false,
      senderClanTag: '[SYN]',
    ));

    // Auto-scroll to bottom after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  List<_ChatMessage> get _currentMessages =>
      _tabController.index == 0 ? _globalMessages : _clanMessages;

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final senderName = auth.displayName;

    final message = _ChatMessage(
      id: 'own_${DateTime.now().millisecondsSinceEpoch}',
      senderName: senderName,
      content: text,
      timestamp: DateTime.now(),
      isOwn: true,
    );

    setState(() {
      if (_tabController.index == 0) {
        _globalMessages.add(message);
      } else {
        _clanMessages.add(message);
      }
    });

    _textController.clear();
    _inputFocus.unfocus();
    _scrollToBottom();

    // Simulate bot response after a delay
    _simulateBotReply();
  }

  void _simulateBotReply() {
    final delay = Duration(seconds: 1 + _random.nextInt(3));
    Future.delayed(delay, () {
      if (!mounted) return;
      final (name, tag) = _botNames[_random.nextInt(_botNames.length)];
      final reply = _ChatMessage(
        id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
        senderName: name,
        content: _sampleMessages[_random.nextInt(_sampleMessages.length)],
        timestamp: DateTime.now(),
        isOwn: false,
        senderClanTag: tag,
      );
      setState(() {
        if (_tabController.index == 0) {
          _globalMessages.add(reply);
        } else {
          _clanMessages.add(reply);
        }
      });
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('СВЯЗЬ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.public, size: 16),
                  SizedBox(width: 6),
                  Text('ОБЩИЙ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.groups, size: 16),
                  SizedBox(width: 6),
                  Text('КЛАН', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
            ),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          indicatorSize: TabBarIndicatorSize.tab,
        ),
      ),
      body: Column(
        children: [
          // ── Online Users Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_onlineCount операторов онлайн',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (_isTyping)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'кто-то печатает',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // ── Messages List ──
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _currentMessages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_currentMessages[index], theme);
              },
            ),
          ),

          // ── Input Area ──
          _buildInputArea(theme, auth),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, ThemeData theme) {
    if (msg.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 12, color: theme.colorScheme.outline.withValues(alpha: 0.6)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    msg.content,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isOwn = msg.isOwn;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isOwn) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.3),
              child: Text(
                msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // ── Sender info ──
                if (!isOwn)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (msg.senderClanTag != null) ...[
                          Text(
                            '${msg.senderClanTag} ',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                        Text(
                          msg.senderName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary.withValues(alpha: 0.8),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(msg.timestamp),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline.withValues(alpha: 0.5),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                // ── Message bubble ──
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isOwn ? const Radius.circular(16) : const Radius.circular(4),
                      bottomRight: isOwn ? const Radius.circular(4) : const Radius.circular(16),
                    ),
                    color: isOwn
                        ? Colors.cyan.withValues(alpha: 0.15)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                    border: Border.all(
                      color: isOwn
                          ? Colors.cyan.withValues(alpha: 0.3)
                          : theme.colorScheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    msg.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: isOwn
                          ? Colors.cyanAccent.shade200
                          : theme.colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
                if (isOwn)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, right: 4),
                    child: Text(
                      _formatTime(msg.timestamp),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline.withValues(alpha: 0.5),
                        fontSize: 9,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isOwn) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Terminal prefix
            Text(
              '> ',
              style: TextStyle(
                color: Colors.greenAccent,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            // Text field
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _inputFocus,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Введите сообщение...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.cyan.withValues(alpha: 0.5)),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface.withValues(alpha: 0.8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            Container(
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.cyanAccent, size: 20),
                onPressed: _sendMessage,
                tooltip: 'Отправить',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
