import 'dart:async';
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
const _cyanSecondary = Color(0xFF00d4ff);
const _goldAccent = Color(0xFFFFD700);

// ── Chat Screen ──────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;

  String _selectedChannel = 'global'; // 'global' or 'cartel'
  List<Map<String, dynamic>> _messages = [];
  bool _isLoadingMessages = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Auto-refresh messages every 3 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Data Loading ──────────────────────────────────────────────────────

  Future<void> _loadMessages() async {
    try {
      final game = ref.read(gameProvider);
      final clanId = game.clanId;

      PostgrestList data;

      if (_selectedChannel == 'cartel' && clanId != null) {
        data = await _supabase
            .from('chat_messages')
            .select()
            .eq('clan_id', clanId)
            .order('created_at', ascending: false)
            .limit(50);
      } else {
        data = await _supabase
            .from('chat_messages')
            .select()
            .isFilter('clan_id', null)
            .order('created_at', ascending: false)
            .limit(50);
      }

      if (mounted) {
        setState(() {
          // Reverse so newest is at the bottom
          _messages = data.reversed.toList();
          _isLoadingMessages = false;
        });

        // Scroll to bottom after messages load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (_) {
      if (mounted && _isLoadingMessages) {
        setState(() => _isLoadingMessages = false);
      }
    }
  }

  // ── Send Message ──────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final game = ref.read(gameProvider);
      final username = game.username ?? 'Хакер';
      final clanId = game.clanId;

      await _supabase.from('chat_messages').insert({
        'sender_id': userId,
        'sender_name': username,
        'content': text,
        'clan_id': _selectedChannel == 'cartel' ? clanId : null,
      });

      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e'), backgroundColor: _bgDark),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Channel Switch ────────────────────────────────────────────────────

  void _switchChannel(String channel) {
    if (channel == _selectedChannel) return;

    // Check if cartel channel is available
    if (channel == 'cartel') {
      final game = ref.read(gameProvider);
      if (game.clanId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Вступите в картель для доступа к чату картеля'),
            backgroundColor: _surfaceVariant,
          ),
        );
        return;
      }
    }

    setState(() {
      _selectedChannel = channel;
      _isLoadingMessages = true;
      _messages = [];
    });
    _loadMessages();
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(dt);

    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes}м назад';
    if (diff.inHours < 24) return '${diff.inHours}ч назад';
    if (diff.inDays < 7) return '${diff.inDays}д назад';

    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  bool _isOwnMessage(Map<String, dynamic> msg) {
    final userId = _supabase.auth.currentUser?.id;
    return msg['sender_id'] == userId;
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);

    if (game.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _greenPrimary));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left Panel: Channels ───────────────────────────────────
          _buildChannelPanel(game.clanId != null),
          const SizedBox(width: 20),

          // ── Right Panel: Messages ─────────────────────────────────
          Expanded(child: _buildMessagesPanel()),
        ],
      ),
    );
  }

  // ── Channel Panel ────────────────────────────────────────────────────

  Widget _buildChannelPanel(bool hasCartel) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: _surfaceVariant,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: const Text(
              'КАНАЛЫ',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Global channel
          _ChannelButton(
            icon: Icons.public,
            label: 'Общий чат',
            selected: _selectedChannel == 'global',
            onTap: () => _switchChannel('global'),
          ),

          // Cartel channel (only if in cartel)
          if (hasCartel) ...[
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 12, bottom: 4),
              child: Text(
                'КАРТЕЛЬ',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            _ChannelButton(
              icon: Icons.shield_outlined,
              label: 'Чат картеля',
              selected: _selectedChannel == 'cartel',
              onTap: () => _switchChannel('cartel'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Messages Panel ───────────────────────────────────────────────────

  Widget _buildMessagesPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceVariant),
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: _surfaceVariant,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedChannel == 'cartel'
                      ? Icons.shield_outlined
                      : Icons.public,
                  color: _selectedChannel == 'cartel'
                      ? _goldAccent
                      : _cyanSecondary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  _selectedChannel == 'cartel'
                      ? 'Чат картеля'
                      : 'Общий чат',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '($_messages.length)',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _isLoadingMessages
                ? const Center(
                    child: CircularProgressIndicator(color: _greenPrimary),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.grey.shade700,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Пока нет сообщений.\nНачните общение!',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) =>
                            _buildMessageBubble(_messages[index]),
                      ),
          ),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isOwn = _isOwnMessage(msg);
    final senderName = msg['sender_name'] as String? ?? 'Аноним';
    final content = msg['content'] as String? ?? '';
    final timeAgo = _timeAgo(msg['created_at'] as String?);

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isOwn
              ? _greenPrimary.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isOwn
              ? Border.all(color: _greenPrimary.withValues(alpha: 0.15))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender avatar
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: isOwn
                    ? _greenPrimary.withValues(alpha: 0.15)
                    : _cyanSecondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: isOwn ? _greenPrimary : _cyanSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        senderName,
                        style: TextStyle(
                          color: isOwn ? _greenPrimary : _cyanSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    content,
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 13,
                      height: 1.4,
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

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: _surfaceVariant,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          // Text input
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Введите сообщение...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send button
          CyberButton(
            text: 'ОТПРАВИТЬ',
            variant: CyberButtonVariant.primary,
            height: 42,
            isLoading: _isSending,
            onPressed: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ── Channel Button Widget ────────────────────────────────────────────────

class _ChannelButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChannelButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ChannelButton> createState() => _ChannelButtonState();
}

class _ChannelButtonState extends State<_ChannelButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? _greenPrimary.withValues(alpha: 0.1)
                : _isHovered
                    ? _surfaceVariant.withValues(alpha: 0.5)
                    : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: widget.selected
                    ? _greenPrimary
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.selected ? _greenPrimary : Colors.grey.shade500,
                size: 16,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.selected
                      ? _greenPrimary
                      : _isHovered
                          ? Colors.white
                          : Colors.grey.shade400,
                  fontSize: 13,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
