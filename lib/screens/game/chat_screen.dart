import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  factory _ChatMessage.fromSupabase(Map<String, dynamic> row, String? myUserId) {
    return _ChatMessage(
      id: row['id'] as String,
      senderName: row['sender_name'] as String? ?? 'Аноним',
      content: row['content'] as String? ?? '',
      timestamp: DateTime.parse(row['created_at'] as String),
      isOwn: row['sender_id'] == myUserId,
      senderClanTag: row['sender_clan_tag'] as String?,
    );
  }
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final List<_ChatMessage> _globalMessages = [];
  final List<_ChatMessage> _clanMessages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  bool _isLoading = false;
  bool _isTyping = false;
  bool _hasMoreGlobal = true;
  bool _hasMoreClan = true;

  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _globalChannel;
  RealtimeChannel? _clanChannel;
  String? _myUserId;
  String? _myClanId;

  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    _myUserId = _supabase.auth.currentUser?.id;

    if (_myUserId != null) {
      _loadInitialData();
      _subscribeToChannels();
    }
  }

  @override
  void dispose() {
    _globalChannel?.unsubscribe();
    _clanChannel?.unsubscribe();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ─── Data Loading ────────────────────────────────────────────────────────

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Load user's clan_id
      final profile = await _supabase
          .from('profiles')
          .select('clan_id, clan:clans(tag)')
          .eq('id', _myUserId!)
          .single();

      _myClanId = profile['clan_id'] as String?;

      // Load global messages
      await _loadGlobalMessages();
      // Load clan messages if in clan
      if (_myClanId != null) {
        await _loadClanMessages();
      }
    } catch (e) {
      debugPrint('Error loading chat data: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _loadGlobalMessages() async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select('*, profiles!inner(username, clan:clans(tag))')
          .isFilter('clan_id', null)
          .order('created_at', ascending: false)
          .limit(_pageSize);

      final messages = (response as List)
          .map((row) {
            final profiles = row['profiles'] as Map<String, dynamic>?;
            final clan = profiles?['clan'] as Map<String, dynamic>?;
            return _ChatMessage(
              id: row['id'] as String,
              senderName: profiles?['username'] as String? ?? 'Аноним',
              content: row['content'] as String? ?? '',
              timestamp: DateTime.parse(row['created_at'] as String),
              isOwn: row['sender_id'] == _myUserId,
              senderClanTag: clan?['tag'] as String?,
            );
          })
          .toList()
          .reversed
          .toList();

      if (mounted) {
        setState(() {
          _globalMessages
            ..clear()
            ..addAll(messages);
          _hasMoreGlobal = messages.length >= _pageSize;
        });
      }
    } catch (e) {
      debugPrint('Error loading global messages: $e');
    }
  }

  Future<void> _loadClanMessages() async {
    if (_myClanId == null) return;
    try {
      final response = await _supabase
          .from('chat_messages')
          .select('*, profiles!inner(username, clan:clans(tag))')
          .eq('clan_id', _myClanId!)
          .order('created_at', ascending: false)
          .limit(_pageSize);

      final messages = (response as List)
          .map((row) {
            final profiles = row['profiles'] as Map<String, dynamic>?;
            final clan = profiles?['clan'] as Map<String, dynamic>?;
            return _ChatMessage(
              id: row['id'] as String,
              senderName: profiles?['username'] as String? ?? 'Аноним',
              content: row['content'] as String? ?? '',
              timestamp: DateTime.parse(row['created_at'] as String),
              isOwn: row['sender_id'] == _myUserId,
              senderClanTag: clan?['tag'] as String?,
            );
          })
          .toList()
          .reversed
          .toList();

      if (mounted) {
        setState(() {
          _clanMessages
            ..clear()
            ..addAll(messages);
          _hasMoreClan = messages.length >= _pageSize;
        });
      }
    } catch (e) {
      debugPrint('Error loading clan messages: $e');
    }
  }

  // ─── Realtime Subscriptions ──────────────────────────────────────────────

  void _subscribeToChannels() {
    // Global chat channel
    _globalChannel = _supabase
        .channel('public:chat_messages:global')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'clan_id',
            value: 'null',
          ),
          callback: _onGlobalMessage,
        )
        .subscribe();

    // Clan chat channel
    if (_myClanId != null) {
      _clanChannel = _supabase
          .channel('public:chat_messages:clan_$_myClanId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'clan_id',
              value: _myClanId,
            ),
            callback: _onClanMessage,
          )
          .subscribe();
    }
  }

  void _onGlobalMessage(PostgresChangePayload payload) {
    if (!mounted) return;
    final row = payload.newRecord as Map<String, dynamic>;
    final msg = _ChatMessage(
      id: row['id'] as String,
      senderName: row['sender_name'] as String? ?? 'Аноним',
      content: row['content'] as String? ?? '',
      timestamp: DateTime.parse(row['created_at'] as String),
      isOwn: row['sender_id'] == _myUserId,
    );

    setState(() => _globalMessages.add(msg));
    if (_tabController.index == 0) {
      _scrollToBottom();
    }
  }

  void _onClanMessage(PostgresChangePayload payload) {
    if (!mounted) return;
    final row = payload.newRecord as Map<String, dynamic>;
    final msg = _ChatMessage(
      id: row['id'] as String,
      senderName: row['sender_name'] as String? ?? 'Аноним',
      content: row['content'] as String? ?? '',
      timestamp: DateTime.parse(row['created_at'] as String),
      isOwn: row['sender_id'] == _myUserId,
    );

    setState(() => _clanMessages.add(msg));
    if (_tabController.index == 1) {
      _scrollToBottom();
    }
  }

  // ─── Send Message ────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _myUserId == null) return;

    final auth = context.read<AuthProvider>();
    final senderName = auth.displayName;
    final isClanTab = _tabController.index == 1;

    // Validate clan membership for clan messages
    if (isClanTab && _myClanId == null) {
      _showSnackBar('Вступите в клан для клан-чата', Colors.orangeAccent);
      return;
    }

    // Optimistic UI update
    final optimisticMsg = _ChatMessage(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      senderName: senderName,
      content: text,
      timestamp: DateTime.now(),
      isOwn: true,
      senderClanTag: isClanTab ? '[КЛАН]' : null,
    );

    setState(() {
      if (isClanTab) {
        _clanMessages.add(optimisticMsg);
      } else {
        _globalMessages.add(optimisticMsg);
      }
    });

    _textController.clear();
    _inputFocus.unfocus();
    _scrollToBottom();

    try {
      await _supabase.from('chat_messages').insert({
        'sender_id': _myUserId,
        'sender_name': senderName,
        'content': text,
        'clan_id': isClanTab ? _myClanId : null,
      });
    } catch (e) {
      if (!mounted) return;
      // Remove optimistic message on error
      setState(() {
        if (isClanTab) {
          _clanMessages.remove(optimisticMsg);
        } else {
          _globalMessages.remove(optimisticMsg);
        }
      });
      _showSnackBar('Не удалось отправить сообщение', Colors.redAccent);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Tab Handling ────────────────────────────────────────────────────────

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

  // ─── Build ───────────────────────────────────────────────────────────────

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
                children: [
                  const Icon(Icons.groups, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'КЛАН',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  if (_myClanId == null)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'нет',
                        style: TextStyle(fontSize: 8, color: Colors.orangeAccent),
                      ),
                    ),
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
          // ── Connection Status Header ──
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
                  _tabController.index == 0
                      ? 'Общий канал — все операторы'
                      : _myClanId != null
                          ? 'Клан-канал — только свои'
                          : 'Клан-канал — вступите в клан',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _myClanId != null || _tabController.index == 0
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // ── Messages List ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tabController.index == 1 && _myClanId == null
                    ? _buildNoClanPlaceholder(theme)
                    : _currentMessages.isEmpty
                        ? _buildEmptyState(theme)
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: _currentMessages.length,
                            itemBuilder: (context, index) =>
                                _buildMessageBubble(_currentMessages[index], theme),
                          ),
          ),

          // ── Input Area ──
          _buildInputArea(theme, auth),
        ],
      ),
    );
  }

  Widget _buildNoClanPlaceholder(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined,
                size: 56,
                color: theme.colorScheme.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Клан-канал недоступен',
              style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            Text(
              'Вступите в клан, чтобы общаться с союзниками',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 56,
                color: theme.colorScheme.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Пока нет сообщений',
              style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            Text(
              'Начните общение первым!',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, ThemeData theme) {
    // Pending message (optimistic UI)
    if (msg.id.startsWith('pending_')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                  color: Colors.cyan.withValues(alpha: 0.1),
                  border: Border.all(
                    color: Colors.cyan.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        msg.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Colors.cyanAccent.shade200,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
              ),
            ),
            const SizedBox(width: 8),
          ],
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
              style: const TextStyle(
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
