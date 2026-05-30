import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';

// ─── Theme Constants ──────────────────────────────────────────────────────────

class _T {
  _T._();

  static const bg = Color(0xFF0a0e17);
  static const surface = Color(0xFF0d1320);
  static const card = Color(0xFF111827);
  static const cardElevated = Color(0xFF1a2236);
  static const accentCyan = Color(0xFF00F0FF);
  static const accentGreen = Color(0xFF00ff41);
  static const accentGold = Color(0xFFFFD700);
  static const accentPurple = Color(0xFFa855f7);
  static const warningRed = Color(0xFFFF0040);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF7b8ca8);
  static const textMuted = Color(0xFF4a5568);
  static const border = Color(0xFF1e293b);
  static const channelListWidth = 200.0;
}

// ─── Data Model ────────────────────────────────────────────────────────────────

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

// ─── Channel Definition ──────────────────────────────────────────────────────

enum _ChatChannel {
  global,
  clan,
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // ── Channel selection (replaces TabController) ──
  _ChatChannel _selectedChannel = _ChatChannel.global;
  _ChatChannel? _hoveredChannel;

  // ── Message lists ──
  final List<_ChatMessage> _globalMessages = [];
  final List<_ChatMessage> _clanMessages = [];

  // ── Input ──
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  // ── Rate limiting ──
  DateTime? _lastMessageTime;
  DateTime? _lastGlobalSent;
  DateTime? _lastClanSent;

  // ── State ──
  bool _isLoading = false;
  bool _hasMoreGlobal = true;
  bool _hasMoreClan = true;

  // ── Supabase ──
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _globalChannel;
  RealtimeChannel? _clanChannel;
  String? _myUserId;
  String? _myClanId;

  static const int _pageSize = 50;

  // ── Unread counts per channel ──
  int _globalUnread = 0;
  int _clanUnread = 0;

  @override
  void initState() {
    super.initState();
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
    _textController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _supabase
          .from('profiles')
          .select('clan_id, clan:clans(tag)')
          .eq('id', _myUserId!)
          .single();

      _myClanId = profile['clan_id'] as String?;

      await _loadGlobalMessages();
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

  // ═══════════════════════════════════════════════════════════════════════════
  // REALTIME SUBSCRIPTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  void _subscribeToChannels() {
    _globalChannel = _supabase
        .channel('public:chat_messages:global')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            final row = payload.newRecord as Map<String, dynamic>;
            final clanId = row['clan_id'];
            if (clanId != null) return;
            _onGlobalMessage(payload);
          },
        )
        .subscribe();

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

    setState(() {
      _globalMessages.add(msg);
      if (_selectedChannel != _ChatChannel.global) {
        _globalUnread++;
      }
    });
    if (_selectedChannel == _ChatChannel.global) {
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

    setState(() {
      _clanMessages.add(msg);
      if (_selectedChannel != _ChatChannel.clan) {
        _clanUnread++;
      }
    });
    if (_selectedChannel == _ChatChannel.clan) {
      _scrollToBottom();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEND MESSAGE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _myUserId == null) return;
    final isClanTab = _selectedChannel == _ChatChannel.clan;

    // Rate limit: max 1 message per 2 seconds (separate per channel)
    final lastSent = isClanTab ? _lastClanSent : _lastGlobalSent;
    if (lastSent != null) {
      final elapsed = DateTime.now().difference(lastSent).inMilliseconds;
      if (elapsed < 2000) {
        final remaining = ((2000 - elapsed) / 1000).toStringAsFixed(1);
        _showSnackBar('Подождите $remainingс перед отправкой', Colors.orangeAccent);
        return;
      }
    }
    if (isClanTab) {
      _lastClanSent = DateTime.now();
    } else {
      _lastGlobalSent = DateTime.now();
    }
    _lastMessageTime = DateTime.now();

    final auth = context.read<AuthProvider>();
    final senderName = auth.displayName;

    // Max message length
    if (text.length > 500) {
      _showSnackBar('Сообщение слишком длинное (макс. 500 символов)', Colors.orangeAccent);
      return;
    }

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
    _inputFocus.requestFocus();
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

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  List<_ChatMessage> get _currentMessages =>
      _selectedChannel == _ChatChannel.global
          ? _globalMessages
          : _clanMessages;

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _selectChannel(_ChatChannel channel) {
    if (_selectedChannel == channel) return;
    setState(() {
      _selectedChannel = channel;
      // Clear unread for selected channel
      if (channel == _ChatChannel.global) {
        _globalUnread = 0;
      } else {
        _clanUnread = 0;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // GameShell provides the outer sidebar; we fill the main content area
    return Scaffold(
      backgroundColor: _T.bg,
      body: Row(
        children: [
          // ── LEFT PANEL: Channel List (200px) ──
          _buildChannelList(),
          // ── Divider ──
          Container(
            width: 1,
            color: _T.border,
          ),
          // ── RIGHT PANEL: Messages + Input (expanded) ──
          Expanded(
            child: Column(
              children: [
                // ── Channel Header / Status Bar ──
                _buildChannelHeader(),
                // ── Messages Area ──
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: _T.accentCyan,
                            strokeWidth: 2,
                          ),
                        )
                      : _selectedChannel == _ChatChannel.clan &&
                              _myClanId == null
                          ? _buildNoClanPlaceholder()
                          : _currentMessages.isEmpty
                              ? _buildEmptyState()
                              : _buildMessageList(),
                ),
                // ── Input Area ──
                _buildInputArea(auth),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEFT PANEL: CHANNEL LIST
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildChannelList() {
    return Container(
      width: _T.channelListWidth,
      color: _T.surface,
      child: Column(
        children: [
          // ── Panel Header ──
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _T.border),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: const Text(
              'КАНАЛЫ',
              style: TextStyle(
                color: _T.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Global Channel ──
          _buildChannelItem(
            channel: _ChatChannel.global,
            icon: Icons.public_rounded,
            label: 'Общий',
            subtitle: 'Все операторы',
            color: _T.accentCyan,
            unread: _globalUnread,
          ),

          const SizedBox(height: 4),

          // ── Clan Channel ──
          _buildChannelItem(
            channel: _ChatChannel.clan,
            icon: Icons.groups_rounded,
            label: 'Клан',
            subtitle: _myClanId != null ? 'Только свои' : 'Нет клана',
            color: _T.accentPurple,
            unread: _clanUnread,
            disabled: _myClanId == null,
          ),

          const Spacer(),

          // ── Connection Status ──
          _buildConnectionIndicator(),
        ],
      ),
    );
  }

  Widget _buildChannelItem({
    required _ChatChannel channel,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required int unread,
    bool disabled = false,
  }) {
    final isSelected = _selectedChannel == channel;
    final isHovered = _hoveredChannel == channel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredChannel = channel),
        onExit: (_) {
          if (_hoveredChannel == channel) {
            setState(() => _hoveredChannel = null);
          }
        },
        child: GestureDetector(
          onTap: disabled ? null : () => _selectChannel(channel),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.12)
                  : (isHovered && !disabled
                      ? color.withValues(alpha: 0.06)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: color.withValues(alpha: 0.4), width: 1)
                  : (isHovered && !disabled
                      ? Border.all(color: color.withValues(alpha: 0.15), width: 1)
                      : null),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: -2,
                        offset: const Offset(-2, 0),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.15)
                        : (disabled
                            ? _T.textMuted.withValues(alpha: 0.1)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 17,
                    color: isSelected
                        ? color
                        : (disabled ? _T.textMuted : _T.textSecondary),
                  ),
                ),
                const SizedBox(width: 10),
                // Label + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? color
                              : (disabled ? _T.textMuted : _T.textPrimary),
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          letterSpacing: 0.3,
                          shadows: isSelected
                              ? [
                                  Shadow(
                                      color: color.withValues(alpha: 0.3),
                                      blurRadius: 6)
                                ]
                              : [],
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: disabled
                              ? _T.textMuted.withValues(alpha: 0.6)
                              : _T.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                // Unread badge
                if (unread > 0)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _T.border),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _T.accentGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _T.accentGreen.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Подключено',
              style: TextStyle(
                color: _T.accentGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Icon(
            Icons.wifi,
            color: _T.accentGreen,
            size: 14,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RIGHT PANEL: CHANNEL HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildChannelHeader() {
    final isGlobal = _selectedChannel == _ChatChannel.global;
    final channelColor = isGlobal ? _T.accentCyan : _T.accentPurple;
    final channelName = isGlobal ? 'ОБЩИЙ КАНАЛ' : 'КЛАН-КАНАЛ';
    final channelDesc = isGlobal
        ? 'Общий канал — все операторы'
        : (_myClanId != null
            ? 'Клан-канал — только свои'
            : 'Клан-канал — вступите в клан');

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _T.surface,
        border: const Border(bottom: BorderSide(color: _T.border)),
        boxShadow: [
          BoxShadow(
            color: channelColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Channel icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: channelColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: channelColor.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: Icon(
              isGlobal ? Icons.public_rounded : Icons.groups_rounded,
              color: channelColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          // Channel name + description
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                channelName,
                style: TextStyle(
                  color: channelColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                  shadows: [
                    Shadow(color: channelColor.withValues(alpha: 0.3), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              Text(
                channelDesc,
                style: TextStyle(
                  color: (_myClanId != null || isGlobal)
                      ? _T.accentGreen.withValues(alpha: 0.7)
                      : _T.accentGold.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Message count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: channelColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: channelColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, color: channelColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${_currentMessages.length}',
                  style: TextStyle(
                    color: channelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RIGHT PANEL: MESSAGE LIST
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: _currentMessages.length,
      itemBuilder: (context, index) =>
          _buildMessageBubble(_currentMessages[index]),
    );
  }

  Widget _buildNoClanPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _T.accentPurple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border:
                    Border.all(color: _T.accentPurple.withValues(alpha: 0.2)),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.groups_outlined,
                size: 36,
                color: _T.accentPurple,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Клан-канал недоступен',
              style: TextStyle(
                color: _T.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Вступите в клан, чтобы общаться с союзниками',
              style: TextStyle(
                color: _T.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _T.accentCyan.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border:
                    Border.all(color: _T.accentCyan.withValues(alpha: 0.2)),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 36,
                color: _T.accentCyan,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Пока нет сообщений',
              style: TextStyle(
                color: _T.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Начните общение первым!',
              style: TextStyle(
                color: _T.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE BUBBLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMessageBubble(_ChatMessage msg) {
    // Pending optimistic message
    if (msg.id.startsWith('pending_')) {
      return _PendingMessageBubble(msg: msg);
    }

    return _MessageRow(msg: msg);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INPUT AREA
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInputArea(AuthProvider auth) {
    return _ChatInputArea(
      controller: _textController,
      focusNode: _inputFocus,
      onSend: _sendMessage,
      auth: auth,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS: MESSAGE ROW (own + other)
// ══════════════════════════════════════════════════════════════════════════════

class _MessageRow extends StatefulWidget {
  final _ChatMessage msg;
  const _MessageRow({required this.msg});

  @override
  State<_MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<_MessageRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final isOwn = msg.isOwn;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Row(
          mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar (others only) ──
            if (!isOwn) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _T.accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _T.accentCyan.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  msg.senderName.isNotEmpty
                      ? msg.senderName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: _T.accentCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            // ── Bubble content ──
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment:
                      isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // ── Sender info (others only) ──
                    if (!isOwn)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (msg.senderClanTag != null) ...[
                              Text(
                                '${msg.senderClanTag} ',
                                style: const TextStyle(
                                  color: _T.accentPurple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                            Text(
                              msg.senderName,
                              style: TextStyle(
                                color: _T.accentCyan.withValues(alpha: 0.9),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _formatTimeStatic(msg.timestamp),
                              style: TextStyle(
                                color: _T.textMuted.withValues(alpha: 0.7),
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    // ── Bubble ──
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: isOwn
                              ? const Radius.circular(14)
                              : const Radius.circular(4),
                          bottomRight: isOwn
                              ? const Radius.circular(4)
                              : const Radius.circular(14),
                        ),
                        color: isOwn
                            ? _T.accentCyan.withValues(alpha: 0.1)
                            : _T.card,
                        border: Border.all(
                          color: isOwn
                              ? _T.accentCyan.withValues(alpha: _isHovered ? 0.45 : 0.25)
                              : _T.border.withValues(alpha: _isHovered ? 0.8 : 0.5),
                        ),
                        boxShadow: _isHovered
                            ? [
                                BoxShadow(
                                  color: isOwn
                                      ? _T.accentCyan.withValues(alpha: 0.08)
                                      : _T.accentCyan.withValues(alpha: 0.03),
                                  blurRadius: 12,
                                ),
                              ]
                            : [],
                      ),
                      child: Text(
                        msg.content,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: isOwn
                              ? const Color(0xFFa0e4ff)
                              : _T.textPrimary,
                          height: 1.45,
                        ),
                      ),
                    ),
                    // ── Timestamp (own only) ──
                    if (isOwn)
                      Padding(
                        padding: const EdgeInsets.only(top: 3, right: 4),
                        child: Text(
                          _formatTimeStatic(msg.timestamp),
                          style: TextStyle(
                            color: _T.textMuted.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (isOwn) const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  String _formatTimeStatic(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS: PENDING MESSAGE
// ══════════════════════════════════════════════════════════════════════════════

class _PendingMessageBubble extends StatelessWidget {
  final _ChatMessage msg;
  const _PendingMessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(4),
                        ),
                        color: _T.accentCyan.withValues(alpha: 0.08),
                        border: Border.all(
                          color: _T.accentCyan.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        msg.content,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Color(0xFFa0e4ff),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _T.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS: INPUT AREA (wide, terminal-style)
// ══════════════════════════════════════════════════════════════════════════════

class _ChatInputArea extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final AuthProvider auth;

  const _ChatInputArea({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.auth,
  });

  @override
  State<_ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<_ChatInputArea> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
        decoration: BoxDecoration(
          color: _T.surface,
          border: Border(
            top: BorderSide(
              color: _isFocused
                  ? _T.accentCyan.withValues(alpha: 0.3)
                  : _T.border,
              width: _isFocused ? 1.5 : 1,
            ),
          ),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: _T.accentCyan.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Terminal prefix
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: const Text(
                '> ',
                style: TextStyle(
                  color: _T.accentGreen,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // ── Username prefix ──
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${widget.auth.displayName}: ',
                style: TextStyle(
                  color: _T.accentCyan.withValues(alpha: 0.6),
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            // ── Text Field ──
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _T.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isFocused
                        ? _T.accentCyan.withValues(alpha: 0.4)
                        : (_isHovered
                            ? _T.border.withValues(alpha: 0.8)
                            : _T.border),
                  ),
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  style: const TextStyle(
                    color: _T.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Введите сообщение...',
                    hintStyle: TextStyle(
                      color: _T.textMuted.withValues(alpha: 0.6),
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => widget.onSend(),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // ── Send Button ──
            _SendButton(
              onPressed: widget.onSend,
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _SendButton({required this.onPressed});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) {
        setState(() {
          _isHovered = false;
          _isPressed = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isPressed
                ? _T.accentCyan.withValues(alpha: 0.25)
                : (_isHovered
                    ? _T.accentCyan.withValues(alpha: 0.15)
                    : _T.accentCyan.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _T.accentCyan.withValues(
                  alpha: _isHovered ? 0.5 : 0.3),
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: _T.accentCyan.withValues(alpha: 0.15),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.send_rounded,
                color: _T.accentCyan,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'ОТПРАВИТЬ',
                style: TextStyle(
                  color: _T.accentCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
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
