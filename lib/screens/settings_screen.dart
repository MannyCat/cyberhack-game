import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/cyber_button.dart';
import '../providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CYBERHACK — Настройки (PC Desktop Layout)
// Wide layout · maxWidth 1100 · Section cards · Cyberpunk aesthetic · Russian UI
// ═══════════════════════════════════════════════════════════════════════════

const _bgDark = Color(0xFF0a0e17);
const _bgCard = Color(0xFF111827);
const _bgCardInner = Color(0xFF0d1220);
const _neonCyan = Color(0xFF00F0FF);
const _neonGreen = Color(0xFF00ff41);
const _neonRed = Color(0xFFFF0040);
const _neonPurple = Color(0xFFa855f7);
const _neonGold = Color(0xFFFFD700);
const _muted = Color(0xFF4a5568);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── State ────────────────────────────────────────────────────────
  bool _darkTheme = true;
  bool _soundEffects = true;
  bool _music = true;
  bool _notifications = true;
  bool _pushAttackAlerts = true;
  bool _pushClanMessages = true;
  bool _pushUpdates = false;
  String _language = 'Русский';

  // Audio levels
  double _masterVolume = 0.8;
  double _effectsVolume = 0.7;
  double _musicVolume = 0.6;

  // Graphics
  double _uiScale = 1.0;
  bool _animationsEnabled = true;
  bool _particlesEnabled = true;
  bool _screenShake = true;
  String _graphicsQuality = 'Высокое';

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

  // ── Persistence ──────────────────────────────────────────────────
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkTheme = prefs.getBool('dark_theme') ?? true;
      _soundEffects = prefs.getBool('sound_effects') ?? true;
      _music = prefs.getBool('music') ?? true;
      _notifications = prefs.getBool('notifications') ?? true;
      _pushAttackAlerts = prefs.getBool('push_attack_alerts') ?? true;
      _pushClanMessages = prefs.getBool('push_clan_messages') ?? true;
      _pushUpdates = prefs.getBool('push_updates') ?? false;
      _language = prefs.getString('language') ?? 'Русский';
      _masterVolume = prefs.getDouble('master_volume') ?? 0.8;
      _effectsVolume = prefs.getDouble('effects_volume') ?? 0.7;
      _musicVolume = prefs.getDouble('music_volume') ?? 0.6;
      _uiScale = prefs.getDouble('ui_scale') ?? 1.0;
      _animationsEnabled = prefs.getBool('animations_enabled') ?? true;
      _particlesEnabled = prefs.getBool('particles_enabled') ?? true;
      _screenShake = prefs.getBool('screen_shake') ?? true;
      _graphicsQuality = prefs.getString('graphics_quality') ?? 'Высокое';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }

  // ── Setters ──────────────────────────────────────────────────────
  Future<void> _setDarkTheme(bool v) async {
    setState(() => _darkTheme = v);
    await _saveSetting('dark_theme', v);
  }

  Future<void> _setSoundEffects(bool v) async {
    setState(() => _soundEffects = v);
    await _saveSetting('sound_effects', v);
  }

  Future<void> _setMusic(bool v) async {
    setState(() => _music = v);
    await _saveSetting('music', v);
  }

  Future<void> _setMasterVolume(double v) async {
    setState(() => _masterVolume = v);
    await _saveSetting('master_volume', v);
  }

  Future<void> _setEffectsVolume(double v) async {
    setState(() => _effectsVolume = v);
    await _saveSetting('effects_volume', v);
  }

  Future<void> _setMusicVolume(double v) async {
    setState(() => _musicVolume = v);
    await _saveSetting('music_volume', v);
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

  Future<void> _setUIScale(double v) async {
    setState(() => _uiScale = v);
    await _saveSetting('ui_scale', v);
  }

  Future<void> _setAnimations(bool v) async {
    setState(() => _animationsEnabled = v);
    await _saveSetting('animations_enabled', v);
  }

  Future<void> _setParticles(bool v) async {
    setState(() => _particlesEnabled = v);
    await _saveSetting('particles_enabled', v);
  }

  Future<void> _setScreenShake(bool v) async {
    setState(() => _screenShake = v);
    await _saveSetting('screen_shake', v);
  }

  Future<void> _setGraphicsQuality(String v) async {
    setState(() => _graphicsQuality = v);
    await _saveSetting('graphics_quality', v);
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ═══ TOP BAR: Back button + Title ════════════════════
                _TopBar(),

                const SizedBox(height: 28),

                // ═══ TWO-COLUMN LAYOUT ═══════════════════════════════
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── LEFT COLUMN (settings sections) ─────────────
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── AUDIO SECTION ────────────────────────
                          _sectionLabel('АУДИО'),
                          const SizedBox(height: 10),
                          _SectionCard(
                            children: [
                              _SwitchRow(
                                icon: Icons.volume_up_rounded,
                                label: 'Общая громкость',
                                subtitle: 'Главный регулятор звука',
                                value: _soundEffects,
                                onChanged: (v) => _setSoundEffects(v),
                              ),
                              const _CyberDivider(),
                              _VolumeSlider(
                                icon: Icons.tune_rounded,
                                label: 'Мастер-громкость',
                                value: _masterVolume,
                                onChanged: _setMasterVolume,
                                color: _neonCyan,
                              ),
                              const _CyberDivider(),
                              _VolumeSlider(
                                icon: Icons.graphic_eq_rounded,
                                label: 'Громкость эффектов',
                                value: _effectsVolume,
                                onChanged: _setEffectsVolume,
                                color: _neonGreen,
                              ),
                              const _CyberDivider(),
                              _SwitchRow(
                                icon: Icons.music_note_rounded,
                                label: 'Музыка',
                                subtitle: 'Фоновые треки и эмбиент',
                                value: _music,
                                onChanged: (v) => _setMusic(v),
                              ),
                              const _CyberDivider(),
                              _VolumeSlider(
                                icon: Icons.piano_rounded,
                                label: 'Громкость музыки',
                                value: _musicVolume,
                                onChanged: _setMusicVolume,
                                color: _neonPurple,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── GRAPHICS SECTION ──────────────────────
                          _sectionLabel('ГРАФИКА'),
                          const SizedBox(height: 10),
                          _SectionCard(
                            children: [
                              _QualitySelector(
                                label: 'Качество графики',
                                options: ['Низкое', 'Среднее', 'Высокое', 'Ультра'],
                                selected: _graphicsQuality,
                                onChanged: _setGraphicsQuality,
                              ),
                              const _CyberDivider(),
                              _VolumeSlider(
                                icon: Icons.zoom_out_map_rounded,
                                label: 'Масштаб интерфейса',
                                value: _uiScale,
                                onChanged: _setUIScale,
                                min: 0.5,
                                max: 2.0,
                                color: _neonGold,
                                displayPercent: true,
                              ),
                              const _CyberDivider(),
                              _SwitchRow(
                                icon: Icons.animation_rounded,
                                label: 'Анимации',
                                subtitle: 'Плавные переходы и эффекты',
                                value: _animationsEnabled,
                                onChanged: (v) => _setAnimations(v),
                              ),
                              const _CyberDivider(),
                              _SwitchRow(
                                icon: Icons.auto_awesome_rounded,
                                label: 'Частицы',
                                subtitle: 'Визуальные эффекты и спецэффекты',
                                value: _particlesEnabled,
                                onChanged: (v) => _setParticles(v),
                              ),
                              const _CyberDivider(),
                              _SwitchRow(
                                icon: Icons.vibration_rounded,
                                label: 'Тряска экрана',
                                subtitle: 'Вибрация при взрывах и ударах',
                                value: _screenShake,
                                onChanged: (v) => _setScreenShake(v),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── NOTIFICATIONS SECTION ─────────────────
                          _sectionLabel('УВЕДОМЛЕНИЯ'),
                          const SizedBox(height: 10),
                          _SectionCard(
                            children: [
                              _SwitchRow(
                                icon: Icons.notifications_active_rounded,
                                label: 'Включить уведомления',
                                subtitle: 'Получать push-уведомления',
                                value: _notifications,
                                onChanged: (v) => _setNotifications(v),
                              ),
                              if (_notifications) ...[
                                const _CyberDivider(),
                                _SwitchRow(
                                  icon: Icons.shield_rounded,
                                  label: 'Оповещения об атаках',
                                  subtitle: 'Когда вашу сеть атакуют',
                                  value: _pushAttackAlerts,
                                  onChanged: (v) => _setAttackAlerts(v),
                                ),
                                const _CyberDivider(),
                                _SwitchRow(
                                  icon: Icons.groups_rounded,
                                  label: 'Сообщения клана',
                                  subtitle: 'Новый чат и события клана',
                                  value: _pushClanMessages,
                                  onChanged: (v) => _setClanMessages(v),
                                ),
                                const _CyberDivider(),
                                _SwitchRow(
                                  icon: Icons.system_update_rounded,
                                  label: 'Обновления игры',
                                  subtitle: 'Новые функции и патчи',
                                  value: _pushUpdates,
                                  onChanged: (v) => _setUpdates(v),
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),

                    const SizedBox(width: 24),

                    // ── RIGHT COLUMN (account, appearance, about, disconnect)
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── ACCOUNT SECTION ──────────────────────
                          _sectionLabel('АККАУНТ'),
                          const SizedBox(height: 10),
                          _SectionCard(
                            children: [
                              _NavRow(
                                icon: Icons.lock_rounded,
                                label: 'Сменить пароль',
                                subtitle: 'Изменить пароль доступа',
                                onTap: _showChangePasswordDialog,
                              ),
                              const _CyberDivider(),
                              _NavRow(
                                icon: Icons.language_rounded,
                                label: 'Язык интерфейса',
                                subtitle: _language,
                                onTap: _showLanguageDialog,
                              ),
                              const _CyberDivider(),
                              _NavRow(
                                icon: Icons.delete_forever_rounded,
                                label: 'Удалить аккаунт',
                                subtitle: 'Необратимое действие',
                                labelColor: _neonRed,
                                iconColor: _neonRed,
                                onTap: _showDeleteAccountDialog,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── APPEARANCE SECTION ─────────────────────
                          _sectionLabel('ОФОРМЛЕНИЕ'),
                          const SizedBox(height: 10),
                          _SectionCard(
                            children: [
                              _SwitchRow(
                                icon: Icons.dark_mode_rounded,
                                label: 'Тёмный режим',
                                subtitle: _darkTheme
                                    ? 'Чёрный фон включён'
                                    : 'Более светлый вариант',
                                value: _darkTheme,
                                onChanged: (v) => _setDarkTheme(v),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── ABOUT SECTION ─────────────────────────
                          _sectionLabel('О ПРИЛОЖЕНИИ'),
                          const SizedBox(height: 10),
                          _SectionCard(
                            children: [
                              _InfoRow(label: 'Игра', value: 'CyberHack'),
                              _InfoRow(label: 'Версия', value: '1.3.0'),
                              _InfoRow(label: 'Сборка', value: '2026.05.28'),
                              _InfoRow(label: 'Платформа', value: 'Windows Desktop'),
                              const _CyberDivider(),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Авторы',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        fontSize: 11,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Разработано командой CyberHack.',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Все персонажи и события вымышлены.',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── DISCONNECT BUTTON ────────────────────
                          CyberButton(
                            label: 'ОТКЛЮЧИТЬСЯ',
                            variant: CyberButtonVariant.danger,
                            icon: Icons.power_settings_new_rounded,
                            width: double.infinity,
                            onPressed: _showDisconnectDialog,
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Section Label ────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: _muted,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.5,
        ),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _neonCyan),
        ),
        title: const Text(
          'Язык интерфейса',
          style: TextStyle(color: _neonCyan, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Английский', 'Русский'].map((lang) {
            final isSelected = lang == _language;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    _setLanguage(lang);
                    Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _neonGreen.withValues(alpha: 0.12)
                          : const Color(0xFF12162A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? _neonGreen
                            : const Color(0xFF2A2F45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: isSelected ? _neonGreen : Colors.white38,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          lang,
                          style: TextStyle(
                            color: isSelected
                                ? _neonGreen
                                : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ЗАКРЫТЬ',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _neonCyan),
        ),
        title: const Text(
          'Сменить пароль',
          style: TextStyle(color: _neonCyan, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(
              label: 'Текущий пароль',
              controller: _currentPassCtrl,
              obscure: true,
            ),
            const SizedBox(height: 10),
            _dialogField(
              label: 'Новый пароль',
              controller: _newPassCtrl,
              obscure: true,
            ),
            const SizedBox(height: 10),
            _dialogField(
              label: 'Подтвердите новый пароль',
              controller: _confirmPassCtrl,
              obscure: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОТМЕНА',
                style: TextStyle(color: Colors.white54)),
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
                    backgroundColor: _neonRed,
                  ),
                );
                return;
              }

              if (newPass.length < 8) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Новый пароль должен быть не менее 8 символов.'),
                    backgroundColor: _neonRed,
                  ),
                );
                return;
              }

              if (newPass != confirm) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Пароли не совпадают.'),
                    backgroundColor: _neonRed,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              _currentPassCtrl.clear();
              _newPassCtrl.clear();
              _confirmPassCtrl.clear();

              try {
                await Supabase.instance.client.auth.updateUser(
                  UserAttributes(password: newPass),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Пароль успешно обновлён.'),
                      backgroundColor: _neonGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка: ${e.toString()}'),
                      backgroundColor: _neonRed,
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
    final auth = context.read<AuthProvider>();
    final userHandle = auth.displayName.isNotEmpty
        ? auth.displayName
        : Supabase.instance.client.auth.currentUser?.email ?? 'player';

    showDialog(
      context: context,
      builder: (ctx) {
        final confirmCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1A1F2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: _neonRed),
            ),
            title: const Text(
              'Удалить аккаунт?',
              style: TextStyle(color: _neonRed, fontWeight: FontWeight.w700),
            ),
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
                    color: _neonRed,
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
                      borderSide: const BorderSide(color: _neonRed),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF2A2F45)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: _neonRed),
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
                    ? () async {
                        confirmCtrl.dispose();
                        Navigator.pop(ctx);
                        try {
                          await Supabase.instance.client.auth.admin.deleteUser(
                              Supabase.instance.client.auth.currentUser!.id);
                          await auth.logout();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Аккаунт удалён.'),
                                backgroundColor: _neonRed,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Ошибка удаления: ${e.toString()}'),
                                backgroundColor: _neonRed,
                              ),
                            );
                          }
                        }
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
          side: const BorderSide(color: _neonCyan),
        ),
        title: const Text(
          'Отключиться?',
          style: TextStyle(color: _neonCyan, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Вы будете отключены от игрового сервера. Ваш прогресс сохраняется автоматически.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОТМЕНА',
                style: TextStyle(color: Colors.white54)),
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
          labelStyle:
              TextStyle(color: Colors.white.withValues(alpha: 0.4)),
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
            borderSide: const BorderSide(color: _neonCyan),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// TOP BAR — Back button + page title
// ═══════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── BACK BUTTON (← НАЗАД) ────────────────────────────────────
        _BackButton(),
        const SizedBox(width: 20),
        // ── Page Title ──────────────────────────────────────────────
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'НАСТРОЙКИ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'ПАРАМЕТРЫ СИСТЕМЫ · АУДИО · ГРАФИКА · УВЕДОМЛЕНИЯ',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BACK BUTTON — Always visible, top-left corner
// ═══════════════════════════════════════════════════════════════════════════

class _BackButton extends StatefulWidget {
  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go('/game/home'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hover
                ? _neonCyan.withValues(alpha: 0.12)
                : const Color(0xFF111827),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _neonCyan.withValues(alpha: _hover ? 0.6 : 0.2),
              width: _hover ? 1.5 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: _neonCyan.withValues(alpha: 0.15),
                      blurRadius: 16,
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_rounded,
                color: _neonCyan.withValues(alpha: _hover ? 1.0 : 0.7),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'НАЗАД',
                style: TextStyle(
                  color: _neonCyan.withValues(alpha: _hover ? 1.0 : 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION CARD — Wide card container for a settings group
// ═══════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bgCard, _bgCardInner],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SWITCH ROW — Toggle switch with icon, label, and subtitle
// ═══════════════════════════════════════════════════════════════════════════

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _neonCyan.withValues(alpha: value ? 0.12 : 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _neonCyan.withValues(alpha: value ? 0.3 : 0.1),
              ),
            ),
            child: Icon(
              icon,
              color: _neonCyan.withValues(alpha: value ? 1.0 : 0.4),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          // Label + Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: value ? 1.0 : 0.6),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Toggle
          SizedBox(
            width: 48,
            height: 26,
            child: FittedBox(
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: _neonGreen,
                activeTrackColor: const Color(0xFF0D2818),
                inactiveTrackColor: const Color(0xFF12162A),
                inactiveThumbColor: Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VOLUME SLIDER — Horizontal slider with icon, label, and value display
// ═══════════════════════════════════════════════════════════════════════════

class _VolumeSlider extends StatefulWidget {
  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final Color color;
  final double min;
  final double max;
  final bool displayPercent;

  const _VolumeSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.color = _neonCyan,
    this.min = 0.0,
    this.max = 1.0,
    this.displayPercent = false,
  });

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  bool _hover = false;

  String _formatValue(double v) {
    if (widget.displayPercent) {
      return '${(v * 100).round()}%';
    }
    return '${(v * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row
            Row(
              children: [
                Icon(
                  widget.icon,
                  color: widget.color.withValues(alpha: _hover ? 1.0 : 0.7),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: _hover ? 1.0 : 0.8),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                // Value display
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    _formatValue(widget.value),
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Slider
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: widget.color,
                inactiveTrackColor: const Color(0xFF12162A),
                thumbColor: widget.color,
                overlayColor: widget.color.withValues(alpha: 0.2),
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: widget.value,
                min: widget.min,
                max: widget.max,
                onChanged: widget.onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// QUALITY SELECTOR — Clickable option chips for graphics quality
// ═══════════════════════════════════════════════════════════════════════════

class _QualitySelector extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _QualitySelector({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.high_quality_rounded,
                  color: _neonCyan, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: options.map((opt) {
              final isSelected = opt == selected;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => onChanged(opt),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _neonGreen.withValues(alpha: 0.12)
                              : const Color(0xFF12162A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? _neonGreen
                                : const Color(0xFF2A2F45),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          opt,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? _neonGreen : Colors.white54,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NAV ROW — Clickable row for navigation actions (change password, etc.)
// ═══════════════════════════════════════════════════════════════════════════

class _NavRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color? labelColor;
  final Color? iconColor;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.labelColor,
    this.iconColor,
    required this.onTap,
  });

  @override
  State<_NavRow> createState() => _NavRowState();
}

class _NavRowState extends State<_NavRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final rowColor = widget.iconColor ?? _neonCyan;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: _hover
                ? rowColor.withValues(alpha: 0.06)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: rowColor.withValues(alpha: _hover ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: rowColor.withValues(alpha: _hover ? 0.4 : 0.15),
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: rowColor.withValues(alpha: _hover ? 1.0 : 0.7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.labelColor ??
                            Colors.white.withValues(alpha: _hover ? 1.0 : 0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: rowColor.withValues(alpha: _hover ? 0.8 : 0.25),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INFO ROW — Simple key-value display row
// ═══════════════════════════════════════════════════════════════════════════

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CYBER DIVIDER — Neon-styled horizontal divider
// ═══════════════════════════════════════════════════════════════════════════

class _CyberDivider extends StatelessWidget {
  const _CyberDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.06),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
