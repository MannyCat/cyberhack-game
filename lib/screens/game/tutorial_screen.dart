import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/tutorial_provider.dart';

// ─── Tutorial Screen — PC Desktop ─────────────────────────────────────────────

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    final tutorial = context.read<TutorialProvider>();
    _currentStep = tutorial.currentStep;

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    final tutorial = context.read<TutorialProvider>();
    if (step != _currentStep) {
      _slideController.reverse().then((_) {
        if (mounted) {
          setState(() => _currentStep = step);
          tutorial.goToStep(step);
          _slideController.forward();
        }
      });
    }
  }

  void _nextStep() {
    final tutorial = context.read<TutorialProvider>();
    if (_currentStep < tutorialSteps.length - 1) {
      _goToStep(_currentStep + 1);
    } else {
      tutorial.completeTutorial();
      context.go('/game/home');
    }
  }

  void _prevStep() {
    if (_currentStep > 0) _goToStep(_currentStep - 1);
  }

  void _skip() {
    context.read<TutorialProvider>().completeTutorial();
    context.go('/game/home');
  }

  @override
  Widget build(BuildContext context) {
    final step = tutorialSteps[_currentStep];
    final isLast = _currentStep == tutorialSteps.length - 1;
    final isFirst = _currentStep == 0;
    final progress = (_currentStep + 1) / tutorialSteps.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: Column(
        children: [
          // ── Top Bar: progress + close ──
          _buildTopBar(progress, step),

          // ── Main Content ──
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildStepContent(step, isLast),
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom: Navigation + Steps dots ──
          _buildBottomNav(step, isFirst, isLast),
        ],
      ),
    );
  }

  // ── Top Bar ──

  Widget _buildTopBar(double progress, TutorialStep step) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF111827), width: 1)),
      ),
      child: Row(
        children: [
          // Step counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: step.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: step.color.withValues(alpha: 0.2)),
            ),
            child: Text(
              'ШАГ ${_currentStep + 1} / ${tutorialSteps.length}',
              style: TextStyle(color: step.color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ),
          const SizedBox(width: 20),
          // Progress bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFF111827),
                valueColor: AlwaysStoppedAnimation<Color>(step.color),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Percentage
          Text('${(progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: step.color.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 20),
          // Skip button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _skip,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d1220),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1e293b)),
                ),
                child: const Text('ПРОПУСТИТЬ',
                  style: TextStyle(color: Color(0xFF4a5568), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step Content ──

  Widget _buildStepContent(TutorialStep step, bool isLast) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: Icon Card ──
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: step.color.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: step.color.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(color: step.color.withValues(alpha: 0.08), blurRadius: 30, spreadRadius: 4),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: step.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: step.color.withValues(alpha: 0.3), width: 2),
                      boxShadow: [
                        BoxShadow(color: step.color.withValues(alpha: 0.2), blurRadius: 20),
                      ],
                    ),
                    child: Icon(step.icon, color: step.color, size: 44),
                  ),
                  const SizedBox(height: 16),
                  Text(step.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: step.color.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ],
              ),
            ),
          ),

          const SizedBox(width: 36),

          // ── Right: Text Content ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(step.title,
                  style: TextStyle(color: step.color, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2, height: 1.2)),

                const SizedBox(height: 20),

                // Description
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0d1220),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: step.color.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.description,
                        style: const TextStyle(
                          color: Color(0xFFb0b8c8),
                          fontSize: 14,
                          height: 1.7,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (step.tip != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb, color: Color(0xFFFFD700), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text('СОВЕТ: ${step.tip}',
                                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Quick navigation cards for relevant screens
                if (_currentStep > 0 && _currentStep < tutorialSteps.length - 1) ...[
                  const SizedBox(height: 16),
                  _buildQuickNav(step),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNav(TutorialStep step) {
    String? navLabel;
    String? navPath;
    IconData? navIcon;

    switch (step.id) {
      case 'base':
        navLabel = 'Перейти к базе';
        navPath = '/game/network';
        navIcon = Icons.account_tree;
        break;
      case 'map':
        navLabel = 'Открыть карту мира';
        navPath = '/game/map';
        navIcon = Icons.public;
        break;
      case 'attack':
        navLabel = 'Выбрать цель';
        navPath = '/game/attack';
        navIcon = Icons.gps_fixed;
        break;
      case 'daily':
        navLabel = 'Забрать награду';
        navPath = '/game/daily-reward';
        navIcon = Icons.card_giftcard;
        break;
      case 'social':
        navLabel = 'Найти банду';
        navPath = '/game/clan';
        navIcon = Icons.groups;
        break;
    }

    if (navLabel == null) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          context.read<TutorialProvider>().completeTutorial();
          context.go(navPath!);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: step.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: step.color.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(navIcon, color: step.color, size: 20),
              const SizedBox(width: 12),
              Text(navLabel,
                style: TextStyle(color: step.color, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(width: 10),
              Text('(завершит обучение)', style: const TextStyle(color: Color(0xFF3a4060), fontSize: 11)),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: step.color.withValues(alpha: 0.4), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom Navigation ──

  Widget _buildBottomNav(TutorialStep step, bool isFirst, bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF111827), width: 1)),
      ),
      child: Row(
        children: [
          // Previous button
          if (!isFirst)
            _navButton('НАЗАД', const Color(0xFF4a5568), Icons.arrow_back, _prevStep)
          else
            const SizedBox(width: 140),

          const Spacer(),

          // Step dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(tutorialSteps.length, (i) {
              final isActive = i == _currentStep;
              final isPassed = i < _currentStep;
              final dotStep = tutorialSteps[i];

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _goToStep(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: isActive ? 36 : 12,
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: isActive
                          ? dotStep.color
                          : isPassed
                              ? dotStep.color.withValues(alpha: 0.3)
                              : const Color(0xFF1e2535),
                      boxShadow: isActive
                          ? [BoxShadow(color: dotStep.color.withValues(alpha: 0.4), blurRadius: 8)]
                          : [],
                    ),
                  ),
                ),
              );
            }),
          ),

          const Spacer(),

          // Next button
          _navButton(
            isLast ? 'НАЧАТЬ ИГРУ' : 'ДАЛЕЕ',
            step.color,
            isLast ? Icons.rocket_launch : Icons.arrow_forward,
            _nextStep,
          ),
        ],
      ),
    );
  }

  Widget _navButton(String label, Color color, IconData icon, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 14),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2)),
              const SizedBox(width: 10),
              Icon(icon, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
