import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/cyber_button.dart';

// ── Color Constants ──────────────────────────────────────────────────────

const _bgDark = Color(0xFF0a0e17);
const _surface = Color(0xFF111827);
const _surfaceVariant = Color(0xFF1a2332);
const _greenPrimary = Color(0xFF00ff88);
const _greenDark = Color(0xFF00cc6a);
const _cyanSecondary = Color(0xFF00d4ff);
const _dangerRed = Color(0xFFff4444);

// ── Settings Screen ───────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _supabase = Supabase.instance.client;

  // Decorative toggles (visual-only)
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final profile = game.profile;
    final username = profile?['username'] as String? ?? 'Хакер';
    final email =
        _supabase.auth.currentUser?.email ?? profile?['email'] as String?;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Navigation Row ───────────────────────────────────────
              _buildTopNav(),
              const SizedBox(height: 28),

              // ── Interface Section ───────────────────────────────────────
              _buildInterfaceSection(),
              const SizedBox(height: 20),

              // ── Audio Section ─────────────────────────────────────────────
              _buildAudioSection(),
              const SizedBox(height: 20),

              // ── Account Section ──────────────────────────────────────────
              _buildAccountSection(username, email),
              const SizedBox(height: 20),

              // ── About Section ────────────────────────────────────────────
              _buildAboutSection(),
              const SizedBox(height: 28),

              // ── Logout Button ────────────────────────────────────────────
              CyberButton(
                text: 'ВЫЙТИ ИЗ АККАУНТА',
                variant: CyberButtonVariant.danger,
                width: double.infinity,
                height: 48,
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (mounted) context.go('/auth/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Navigation ─────────────────────────────────────────────────────

  Widget _buildTopNav() {
    return Row(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: CyberButton(
            text: '← НАЗАД',
            variant: CyberButtonVariant.secondary,
            height: 40,
            onPressed: () => context.go('/game/dashboard'),
          ),
        ),
        const SizedBox(width: 20),
        const Text(
          'НАСТРОЙКИ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ── Interface Section ───────────────────────────────────────────────────

  Widget _buildInterfaceSection() {
    return _buildSectionCard(
      title: 'Интерфейс',
      icon: Icons.palette_outlined,
      children: [
        // Theme toggle (visual, disabled)
        _buildSettingsRow(
          label: 'Тёмная тема',
          trailing: Switch(
            value: true,
            onChanged: null, // disabled — dark-only
            activeColor: _greenPrimary,
            activeTrackColor: _greenPrimary.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey.shade600,
            inactiveTrackColor: Colors.grey.shade800,
          ),
        ),
        const _SettingsDivider(),
        // Language display
        _buildSettingsRow(
          label: 'Язык',
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _cyanSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _cyanSecondary.withValues(alpha: 0.25),
              ),
            ),
            child: const Text(
              'Русский',
              style: TextStyle(
                color: _cyanSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Audio Section ───────────────────────────────────────────────────────

  Widget _buildAudioSection() {
    return _buildSectionCard(
      title: 'Аудио',
      icon: Icons.volume_up_outlined,
      children: [
        _buildSettingsRow(
          label: 'Звуковые эффекты',
          trailing: Switch(
            value: _soundEnabled,
            onChanged: (val) => setState(() => _soundEnabled = val),
            activeColor: _greenPrimary,
            activeTrackColor: _greenPrimary.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey.shade600,
            inactiveTrackColor: Colors.grey.shade800,
          ),
        ),
        const _SettingsDivider(),
        _buildSettingsRow(
          label: 'Музыка',
          trailing: Switch(
            value: _musicEnabled,
            onChanged: (val) => setState(() => _musicEnabled = val),
            activeColor: _greenPrimary,
            activeTrackColor: _greenPrimary.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey.shade600,
            inactiveTrackColor: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  // ── Account Section ─────────────────────────────────────────────────────

  Widget _buildAccountSection(String username, String? email) {
    return _buildSectionCard(
      title: 'Аккаунт',
      icon: Icons.person_outline,
      children: [
        // Email display (read-only)
        _buildSettingsRow(
          label: 'Email',
          trailing: Text(
            email ?? '—',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 13,
            ),
          ),
        ),
        const _SettingsDivider(),
        // Username with edit button
        _buildSettingsRow(
          label: 'Имя пользователя',
          trailing: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showChangeUsernameDialog(username),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      color: _greenPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit_outlined,
                    color: _cyanSecondary.withValues(alpha: 0.6),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        const _SettingsDivider(),
        // Change password button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: CyberButton(
              text: 'Сменить пароль',
              variant: CyberButtonVariant.secondary,
              height: 38,
              icon: Icons.lock_outline,
              onPressed: () => _showResetPasswordDialog(email),
            ),
          ),
        ),
      ],
    );
  }

  // ── About Section ──────────────────────────────────────────────────────

  Widget _buildAboutSection() {
    return _buildSectionCard(
      title: 'О игре',
      icon: Icons.info_outline,
      children: [
        _buildSettingsRow(
          label: 'Версия',
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _greenPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _greenPrimary.withValues(alpha: 0.25),
              ),
            ),
            child: const Text(
              '3.0.0',
              style: TextStyle(
                color: _greenPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const _SettingsDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CyberHack Manager — хакерский тайкун',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Все корпорации и организации в игре являются вымышленными.',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Section Card Wrapper ────────────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _surfaceVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title
              Row(
                children: [
                  Icon(icon, color: _greenPrimary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: _surfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Section content
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  // ── Settings Row ────────────────────────────────────────────────────────

  Widget _buildSettingsRow({
    required String label,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  // ── Change Username Dialog ──────────────────────────────────────────────

  void _showChangeUsernameDialog(String currentUsername) {
    final controller = TextEditingController(text: currentUsername);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: _greenPrimary.withValues(alpha: 0.2),
              ),
            ),
            title: const Text(
              'Изменить имя',
              style: TextStyle(
                color: _greenPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Введите новое имя пользователя',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: _greenPrimary,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _surfaceVariant,
                    hintText: 'Новое имя',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _greenPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: _greenPrimary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
            actions: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'ОТМЕНА',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: CyberButton(
                  text: isSaving ? 'СОХРАНЕНИЕ...' : 'СОХРАНИТЬ',
                  variant: CyberButtonVariant.primary,
                  height: 38,
                  isLoading: isSaving,
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newName = controller.text.trim();
                          if (newName.isEmpty || newName == currentUsername) {
                            Navigator.pop(dialogContext);
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            final userId = _supabase.auth.currentUser?.id;
                            if (userId != null) {
                              await _supabase.from('profiles').update({
                                'username': newName,
                              }).eq('id', userId);
                              await ref
                                  .read(gameProvider.notifier)
                                  .refreshProfile();
                            }
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Имя изменено на «$newName»'),
                                  backgroundColor: _greenPrimary,
                                  foregroundColor: _bgDark,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setDialogState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Ошибка: $e'),
                                  backgroundColor: _dangerRed,
                                ),
                              );
                            }
                          }
                        },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Reset Password Dialog ──────────────────────────────────────────────

  void _showResetPasswordDialog(String? email) {
    final emailController =
        TextEditingController(text: email ?? _supabase.auth.currentUser?.email);
    bool isResetting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: _cyanSecondary.withValues(alpha: 0.2),
              ),
            ),
            title: const Text(
              'Сброс пароля',
              style: TextStyle(
                color: _cyanSecondary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'На указанный email будет отправлена ссылка для сброса пароля.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: _cyanSecondary,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _surfaceVariant,
                    hintText: 'Email',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _cyanSecondary.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: _cyanSecondary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
            actions: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'ОТМЕНА',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: CyberButton(
                  text: isResetting ? 'ОТПРАВКА...' : 'СБРОСИТЬ',
                  variant: CyberButtonVariant.secondary,
                  height: 38,
                  isLoading: isResetting,
                  onPressed: isResetting
                      ? null
                      : () async {
                          final resetEmail = emailController.text.trim();
                          if (resetEmail.isEmpty) return;
                          setDialogState(() => isResetting = true);
                          try {
                            await _supabase.auth
                                .resetPasswordForEmail(resetEmail);
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Ссылка для сброса отправлена на $resetEmail'),
                                  backgroundColor: _cyanSecondary,
                                  foregroundColor: _bgDark,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setDialogState(() => isResetting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Ошибка: $e'),
                                  backgroundColor: _dangerRed,
                                ),
                              );
                            }
                          }
                        },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Settings Row Divider ─────────────────────────────────────────────────

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: const Color(0xFF1a2332),
      margin: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}
