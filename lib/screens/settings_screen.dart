import 'package:flutter/material.dart';
import '../../widgets/cyber_button.dart';

// ── Screen ─────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── State ───────────────────────────────────────────────────
  bool _darkTheme = true; // true = deep dark, false = lighter dark
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
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
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
              onChanged: (v) => setState(() => _darkTheme = v),
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
              onChanged: (v) => setState(() => _soundEffects = v),
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
              onChanged: (v) => setState(() {
                _notifications = v;
                if (!v) {
                  _pushAttackAlerts = false;
                  _pushClanMessages = false;
                  _pushUpdates = false;
                }
              }),
            ),
            if (_notifications) ...[
              const _Divider(),
              _switchRow(
                icon: Icons.shield,
                label: 'Оповещения об атаках',
                subtitle: 'Когда вашу сеть атакуют',
                value: _pushAttackAlerts,
                onChanged: (v) => setState(() => _pushAttackAlerts = v),
              ),
              const _Divider(),
              _switchRow(
                icon: Icons.group,
                label: 'Сообщения клана',
                subtitle: 'Новый чат и события клана',
                value: _pushClanMessages,
                onChanged: (v) => setState(() => _pushClanMessages = v),
              ),
              const _Divider(),
              _switchRow(
                icon: Icons.system_update,
                label: 'Обновления игры',
                subtitle: 'Новые функции и патчи',
                value: _pushUpdates,
                onChanged: (v) => setState(() => _pushUpdates = v),
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
              onChanged: (v) => setState(() => _language = v),
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
            _infoRow('Версия', '1.0.0-alpha'),
            _infoRow('Сборка', '2025.06.01'),
            const _Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Авторы',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 11)),
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
                          color: Colors.white.withOpacity(0.35), fontSize: 11)),
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
                    color: Colors.white.withOpacity(0.4), fontSize: 12)),
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
                          ? const Color(0xFF00FF41).withOpacity(0.12)
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
            onPressed: () {
              Navigator.pop(context);
              _currentPassCtrl.clear();
              _newPassCtrl.clear();
              _confirmPassCtrl.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Пароль обновлён.'),
                  backgroundColor: Color(0xFF00FF41),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFF0040)),
        ),
        title: const Text('Удалить аккаунт?',
            style: TextStyle(color: Color(0xFFFF0040))),
        content: const Text(
          'Это действие необратимо. Весь прогресс, кредиты и членство в клане будут навсегда утрачены.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('ОТМЕНА', style: TextStyle(color: Colors.white54)),
          ),
          CyberButton(
            label: 'УДАЛИТЬ',
            variant: CyberButtonVariant.danger,
            height: 36,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Запрос на удаление аккаунта отправлен.'),
                  backgroundColor: Color(0xFFFF0040),
                ),
              );
            },
          ),
        ],
      ),
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
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Отключено.'),
                  backgroundColor: Color(0xFF00E5FF),
                ),
              );
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
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
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
