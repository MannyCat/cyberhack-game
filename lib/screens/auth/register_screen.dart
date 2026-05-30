import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

// ─── Scanline Background Painter ──────────────────────────────────────────

class _ScanlinePainter extends CustomPainter {
  final double offset;

  _ScanlinePainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0a0e17);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF00ff41).withValues(alpha: 0.03)
      ..strokeWidth = 1;

    for (double y = (offset % 4) - 4; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final scanY = offset % size.height;
    final scanPaint = Paint()
      ..color = const Color(0xFF00ff41).withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(0, scanY, size.width, 40),
      scanPaint,
    );

    const cornerColor = Color(0xFF00e5ff);
    final cornerPaint = Paint()
      ..color = cornerColor.withValues(alpha: 0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const cornerSize = 30.0;
    canvas.drawLine(const Offset(10, 10), const Offset(10 + cornerSize, 10), cornerPaint);
    canvas.drawLine(const Offset(10, 10), const Offset(10, 10 + cornerSize), cornerPaint);
    canvas.drawLine(
        Offset(size.width - 10, 10), Offset(size.width - 10 - cornerSize, 10), cornerPaint);
    canvas.drawLine(
        Offset(size.width - 10, 10), Offset(size.width - 10, 10 + cornerSize), cornerPaint);
    canvas.drawLine(Offset(10, size.height - 10),
        Offset(10 + cornerSize, size.height - 10), cornerPaint);
    canvas.drawLine(Offset(10, size.height - 10),
        Offset(10, size.height - 10 - cornerSize), cornerPaint);
    canvas.drawLine(Offset(size.width - 10, size.height - 10),
        Offset(size.width - 10 - cornerSize, size.height - 10), cornerPaint);
    canvas.drawLine(Offset(size.width - 10, size.height - 10),
        Offset(size.width - 10, size.height - 10 - cornerSize), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) => true;
}

// ─── Glitch Text (shared visual identity) ─────────────────────────────────

class _GlitchTitle extends StatefulWidget {
  const _GlitchTitle();

  @override
  State<_GlitchTitle> createState() => _GlitchTitleState();
}

class _GlitchTitleState extends State<_GlitchTitle>
    with TickerProviderStateMixin {
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
        final t = _controller.value;
        final glitchOffset = (t * 2 * 3.14159 * 5).abs() * 2;
        final showGlitch = (t * 30).toInt() % 7 == 0;

        return Stack(
          children: [
            if (showGlitch)
              Text(
                'CYBERHACK',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.red.withValues(alpha: 0.7),
                  letterSpacing: 8,
                  fontFamily: 'monospace',
                ),
              ),
            if (showGlitch)
              Text(
                'CYBERHACK',
                style: TextStyle(
                  fontSize: 42,
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
                  colors: [Color(0xFF00e5ff), Color(0xFF00ff41)],
                ).createShader(bounds),
                child: const Text(
                  'CYBERHACK',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 8,
                    fontFamily: 'monospace',
                    shadows: [
                      Shadow(color: Color(0xFF00e5ff), blurRadius: 20),
                      Shadow(color: Color(0xFF00ff41), blurRadius: 10),
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

// ─── Neon Title ──────────────────────────────────────────────────────────

class _NeonTitle extends StatelessWidget {
  const _NeonTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _GlitchTitle(),
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
            '// СОЗДАТЬ ОПЕРАТОРА',
            style: TextStyle(
              color: Color(0xFF00e5ff),
              fontSize: 12,
              letterSpacing: 3,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          '// ИНИЦИАЛИЗАЦИЯ НОВОЙ ЛИЧНОСТИ',
          style: TextStyle(
            color: Color(0xFF4a5568),
            fontSize: 11,
            letterSpacing: 2,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

// ─── Cyberpunk Desktop Text Field ────────────────────────────────────────

class _CyberTextField extends StatefulWidget {
  final String label;
  final String hintText;
  final bool obscureText;
  final TextEditingController controller;
  final IconData icon;
  final String? errorText;
  final Widget? suffixIcon;

  const _CyberTextField({
    required this.label,
    required this.hintText,
    required this.controller,
    this.obscureText = false,
    required this.icon,
    this.errorText,
    this.suffixIcon,
  });

  @override
  State<_CyberTextField> createState() => _CyberTextFieldState();
}

class _CyberTextFieldState extends State<_CyberTextField> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderColor = hasError
        ? const Color(0xFFFF4444)
        : _isFocused
            ? const Color(0xFF00e5ff)
            : _isHovered
                ? const Color(0xFF00e5ff).withValues(alpha: 0.6)
                : const Color(0xFF1a3a2a);

    final glowColor = _isFocused
        ? const Color(0xFF00e5ff).withValues(alpha: 0.2)
        : const Color(0xFF00e5ff).withValues(alpha: 0.08);

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

  const _CyberHoverButton({
    required this.onPressed,
    required this.text,
    this.baseColor = const Color(0xFF00e5ff),
    this.glowColor = const Color(0xFF00e5ff),
    this.isLoading = false,
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
                ? const SizedBox(
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
                      letterSpacing: 4,
                      fontFamily: 'monospace',
                    ),
                  ),
          ),
        ),
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
                      ? const Color(0xFF00ff41)
                      : const Color(0xFF00ff41).withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                  decoration:
                      _isHovered ? TextDecoration.underline : TextDecoration.none,
                  decorationColor: const Color(0xFF00ff41),
                  shadows: _isHovered
                      ? const [
                          Shadow(
                              color: Color(0xFF00ff41),
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

// ─── Cyberpunk Checkbox ───────────────────────────────────────────────────

class _CyberCheckbox extends StatefulWidget {
  final String label;
  final ValueChanged<bool> onChanged;

  const _CyberCheckbox({required this.label, required this.onChanged});

  @override
  State<_CyberCheckbox> createState() => _CyberCheckboxState();
}

class _CyberCheckboxState extends State<_CyberCheckbox> {
  bool _checked = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          setState(() => _checked = !_checked);
          widget.onChanged(_checked);
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: _checked
                    ? const Color(0xFF00e5ff).withValues(alpha: 0.2)
                    : const Color(0xFF0d1117),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _checked
                      ? const Color(0xFF00e5ff)
                      : _isHovered
                          ? const Color(0xFF00e5ff).withValues(alpha: 0.5)
                          : const Color(0xFF1a3a2a),
                  width: 1.5,
                ),
                boxShadow: _checked
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00e5ff)
                              .withValues(alpha: 0.15),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
              ),
              child: _checked
                  ? const Icon(Icons.check, size: 14, color: Color(0xFF00e5ff))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: widget.label,
                  style: TextStyle(
                    color: const Color(0xFF4a5568).withValues(
                        alpha: _isHovered ? 1.0 : 0.8),
                    fontSize: 12,
                    letterSpacing: 0.5,
                    fontFamily: 'monospace',
                  ),
                  children: [
                    TextSpan(
                      text: ' УСЛОВИЯ ИСПОЛЬЗОВАНИЯ',
                      style: TextStyle(
                        color: const Color(0xFF00e5ff).withValues(alpha: 0.7),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Password Strength Indicator ─────────────────────────────────────────

class _PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const _PasswordStrengthIndicator({required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    final String strengthLevel;
    if (strength == 0) {
      strengthLevel = 'НЕТ';
    } else if (strength <= 1) {
      strengthLevel = 'СЛАБЫЙ';
    } else if (strength <= 3) {
      strengthLevel = 'СРЕДНИЙ';
    } else {
      strengthLevel = 'СИЛЬНЫЙ';
    }

    final color = strength == 0
        ? const Color(0xFF4a5568)
        : strength <= 1
            ? const Color(0xFFff4444)
            : strength <= 3
                ? const Color(0xFFffaa00)
                : const Color(0xFF00ff41);

    return Row(
      children: [
        const Text(
          'НАДЁЖНОСТЬ КЛЮЧА: ',
          style: TextStyle(
            color: Color(0xFF4a5568),
            fontSize: 11,
            letterSpacing: 1,
            fontFamily: 'monospace',
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: strength / 5,
              backgroundColor: const Color(0xFF0d1117),
              color: color,
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          strengthLevel,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

// ─── Register Screen ──────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  final _aliasController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _termsAccepted = false;
  bool _isSubmitting = false;
  String? _fieldError;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _aliasController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final alias = _aliasController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    setState(() => _fieldError = null);

    // Валидация
    if (alias.isEmpty || alias.length < 3) {
      setState(() => _fieldError = 'Псевдоним должен быть не менее 3 символов');
      return;
    }
    if (alias.length > 20) {
      setState(() => _fieldError = 'Псевдоним не более 20 символов');
      return;
    }
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _fieldError = 'Введите корректный email');
      return;
    }
    if (password.length < 8) {
      setState(() => _fieldError = 'Пароль должен быть не менее 8 символов');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _fieldError = 'Пароли не совпадают');
      return;
    }
    if (!_termsAccepted) {
      setState(() => _fieldError = 'Примите условия использования');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.register(
        email: email,
        password: password,
        username: alias,
      );

      if (!success && mounted) {
        setState(
            () => _fieldError = authProvider.errorMessage ?? 'Ошибка регистрации');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _fieldError = 'Ошибка подключения: $e');
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
          // Scanline background
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, _) {
              return CustomPaint(
                painter: _ScanlinePainter(
                    offset: _scanController.value * 400),
                size: size,
              );
            },
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
                      color: const Color(0xFF00e5ff).withValues(alpha: 0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF00e5ff).withValues(alpha: 0.12),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color:
                            const Color(0xFF00ff41).withValues(alpha: 0.08),
                        blurRadius: 50,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF00e5ff),
                            width: 2,
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF00e5ff),
                              Color(0xFF00ff41),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00e5ff)
                                  .withValues(alpha: 0.4),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1,
                          color: Color(0xFF0a0e17),
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title with neon glow
                      const _NeonTitle(),
                      const SizedBox(height: 32),

                      // Error banner
                      if (_fieldError != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFFF4444).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Color(0xFFFF4444), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _fieldError!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF4444),
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Hacker alias
                      _CyberTextField(
                        label: '[ ПСЕВДОНИМ ХАКЕРА ]',
                        hintText: 'shadow_byte',
                        controller: _aliasController,
                        icon: Icons.hub_outlined,
                      ),
                      const SizedBox(height: 20),

                      // Email
                      _CyberTextField(
                        label: '[ ЭЛ. ПОЧТА ]',
                        hintText: 'operator@darknet.io',
                        controller: _emailController,
                        icon: Icons.alternate_email,
                      ),
                      const SizedBox(height: 20),

                      // Password
                      _CyberTextField(
                        label: '[ ПАРОЛЬ ]',
                        hintText: '••••••••••••',
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
                      const SizedBox(height: 20),

                      // Confirm password
                      _CyberTextField(
                        label: '[ ПОДТВЕРДИТЕ ПАРОЛЬ ]',
                        hintText: '••••••••••••',
                        controller: _confirmPasswordController,
                        icon: Icons.lock_reset,
                        obscureText: _obscureConfirm,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: const Color(0xFF00e5ff),
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password strength
                      _PasswordStrengthIndicator(
                        password: _passwordController.text,
                      ),
                      const SizedBox(height: 20),

                      // Terms
                      _CyberCheckbox(
                        label: 'Я ПРИНИМАЮ',
                        onChanged: (v) => setState(() => _termsAccepted = v),
                      ),
                      const SizedBox(height: 28),

                      // Register button
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity:
                            (_termsAccepted && !_isSubmitting) ? 1.0 : 0.35,
                        child: _CyberHoverButton(
                          onPressed: (_termsAccepted && !_isSubmitting)
                              ? _handleRegister
                              : null,
                          text: '⚡  ПОДКЛЮЧИТЬСЯ',
                          isLoading: _isSubmitting,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Back to login
                      _CyberLink(
                        label: 'УЖЕ ПОДКЛЮЧЕНЫ?  ',
                        text: 'ВОЙТИ',
                        onTap: () => context.go('/login'),
                      ),
                      const SizedBox(height: 20),

                      // System info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0a0e17),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF00ff41)
                                .withValues(alpha: 0.1),
                          ),
                        ),
                        child: const Text(
                          '> ЗАШИФРОВАННОЕ СОЕДИНЕНИЕ УСТАНОВЛЕНО\n'
                          '> ПРОТОКОЛ: TLS 1.3 | ШИФР: AES-256-GCM\n'
                          '> АНОНИМИЗАЦИЯ ЛИЧНОСТИ: АКТИВНА',
                          style: TextStyle(
                            color: Color(0xFF00ff41),
                            fontSize: 10,
                            letterSpacing: 0.5,
                            fontFamily: 'monospace',
                            height: 1.6,
                          ),
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
