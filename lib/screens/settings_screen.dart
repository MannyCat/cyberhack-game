import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthUserAttributes;

import '../../widgets/cyber_button.dart';

// ── Screen ─────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── State ───────────────────────────────────────────────────
  bool _darkTheme = true;
  bool _soundEffects = true;
  bool _notifications = true;
  bool _pushAttackAlerts = true;
  bool _pushClanMessages = true;
  bool _pushUpdates = false;
  String _language = 'Русский';
  // Change password
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ── Persistence ──────────────────────────────────────────────
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkTheme = prefs.getBool('dark_theme') ?? true;
      _soundEffects = prefs.getBool('sound_effects') ?? true;
      _notifications = prefs.getBool('notifications') ?? true;
      _pushAttackAlerts = prefs.getBool('push_attack_alerts') ?? true;
      _pushClanMessages = prefs.getBool('push_clan_messages') ?? true;
      _pushUpdates = prefs.getBool('push_updates') ?? false;
      _language = prefs.getString('language') ?? 'Русский';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _setDarkTheme(bool v) async {
    setState(() => _darkTheme = v);
    await _saveSetting('dark_theme', v);
  }

  Future<void> _setSoundEffects(bool v) async {
    setState(() => _soundEffects = v);
    await _saveSetting('sound_effects', v);
  }

  Future<void> _setNotifications(bool v) async {
    setState(() {
      _notifications = v;
      if (!v) {
        _pushAttackAlerts = false;
        _pushClanMessages = false;
        _pushUpdates = false;
      }
    });
    await _saveSetting('notifications', v);
    if (!v) {
      await _saveSetting('push_attack_alerts', false);
      await _saveSetting('push_clan_messages', false);
      await _saveSetting('push_updates', false);
    }
  }

  Future<void> _setAttackAlerts(bool v) async {
    setState(() => _pushAttackAlerts = v);
    await _saveSetting('push_attack_alerts', v);
  }

  Future<void> _setClanMessages(bool v) async {
    setState(() => _pushClanMessages = v);
    await _saveSetting('push_clan_messages', v);
  }

  Future<void> _setUpdates(bool v) async {
    setState(() => _pushUpdates = v);
    await _saveSetting('push_updates', v);
  }

  Future<void> _setLanguage(String v) async {
    setState(() => _language = v);
    await _saveSetting('language', v);
  }

  // ── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        title: const Text(
          'НАСТРОЙКИ',
          style: TextStyle(
            color: Color(0xFF00FF41),
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        backgroundColor: const Color(0xFF0A0E17),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Appearance ────────────────────────────────────────
          _sectionHeader('ВНЕШНИЙ ВИД'),
          _sectionCard([
            _switchRow(
              icon: Icons.dark_mode,
              label: 'Тёмный режим',
              subtitle: _darkTheme ? 'Чёрный фон' : 'Более светлый вариант',
              value: _darkTheme,
              onChanged: (v) => _setDarkTheme(v),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Sound ────────────────────────────────────────────
          _sectionHeader('ЗВУК'),
          _sectionCard([
            _switchRow(
              icon: Icons.volume_up,
              label: 'Звуковые эффекты',
              subtitle: 'Звуки интерфейса и обратная связь',
              value: _soundEffects,
              onChanged: (v) => _setSoundEffects(v),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Notifications ────────────────────────────────────
          _sectionHeader('УВЕДОМЛЕНИЯ'),
          _sectionCard([
            _switchRow(
              icon: Icons.notifications_active,
              label: 'Включить уведомления',
              subtitle: 'Получать push-уведомления',
              value: _notifications,
              onChanged: (v) => _setNotifications(v),
            ),
            if (_notifications) ...[
              const _Divider(),
              _switchRow(
                icon: Icons.shield,
                label: 'Оповещения об атаках',
                subtitle: 'Когда вашу сеть атакуют',
                value: _pushAttackAlerts,
                onChanged: (v) => _setAttackAlerts(v),
              ),
              const _Divider(),
              _switchRow(
                icon: Icons.group,
                label: 'Сообщения клана',
                subtitle: 'Новый чат и события клана',
                value: _pushClanMessages,
                onChanged: (v) => _setClanMessages(v),
              ),
              const _Divider(),
              _switchRow(
                icon: Icons.system_update,
                label: 'Обновления игры',
                subtitle: 'Новые функции и патчи',
                value: _pushUpdates,
                onChanged: (v) => _setUpdates(v),
              ),
            ],
          ]),

          const SizedBox(height: 20),

          // ── Language ─────────────────────────────────────────
          _sectionHeader('ЯЗЫК'),
          _sectionCard([
            _radioRow(
              icon: Icons.language,
              label: 'Язык интерфейса',
              options: ['Английский', 'Русский'],
              selected: _language,
              onChanged: (v) => _setLanguage(v),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Account ──────────────────────────────────────────
          _sectionHeader('АККАУНТ'),
          _sectionCard([
            _navRow(
              icon: Icons.lock,
              label: 'Сменить пароль',
              onTap: _showChangePasswordDialog,
            ),
            const _Divider(),
            _navRow(
              icon: Icons.delete_forever,
              label: 'Удалить аккаунт',
              labelColor: const Color(0xFFFF0040),
              onTap: _showDeleteAccountDialog,
            ),
          ]),

          const SizedBox(height: 20),

          // ── About ────────────────────────────────────────────
          _sectionHeader('О ПРИЛОЖЕНИИ'),
          _sectionCard([
            _infoRow('Игра', 'CyberHack'),
            _infoRow('Версия', '1.0.8'),
            _infoRow('Сборка', '2025.05.28'),
            const _Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Авторы',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                  const SizedBox(height: 4),
                  const Text(
                    'Разработано с 💀 командой CyberHack.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Все персонажи и события вымышлены.',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 28),

          // ── Disconnect ───────────────────────────────────────
          CyberButton(
            label: 'ОТКЛЮЧИТЬСЯ',
            variant: CyberButtonVariant.danger,
            icon: Icons.power_settings_new,
            width: double.infinity,
            onPressed: _showDisconnectDialog,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Section helpers ─────────────────────────────────────────
  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      );

  Widget _sectionCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2A2F45)),
        ),
        child: Column(children: children),
      );

  Widget _switchRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF00E5FF), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF00FF41),
              activeTrackColor: const Color(0xFF0D2818),
              inactiveTrackColor: const Color(0xFF12162A),
              inactiveThumbColor: Colors.white38,
            ),
          ],
        ),
      );

  Widget _navRow({
    required IconData icon,
    required String label,
    Color? labelColor,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon,
                  color: labelColor ?? const Color(0xFF00E5FF), size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: labelColor ?? Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right,
                  color: Colors.white24, size: 18),
            ],
          ),
        ),
      );

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      );

  Widget _radioRow({
    required IconData icon,
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF00E5FF), size: 20),
                const SizedBox(width: 12),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: options.map((opt) {
                final isSelected = opt == selected;
                return GestureDetector(
                  onTap: () => onChanged(opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00FF41).withValues(alpha: 0.12)
                          : const Color(0xFF12162A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00FF41)
                            : const Color(0xFF2A2F45),
                      ),
                    ),
                    child: Text(
                      opt,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF00FF41)
                            : Colors.white54,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );

  // ── Dialogs ────────────────────────────────────────────────
  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF00E5FF)),
        ),
        title: const Text('Сменить пароль',
            style: TextStyle(color: Color(0xFF00E5FF))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(
                label: 'Текущий пароль',
                controller: _currentPassCtrl,
                obscure: true),
            const SizedBox(height: 10),
            _dialogField(
                label: 'Новый пароль',
                controller: _newPassCtrl,
                obscure: true),
            const SizedBox(height: 10),
            _dialogField(
                label: 'Подтвердите новый пароль',
                controller: _confirmPassCtrl,
                obscure: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('ОТМЕНА', style: TextStyle(color: Colors.white54)),
          ),
          CyberButton(
            label: 'ОБНОВИТЬ',
            variant: CyberButtonVariant.secondary,
            height: 36,
            onPressed: () async {
              final current = _currentPassCtrl.text.trim();
              final newPass = _newPassCtrl.text.trim();
              final confirm = _confirmPassCtrl.text.trim();

              if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Все поля обязательны для заполнения.'),
                    backgroundColor: Color(0xFFFF0040),
                  ),
                );
                return;
              }

              if (newPass.length < 8) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Новый пароль должен быть не менее 8 символов.'),
                    backgroundColor: Color(0xFFFF0040),
                  ),
                );
                return;
              }

              if (newPass != confirm) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Пароли не совпадают.'),
                    backgroundColor: Color(0xFFFF0040),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              _currentPassCtrl.clear();
              _newPassCtrl.clear();
              _confirmPassCtrl.clear();

              // Real password update via Supabase
              try {
                await Supabase.instance.client.auth.updateUser(
                  attributes: AuthUserAttributes(password: newPass),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Пароль успешно обновлён.'),
                      backgroundColor: Color(0xFF00FF41),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка: ${e.toString()}'),
                      backgroundColor: const Color(0xFFFF0040),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final userHandle = Supabase.instance.client.auth.currentUser?.email ?? 'player';

    showDialog(
      context: context,
      builder: (ctx) {
        final confirmCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1A1F2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFFF0040)),
            ),
            title: const Text('Удалить аккаунт?',
                style: TextStyle(color: Color(0xFFFF0040))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Это действие необратимо. Весь прогресс, кредиты и членство в клане будут навсегда утрачены.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text(
                  'Введите "$userHandle" для подтверждения:',
                  style: const TextStyle(
                    color: Color(0xFFFF0040),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF12162A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFFF0040)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF2A2F45)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFFF0040)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  confirmCtrl.dispose();
                  Navigator.pop(ctx);
                },
                child: const Text('ОТМЕНА',
                    style: TextStyle(color: Colors.white54)),
              ),
              CyberButton(
                label: 'УДАЛИТЬ',
                variant: CyberButtonVariant.danger,
                height: 36,
                onPressed: confirmCtrl.text.trim() == userHandle
                    ? () {
                        confirmCtrl.dispose();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Запрос на удаление аккаунта отправлен.'),
                            backgroundColor: Color(0xFFFF0040),
                          ),
                        );
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF00E5FF)),
        ),
        title: const Text('Отключиться?',
            style: TextStyle(color: Color(0xFF00E5FF))),
        content: const Text(
          'Вы будете отключены от игрового сервера. Ваш прогресс сохраняется автоматически.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('ОТМЕНА', style: TextStyle(color: Colors.white54)),
          ),
          CyberButton(
            label: 'ОТКЛЮЧИТЬСЯ',
            variant: CyberButtonVariant.secondary,
            height: 36,
            onPressed: () async {
              Navigator.pop(context);
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (e) {
                debugPrint('Sign out error: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _dialogField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
  }) =>
      TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          filled: true,
          fillColor: const Color(0xFF12162A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF2A2F45)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF2A2F45)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF00E5FF)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}

// ── Divider helper ─────────────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Divider(color: Color(0xFF1E2340), height: 1),
    );
  }
}
