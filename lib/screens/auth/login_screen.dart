import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─── Matrix Rain Background ────────────────────────────────────────────────

class _MatrixColumn {
  double x;
  double y;
  double speed;
  final String chars;
  int charIndex;

  _MatrixColumn({required this.x, required this.y, required this.speed, required this.chars, this.charIndex = 0});
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
      // Draw fading trail
      for (int i = 0; i < 20; i++) {
        final trailY = col.y - i * 18;
        if (trailY < -20 || trailY > size.height + 20) continue;

        final trailOpacity = (1.0 - i / 20.0).clamp(0.0, 1.0);
        final trailChar = String.fromCharCode(
          0x30A0 + ((col.charIndex - i) % 96).clamp(0, 95),
        );

        final trailColor = i == 0
            ? green.withOpacity(opacity)
            : dimGreen.withOpacity(trailOpacity * opacity * 0.5);

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
            // Red shadow layer
            if (showGlitch)
              Text(
                widget.text,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w900,
                  color: Colors.red.withOpacity(0.7),
                  letterSpacing: 8,
                  fontFamily: 'monospace',
                ),
              ),
            // Cyan shadow layer
            if (showGlitch)
              Text(
                widget.text,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF00e5ff).withOpacity(0.7),
                  letterSpacing: 8,
                  fontFamily: 'monospace',
                ),
              ),
            // Main text
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

// ─── Cyberpunk Text Field ─────────────────────────────────────────────────

class _CyberTextField extends StatelessWidget {
  final String label;
  final String hintText;
  final bool obscureText;
  final TextEditingController controller;
  final IconData icon;

  const _CyberTextField({
    required this.label,
    required this.hintText,
    required this.controller,
    this.obscureText = false,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF00ff41),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0d1117),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF1a3a2a), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00ff41).withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(
              color: Color(0xFF00ff41),
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: const Color(0xFF00ff41).withOpacity(0.3),
                fontFamily: 'monospace',
              ),
              prefixIcon: Icon(icon, color: const Color(0xFF00e5ff), size: 18),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Login Screen ─────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _matrixController;
  late List<_MatrixColumn> _matrixColumns;
  late AnimationController _glowController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _matrixController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _initMatrixColumns();
  }

  void _initMatrixColumns() {
    final chars = List.generate(96, (i) => String.fromCharCode(0x30A0 + i)).join();
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
    _glowController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                if (col.y > 1200) {
                  col.y = Random().nextDouble() * -300;
                  col.speed = 1.5 + Random().nextDouble() * 3;
                }
              }
              return CustomPaint(
                painter: MatrixRainPainter(columns: _matrixColumns, opacity: 0.3),
                size: MediaQuery.of(context).size,
              );
            },
          ),

          // Overlay gradient for readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0a0e17).withOpacity(0.7),
                  const Color(0xFF0a0e17).withOpacity(0.5),
                  const Color(0xFF0a0e17).withOpacity(0.8),
                ],
              ),
            ),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                width: 380,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1f2e).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00ff41).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00ff41).withOpacity(0.15),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF00e5ff).withOpacity(0.1),
                      blurRadius: 40,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00ff41),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00ff41).withOpacity(0.4),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield,
                        color: Color(0xFF00ff41),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    const GlitchText(text: 'CYBERHACK', fontSize: 36),
                    const SizedBox(height: 4),
                    const Text(
                      '// NEURAL INTERFACE v2.0.77',
                      style: TextStyle(
                        color: Color(0xFF00e5ff),
                        fontSize: 11,
                        letterSpacing: 3,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Email field
                    _CyberTextField(
                      label: '[ ЭЛ. ПОЧТА ]',
                      hintText: 'operator@darknet.io',
                      controller: _emailController,
                      icon: Icons.alternate_email,
                    ),
                    const SizedBox(height: 20),

                    // Password field
                    _CyberTextField(
                      label: '[ ПАРОЛЬ ]',
                      hintText: '••••••••••••••••',
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text(
                          'ЗАБЫЛ ПАРОЛЬ?',
                          style: TextStyle(
                            color: Color(0xFF00e5ff),
                            fontSize: 11,
                            letterSpacing: 1,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Login button
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, _) {
                        final glow = _glowController.value;
                        return GestureDetector(
                          onTap: () => context.go('/main-menu'),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00ff41).withOpacity(0.8 + glow * 0.2),
                                  const Color(0xFF00cc33),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00ff41)
                                      .withOpacity(0.3 + glow * 0.4),
                                  blurRadius: 15 + glow * 10,
                                  spreadRadius: 1 + glow * 2,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                '▶ ПОДКЛЮЧИТЬСЯ К СЕТИ',
                                style: TextStyle(
                                  color: Color(0xFF0a0e17),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFF00ff41).withOpacity(0.2),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'ИЛИ',
                            style: TextStyle(
                              color: Color(0xFF00ff41),
                              fontSize: 11,
                              letterSpacing: 2,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFF00ff41).withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Register link
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: RichText(
                        text: const TextSpan(
                          text: 'НОВЫЙ ХАКЕР? ',
                          style: TextStyle(
                            color: Color(0xFF4a5568),
                            fontSize: 13,
                            letterSpacing: 1,
                            fontFamily: 'monospace',
                          ),
                          children: [
                            TextSpan(
                              text: 'РЕГИСТРАЦИЯ',
                              style: TextStyle(
                                color: Color(0xFF00e5ff),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF00e5ff),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Status bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0e17),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF00ff41).withOpacity(0.15),
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
        ],
      ),
    );
  }
}
