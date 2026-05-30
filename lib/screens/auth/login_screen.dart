import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

// ─── Matrix Rain Background ────────────────────────────────────────────────

class _MatrixColumn {
  double x;
  double y;
  double speed;
  final String chars;
  int charIndex;

  _MatrixColumn({
    required this.x,
    required this.y,
    required this.speed,
    required this.chars,
    this.charIndex = 0,
  });
}

class MatrixRainPainter extends CustomPainter {
  final List<_MatrixColumn> columns;
  final double opacity;

  MatrixRainPainter({required this.columns, this.opacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    const green = Color(0xFF00ff41);
    const dimGreen = Color(0x4000ff41);

    final bgPaint = Paint()..color = const Color(0xFF0a0e17);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (final col in columns) {
      for (int i = 0; i < 20; i++) {
        final trailY = col.y - i * 18;
        if (trailY < -20 || trailY > size.height + 20) continue;

        final trailOpacity = (1.0 - i / 20.0).clamp(0.0, 1.0);
        final trailChar = String.fromCharCode(
          0x30A0 + ((col.charIndex - i) % 96).clamp(0, 95),
        );

        final trailColor = i == 0
            ? green.withValues(alpha: opacity)
            : dimGreen.withValues(alpha: trailOpacity * opacity * 0.5);

        textPainter.text = TextSpan(
          text: trailChar,
          style: TextStyle(
            color: trailColor,
            fontSize: 14,
            fontFamily: 'monospace',
            fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(col.x - textPainter.width / 2, trailY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant MatrixRainPainter oldDelegate) => true;
}

// ─── Glitch Text Widget ────────────────────────────────────────────────────

class GlitchText extends StatefulWidget {
  final String text;
  final double fontSize;

  const GlitchText({super.key, required this.text, this.fontSize = 48});

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText> with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glitchOffset = sin(_controller.value * 2 * pi * 5) * 2;
        final showGlitch = (_controller.value * 30).toInt() % 7 == 0;

        return Stack(
          children: [
            if (showGlitch)
              Text(
                widget.text,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w900,
                  color: Colors.red.withValues(alpha: 0.7),
                  letterSpacing: 8,
                  fontFamily: 'monospace',
                ),
              ),
            if (showGlitch)
              Text(
                widget.text,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF00e5ff).withValues(alpha: 0.7),
                  letterSpacing: 8,
                  fontFamily: 'monospace',
                ),
              ),
            Transform.translate(
              offset: Offset(showGlitch ? glitchOffset : 0, 0),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00ff41), Color(0xFF00e5ff)],
                ).createShader(bounds),
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 8,
                    fontFamily: 'monospace',
                    shadows: const [
                      Shadow(color: Color(0xFF00ff41), blurRadius: 20),
                      Shadow(color: Color(0xFF00e5ff), blurRadius: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Neon Title with persistent glow ───────────────────────────────────────

class _NeonTitle extends StatelessWidget {
  const _NeonTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const GlitchText(text: 'CYBERHACK', fontSize: 42),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFF00e5ff).withValues(alpha: 0.25),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(4),
            color: const Color(0xFF00e5ff).withValues(alpha: 0.04),
          ),
          child: const Text(
            '// НЕЙРО-ИНТЕРФЕЙС v2.0.77',
            style: TextStyle(
              color: Color(0xFF00e5ff),
              fontSize: 12,
              letterSpacing: 3,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Cyberpunk Desktop Text Field ────────────────────────────────────────

class CyberTextField extends StatefulWidget {
  final String label;
  final String hintText;
  final bool obscureText;
  final TextEditingController controller;
  final IconData icon;
  final String? errorText;
  final Widget? suffixIcon;

  const CyberTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    this.obscureText = false,
    required this.icon,
    this.errorText,
    this.suffixIcon,
  });

  @override
  State<CyberTextField> createState() => _CyberTextFieldState();
}

class _CyberTextFieldState extends State<CyberTextField> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderColor = hasError
        ? const Color(0xFFFF4444)
        : _isFocused
            ? const Color(0xFF00ff41)
            : _isHovered
                ? const Color(0xFF00ff41).withValues(alpha: 0.6)
                : const Color(0xFF1a3a2a);

    final glowColor = _isFocused
        ? const Color(0xFF00ff41).withValues(alpha: 0.2)
        : const Color(0xFF00ff41).withValues(alpha: 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: const Color(0xFF00e5ff), size: 14),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: hasError
                      ? const Color(0xFFFF4444)
                      : const Color(0xFF00ff41),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: const Color(0xFF0d1117),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: hasError
                      ? const Color(0xFFFF4444).withValues(alpha: 0.15)
                      : glowColor,
                  blurRadius: _isFocused ? 12 : 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Focus(
              onFocusChange: (v) => setState(() => _isFocused = v),
              child: TextField(
                controller: widget.controller,
                obscureText: widget.obscureText,
                style: const TextStyle(
                  color: Color(0xFF00ff41),
                  fontFamily: 'monospace',
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: const Color(0xFF00ff41).withValues(alpha: 0.25),
                    fontFamily: 'monospace',
                    fontSize: 15,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Icon(
                      widget.icon,
                      color: const Color(0xFF00e5ff).withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 44, minHeight: 24),
                  suffixIcon: widget.suffixIcon,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  errorText: null,
                ),
              ),
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFFF4444), size: 12),
                  const SizedBox(width: 4),
                  Text(
                    widget.errorText!,
                    style: const TextStyle(
                      color: Color(0xFFFF4444),
                      fontSize: 11,
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
}

// ─── Hover Button ─────────────────────────────────────────────────────────

class _CyberHoverButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String text;
  final Color baseColor;
  final Color glowColor;
  final bool isLoading;
  final Widget? loadingWidget;

  const _CyberHoverButton({
    required this.onPressed,
    required this.text,
    this.baseColor = const Color(0xFF00ff41),
    this.glowColor = const Color(0xFF00ff41),
    this.isLoading = false,
    this.loadingWidget,
  });

  @override
  State<_CyberHoverButton> createState() => _CyberHoverButtonState();
}

class _CyberHoverButtonState extends State<_CyberHoverButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _isPressed
                    ? widget.baseColor.withValues(alpha: 0.6)
                    : widget.baseColor.withValues(alpha: _isHovered ? 1.0 : 0.85),
                widget.baseColor.withValues(alpha: _isPressed ? 0.4 : 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor
                    .withValues(alpha: _isHovered ? 0.5 : 0.25),
                blurRadius: _isHovered ? 24 : 12,
                spreadRadius: _isHovered ? 3 : 1,
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? widget.loadingWidget ??
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0a0e17),
                      ),
                    )
                : Text(
                    widget.text,
                    style: TextStyle(
                      color: const Color(0xFF0a0e17),
                      fontSize: _isHovered ? 15 : 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Login Screen ─────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late AnimationController _matrixController;
  late List<_MatrixColumn> _matrixColumns;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _matrixController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _initMatrixColumns();
  }

  void _initMatrixColumns() {
    final chars =
        List.generate(96, (i) => String.fromCharCode(0x30A0 + i)).join();
    _matrixColumns = List.generate(60, (i) {
      return _MatrixColumn(
        x: i * 12.0 + 6,
        y: Random().nextDouble() * -500,
        speed: 1.5 + Random().nextDouble() * 3,
        chars: chars,
        charIndex: Random().nextInt(96),
      );
    });
  }

  @override
  void dispose() {
    _matrixController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите адрес электронной почты')),
      );
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите пароль')),
      );
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный формат электронной почты')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(
        email: email,
        password: password,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Ошибка входа'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка подключения: $e'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: Stack(
        children: [
          // Matrix rain background
          AnimatedBuilder(
            animation: _matrixController,
            builder: (context, _) {
              for (final col in _matrixColumns) {
                col.y += col.speed;
                col.charIndex = (col.charIndex + 1) % 96;
                if (col.y > size.height) {
                  col.y = Random().nextDouble() * -300;
                  col.speed = 1.5 + Random().nextDouble() * 3;
                }
              }
              return CustomPaint(
                painter:
                    MatrixRainPainter(columns: _matrixColumns, opacity: 0.3),
                size: size,
              );
            },
          ),

          // Overlay gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0a0e17).withValues(alpha: 0.7),
                  const Color(0xFF0a0e17).withValues(alpha: 0.5),
                  const Color(0xFF0a0e17).withValues(alpha: 0.8),
                ],
              ),
            ),
          ),

          // ─── Centered Card ───────────────────────────────────────────────
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 40),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(40, 40, 40, 32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a1f2e).withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00ff41).withValues(alpha: 0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF00ff41).withValues(alpha: 0.12),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color:
                            const Color(0xFF00e5ff).withValues(alpha: 0.08),
                        blurRadius: 50,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF00ff41),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00ff41)
                                  .withValues(alpha: 0.4),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield,
                          color: Color(0xFF00ff41),
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title with neon glow
                      const _NeonTitle(),
                      const SizedBox(height: 36),

                      // Email field
                      CyberTextField(
                        label: '[ ЭЛ. ПОЧТА ]',
                        hintText: 'operator@darknet.io',
                        controller: _emailController,
                        icon: Icons.alternate_email,
                      ),
                      const SizedBox(height: 22),

                      // Password field
                      CyberTextField(
                        label: '[ ПАРОЛЬ ]',
                        hintText: '••••••••••••••••',
                        controller: _passwordController,
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: const Color(0xFF00e5ff),
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: _CyberLink(
                          text: 'ЗАБЫЛ ПАРОЛЬ?',
                          onTap: () async {
                            final email = _emailController.text.trim();
                            if (email.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Введите email для сброса пароля'),
                                ),
                              );
                              return;
                            }
                            final auth = context.read<AuthProvider>();
                            final ok = await auth.resetPassword(email: email);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? 'Инструкции отправлены на $email'
                                      : auth.errorMessage ??
                                          'Ошибка сброса пароля'),
                                  backgroundColor: ok
                                      ? const Color(0xFF00ff41)
                                      : const Color(0xFFFF4444),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Login button
                      _CyberHoverButton(
                        onPressed: _isSubmitting ? null : _handleLogin,
                        text: '▶  ПОДКЛЮЧИТЬСЯ К СЕТИ',
                        isLoading: _isSubmitting,
                      ),
                      const SizedBox(height: 28),

                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color:
                                  const Color(0xFF00ff41).withValues(alpha: 0.15),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'ИЛИ',
                              style: TextStyle(
                                color: const Color(0xFF00ff41).withValues(alpha: 0.5),
                                fontSize: 11,
                                letterSpacing: 2,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color:
                                  const Color(0xFF00ff41).withValues(alpha: 0.15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Register link
                      _CyberLink(
                        label: 'НОВЫЙ ХАКЕР?  ',
                        text: 'РЕГИСТРАЦИЯ',
                        onTap: () => context.go('/register'),
                      ),
                      const SizedBox(height: 20),

                      // Status bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0a0e17),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF00ff41)
                                .withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00ff41),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'СИСТЕМА В СЕТИ',
                                  style: TextStyle(
                                    color: Color(0xFF00ff41),
                                    fontSize: 10,
                                    letterSpacing: 1,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'ЗАДЕРЖКА: 12мс',
                              style: TextStyle(
                                color: Color(0xFF00e5ff),
                                fontSize: 10,
                                letterSpacing: 1,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hoverable Link ──────────────────────────────────────────────────────

class _CyberLink extends StatefulWidget {
  final String text;
  final String? label;
  final VoidCallback onTap;

  const _CyberLink({
    required this.text,
    this.label,
    required this.onTap,
  });

  @override
  State<_CyberLink> createState() => _CyberLinkState();
}

class _CyberLinkState extends State<_CyberLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Color(0xFF4a5568),
              fontSize: 13,
              letterSpacing: 1,
              fontFamily: 'monospace',
            ),
            children: [
              if (widget.label != null) TextSpan(text: widget.label),
              TextSpan(
                text: widget.text,
                style: TextStyle(
                  color: _isHovered
                      ? const Color(0xFF00e5ff)
                      : const Color(0xFF00e5ff).withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                  decoration:
                      _isHovered ? TextDecoration.underline : TextDecoration.none,
                  decorationColor: const Color(0xFF00e5ff),
                  shadows: _isHovered
                      ? const [
                          Shadow(
                              color: Color(0xFF00e5ff),
                              blurRadius: 8,
                              offset: Offset(0, 0))
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
