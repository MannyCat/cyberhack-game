import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─── Scanline Background Painter ──────────────────────────────────────────

class _ScanlinePainter extends CustomPainter {
  final double offset;

  _ScanlinePainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    // Base background
    final bgPaint = Paint()..color = const Color(0xFF0a0e17);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Horizontal scanlines
    final linePaint = Paint()
      ..color = const Color(0xFF00ff41).withOpacity(0.03)
      ..strokeWidth = 1;

    for (double y = (offset % 4) - 4; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Moving scan bar
    final scanY = offset % size.height;
    final scanPaint = Paint()
      ..color = const Color(0xFF00ff41).withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(0, scanY, size.width, 40),
      scanPaint,
    );

    // Corner decorations
    const cornerColor = Color(0xFF00e5ff);
    final cornerPaint = Paint()
      ..color = cornerColor.withOpacity(0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const cornerSize = 30.0;
    // Top-left
    canvas.drawLine(const Offset(10, 10), const Offset(10 + cornerSize, 10), cornerPaint);
    canvas.drawLine(const Offset(10, 10), const Offset(10, 10 + cornerSize), cornerPaint);
    // Top-right
    canvas.drawLine(
        Offset(size.width - 10, 10), Offset(size.width - 10 - cornerSize, 10), cornerPaint);
    canvas.drawLine(
        Offset(size.width - 10, 10), Offset(size.width - 10, 10 + cornerSize), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(10, size.height - 10),
        Offset(10 + cornerSize, size.height - 10), cornerPaint);
    canvas.drawLine(Offset(10, size.height - 10),
        Offset(10, size.height - 10 - cornerSize), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - 10, size.height - 10),
        Offset(size.width - 10 - cornerSize, size.height - 10), cornerPaint);
    canvas.drawLine(Offset(size.width - 10, size.height - 10),
        Offset(size.width - 10, size.height - 10 - cornerSize), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) => true;
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
            fontSize: 11,
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
                color: const Color(0xFF00ff41).withOpacity(0.08),
                blurRadius: 6,
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _checked = !_checked);
        widget.onChanged(_checked);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: _checked
                  ? const Color(0xFF00ff41).withOpacity(0.2)
                  : const Color(0xFF0d1117),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: _checked
                    ? const Color(0xFF00ff41)
                    : const Color(0xFF1a3a2a),
                width: 1.5,
              ),
            ),
            child: _checked
                ? const Icon(Icons.check, size: 14, color: Color(0xFF00ff41))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: widget.label,
                style: const TextStyle(
                  color: Color(0xFF4a5568),
                  fontSize: 11,
                  letterSpacing: 0.5,
                  fontFamily: 'monospace',
                ),
                children: [
                  TextSpan(
                    text: ' TERMS OF SERVICE',
                    style: TextStyle(
                      color: const Color(0xFF00e5ff).withOpacity(0.7),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _glowController;
  final _aliasController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    _glowController.dispose();
    _aliasController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: Stack(
        children: [
          // Scanline background
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, _) {
              return CustomPaint(
                painter: _ScanlinePainter(offset: _scanController.value * 400),
                size: MediaQuery.of(context).size,
              );
            },
          ),

          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1f2e).withOpacity(0.94),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00e5ff).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00e5ff).withOpacity(0.12),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF00ff41).withOpacity(0.08),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header icon
                    Container(
                      width: 56,
                      height: 56,
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
                            color: const Color(0xFF00e5ff).withOpacity(0.4),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1,
                        color: Color(0xFF0a0e17),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF00e5ff), Color(0xFF00ff41)],
                      ).createShader(bounds),
                      child: const Text(
                        'CREATE OPERATOR',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 4,
                          fontFamily: 'monospace',
                          shadows: [
                            Shadow(color: Color(0xFF00e5ff), blurRadius: 20),
                            Shadow(color: Color(0xFF00ff41), blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '// INITIALIZE NEW IDENTITY',
                      style: TextStyle(
                        color: Color(0xFF4a5568),
                        fontSize: 11,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Hacker alias field
                    _CyberTextField(
                      label: '[ HACKER ALIAS ]',
                      hintText: 'shadow_byte',
                      controller: _aliasController,
                      icon: Icons.hub_outlined,
                    ),
                    const SizedBox(height: 16),

                    // Email field
                    _CyberTextField(
                      label: '[ EMAIL ADDRESS ]',
                      hintText: 'operator@darknet.io',
                      controller: _emailController,
                      icon: Icons.alternate_email,
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    _CyberTextField(
                      label: '[ ACCESS KEY ]',
                      hintText: '••••••••••••',
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),

                    // Confirm password
                    _CyberTextField(
                      label: '[ CONFIRM KEY ]',
                      hintText: '••••••••••••',
                      controller: _confirmPasswordController,
                      icon: Icons.lock_reset,
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),

                    // Password strength indicator
                    _PasswordStrengthIndicator(
                      password: _passwordController.text,
                    ),
                    const SizedBox(height: 16),

                    // Terms checkbox
                    _CyberCheckbox(
                      label: 'I ACKNOWLEDGE AND ACCEPT THE',
                      onChanged: (v) => setState(() => _termsAccepted = v),
                    ),
                    const SizedBox(height: 24),

                    // Register button
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, _) {
                        final glow = _glowController.value;
                        final isEnabled = _termsAccepted;
                        return GestureDetector(
                          onTap: isEnabled
                              ? () => context.go('/main-menu')
                              : null,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isEnabled ? 1.0 : 0.4,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF00e5ff)
                                        .withOpacity(0.8 + glow * 0.2),
                                    const Color(0xFF009eb8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: isEnabled
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF00e5ff)
                                              .withOpacity(0.3 + glow * 0.4),
                                          blurRadius: 15 + glow * 10,
                                          spreadRadius: 1 + glow * 2,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: const Center(
                                child: Text(
                                  '⚡ JACK IN',
                                  style: TextStyle(
                                    color: Color(0xFF0a0e17),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Back to login
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: RichText(
                        text: const TextSpan(
                          text: 'ALREADY WIRED? ',
                          style: TextStyle(
                            color: Color(0xFF4a5568),
                            fontSize: 12,
                            letterSpacing: 1,
                            fontFamily: 'monospace',
                          ),
                          children: [
                            TextSpan(
                              text: 'LOGIN',
                              style: TextStyle(
                                color: Color(0xFF00ff41),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF00ff41),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // System info
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0e17),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF00ff41).withOpacity(0.1),
                        ),
                      ),
                      child: const Text(
                        '> ENCRYPTED CONNECTION ESTABLISHED\n'
                        '> PROTOCOL: TLS 1.3 | CIPHER: AES-256-GCM\n'
                        '> IDENTITY ANONYMIZATION: ACTIVE',
                        style: TextStyle(
                          color: Color(0xFF00ff41),
                          fontSize: 9,
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
        ],
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

    final strengthLevel = strength <= 1
        ? (strength == 0 ? ('NONE' as dynamic) : 'WEAK')
        : strength <= 3
            ? 'MODERATE'
            : 'STRONG';
    final color = strength <= 1
        ? (strength == 0 ? const Color(0xFF4a5568) : const Color(0xFFff4444))
        : strength <= 3
            ? const Color(0xFFffaa00)
            : const Color(0xFF00ff41);

    return Row(
      children: [
        const Text(
          'KEY STRENGTH: ',
          style: TextStyle(
            color: Color(0xFF4a5568),
            fontSize: 10,
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
        const SizedBox(width: 10),
        Text(
          strengthLevel.toString(),
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
