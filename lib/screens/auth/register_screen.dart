import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';

// ── Theme constants ─────────────────────────────────────────────────────

const _bgColor = Color(0xFF0a0e17);
const _cardBg = Color(0xFF111827);
const _green = Color(0xFF00ff88);
const _cyan = Color(0xFF00d4ff);
const _borderColor = Color(0xFF1e293b);
const _textPrimary = Color(0xFFe0e0e0);
const _textMuted = Color(0xFF6b7280);
const _errorRed = Color(0xFFff4444);

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isHoveringButton = false;
  String? _localError;

  // ── Helpers ─────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String label, {String? hint, String? helper}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperStyle: const TextStyle(color: _textMuted, fontSize: 11),
      labelStyle: const TextStyle(color: _textMuted, fontSize: 13),
      hintStyle: const TextStyle(color: _textMuted, fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF0d1117),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _cyan, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _errorRed, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _errorRed, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  String? _validateUsername(String value) {
    if (value.trim().isEmpty) return 'Введите никнейм';
    if (value.trim().length < 3) return 'Минимум 3 символа';
    if (value.trim().length > 20) return 'Максимум 20 символов';
    if (RegExp(r'[^\w\-]').hasMatch(value.trim())) {
      return 'Только буквы, цифры, _ и -';
    }
    return null;
  }

  String? _validateEmail(String value) {
    if (value.trim().isEmpty) return 'Введите email';
    if (!RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w+$').hasMatch(value.trim())) {
      return 'Некорректный email';
    }
    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return 'Введите пароль';
    if (value.length < 6) return 'Минимум 6 символов';
    return null;
  }

  void _clearErrors() {
    if (_localError != null) setState(() => _localError = null);
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState is AsyncLoading;
    final errorMessage = ref.read(authProvider.notifier).errorMessage;

    // Combine provider error with local validation error
    final displayError = authState.hasError ? errorMessage : _localError;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: _green.withOpacity(0.05),
                  blurRadius: 60,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Title ────────────────────────────────────────────
                ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      colors: [_green, _cyan],
                    ).createShader(bounds);
                  },
                  child: const Text(
                    'РЕГИСТРАЦИЯ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: _green,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Создайте нового оператора',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Error message ─────────────────────────────────────
                if (displayError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _errorRed.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: _errorRed, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            displayError,
                            style: const TextStyle(
                              color: _errorRed,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Username field ───────────────────────────────────
                TextField(
                  controller: _usernameCtrl,
                  enabled: !isLoading,
                  style:
                      const TextStyle(color: _textPrimary, fontSize: 14),
                  cursorColor: _cyan,
                  textCapitalization: TextCapitalization.none,
                  decoration: _inputDecoration(
                    'Никнейм',
                    hint: 'hacker_01',
                  ),
                  onChanged: (_) => _clearErrors(),
                  onSubmitted: (_) => _submitRegister(),
                ),
                const SizedBox(height: 16),

                // ── Email field ───────────────────────────────────────
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                  style:
                      const TextStyle(color: _textPrimary, fontSize: 14),
                  cursorColor: _cyan,
                  decoration: _inputDecoration(
                    'Email',
                    hint: 'operator@darknet.onion',
                  ),
                  onChanged: (_) => _clearErrors(),
                  onSubmitted: (_) => _submitRegister(),
                ),
                const SizedBox(height: 16),

                // ── Password field ───────────────────────────────────
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  enabled: !isLoading,
                  style:
                      const TextStyle(color: _textPrimary, fontSize: 14),
                  cursorColor: _cyan,
                  decoration: _inputDecoration(
                    'Пароль',
                    helper: 'Минимум 6 символов',
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _textMuted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  onChanged: (_) => _clearErrors(),
                  onSubmitted: (_) => _submitRegister(),
                ),
                const SizedBox(height: 28),

                // ── Register button ──────────────────────────────────
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) =>
                      setState(() => _isHoveringButton = true),
                  onExit: (_) =>
                      setState(() => _isHoveringButton = false),
                  child: GestureDetector(
                    onTap: isLoading ? null : _submitRegister,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isHoveringButton
                              ? [_green, Color(0xFF00cc6a)]
                              : [
                                  _green.withOpacity(0.8),
                                  Color(0xFF00cc6a).withOpacity(0.8)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _green.withOpacity(
                                _isHoveringButton ? 0.4 : 0.2),
                            blurRadius: 20,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: _bgColor,
                              ),
                            )
                          : const Text(
                              'СОЗДАТЬ АККАУНТ',
                              style: TextStyle(
                                color: _bgColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Login link ───────────────────────────────────────
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.go('/login'),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(color: _textMuted, fontSize: 13),
                        children: [
                          TextSpan(text: 'Уже есть аккаунт? '),
                          TextSpan(
                            text: 'Войдите',
                            style: TextStyle(
                              color: _cyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Bottom accent line ───────────────────────────────
                const SizedBox(height: 32),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        _green.withOpacity(0.3),
                        _cyan.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'v1.0.0  ·  Защищённое соединение',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Submit ───────────────────────────────────────────────────────────

  Future<void> _submitRegister() async {
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    // Client-side validation
    final usernameErr = _validateUsername(username);
    if (usernameErr != null) {
      setState(() => _localError = usernameErr);
      return;
    }
    final emailErr = _validateEmail(email);
    if (emailErr != null) {
      setState(() => _localError = emailErr);
      return;
    }
    final passErr = _validatePassword(password);
    if (passErr != null) {
      setState(() => _localError = passErr);
      return;
    }

    await ref.read(authProvider.notifier).register(email, password, username);

    if (!mounted) return;
    final auth = ref.read(authProvider);

    if (auth.hasError) {
      // Provider error is displayed via errorMessage getter
      setState(() => _localError = null);
    } else {
      // Registration succeeded – navigate to login with confirmation hint
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Аккаунт создан! Проверьте email для подтверждения.',
          ),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}
