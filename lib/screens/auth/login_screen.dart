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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isHoveringButton = false;

  // ── Helpers ─────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading =
        authState is AsyncLoading || authState.hasError && authState.valueOrNull == null && authState.isLoading;
    final errorMessage = ref.read(authProvider.notifier).errorMessage;

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
                // ── Title ─────────────────────────────────────────────
                ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      colors: [_green, _cyan],
                    ).createShader(bounds);
                  },
                  child: const Text(
                    'CYBERHACK\nMANAGER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: _green,
                      // The shadow is applied via shader mask + container
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: _green.withOpacity(0.6),
                        blurRadius: 30,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Text(
                    'Войдите в даркнет',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: _textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // ── Error message ──────────────────────────────────────
                if (errorMessage != null && authState.hasError) ...[
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
                            errorMessage,
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

                // ── Email field ────────────────────────────────────────
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                  style: const TextStyle(color: _textPrimary, fontSize: 14),
                  cursorColor: _cyan,
                  decoration: _inputDecoration('Email'),
                  onSubmitted: (_) => _submitLogin(),
                ),
                const SizedBox(height: 16),

                // ── Password field ─────────────────────────────────────
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  enabled: !isLoading,
                  style: const TextStyle(color: _textPrimary, fontSize: 14),
                  cursorColor: _cyan,
                  decoration: _inputDecoration('Пароль').copyWith(
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
                  onSubmitted: (_) => _submitLogin(),
                ),
                const SizedBox(height: 28),

                // ── Login button ───────────────────────────────────────
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isHoveringButton = true),
                  onExit: (_) => setState(() => _isHoveringButton = false),
                  child: GestureDetector(
                    onTap: isLoading ? null : _submitLogin,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isHoveringButton
                              ? [_green, Color(0xFF00cc6a)]
                              : [_green.withOpacity(0.8), Color(0xFF00cc6a).withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _green
                                .withOpacity(_isHoveringButton ? 0.4 : 0.2),
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
                              'ВОЙТИ',
                              style: TextStyle(
                                color: _bgColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Register link ─────────────────────────────────────
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.go('/register'),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(color: _textMuted, fontSize: 13),
                        children: [
                          TextSpan(text: 'Нет аккаунта? '),
                          TextSpan(
                            text: 'Зарегистрируйтесь',
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

                // ── Bottom accent line ─────────────────────────────────
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

  // ── Submit ─────────────────────────────────────────────────────────────

  Future<void> _submitLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните все поля'),
          backgroundColor: _errorRed,
        ),
      );
      return;
    }

    await ref.read(authProvider.notifier).login(email, password);

    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (auth.hasError) {
      // Error is already displayed via the provider's errorMessage getter
    } else if (auth.valueOrNull != null) {
      context.go('/game');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}
