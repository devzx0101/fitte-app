import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/session_stats.dart';
import '../widgets/bubo_widget.dart';

class SummaryScreen extends StatefulWidget {
  final SessionStats stats;
  final VoidCallback onRestart;
  final VoidCallback? onHome;

  const SummaryScreen({
    super.key,
    required this.stats,
    required this.onRestart,
    this.onHome,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _xpProgressAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _xpProgressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.stats.xpProgressRatio,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final repLabel = stats.exerciseType == ExerciseType.jumpingJacks
        ? 'Jumps'
        : stats.exerciseType == ExerciseType.plank
            ? 'Hold'
            : stats.exerciseType.displayName;

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F), // Deep Obsidian Dark Background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // 1. TOP GLOWING RING WITH CELEBRATING BUBO & LEVEL BADGE
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Concentric Outer Glow Rings
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFB6FF3B).withValues(alpha: 0.30),
                                const Color(0xFF22C55E).withValues(alpha: 0.12),
                                Colors.transparent,
                              ],
                              stops: const [0.3, 0.7, 1.0],
                            ),
                          ),
                        ),

                        // Glowing Emerald Circle Card
                        Container(
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF84CC16),
                                Color(0xFFA3E635),
                                Color(0xFF4ADE80),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFA3E635).withValues(alpha: 0.45),
                                blurRadius: 24,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: const BuboWidget(
                                mood: BuboMood.celebrate,
                                role: BuboRole.celebrator,
                                size: 82,
                                isAnimated: true,
                              ),
                            ),
                          ),
                        ),

                        // Level Badge overlay on bottom of ring
                        Positioned(
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFA3E635),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFA3E635).withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_rounded, color: Color(0xFFA3E635), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Lv ${stats.userLevel}',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 2. SESSION COMPLETE HEADER
                  Text(
                    'Session Complete',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+${stats.xpEarned} XP earned this session',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 3. LEVEL & XP PROGRESS BAR
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Animated Progress Bar Track
                      AnimatedBuilder(
                        animation: _xpProgressAnimation,
                        builder: (context, child) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 10,
                              width: double.infinity,
                              color: const Color(0xFF1E293B),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: _xpProgressAnimation.value.clamp(0.05, 1.0),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF84CC16),
                                          Color(0xFFA3E635),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),

                      // Level and XP Text Labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Level ${stats.userLevel}',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${stats.currentXp} / ${stats.targetXp} XP',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 4. FOUR STAT CARDS (2x2 GRID IN DEEP SLATE #161822)
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.accessibility_new_rounded,
                          value: '${stats.reps}',
                          label: repLabel,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.layers_rounded,
                          value: '${stats.sets}',
                          label: 'Sets',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.speed_rounded,
                          value: '${stats.bestCpm > 0 ? stats.bestCpm : 129}',
                          label: 'Best cpm',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.schedule_rounded,
                          value: stats.formattedDuration,
                          label: 'Duration',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 5. BOTTOM PRIMARY ACTION BUTTON: "Nice!"
                  _SummaryPressable(
                    onTap: widget.onHome ?? widget.onRestart,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFA3E635),
                            Color(0xFF84CC16),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA3E635).withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Nice!',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sleek Dark Metric Card (#161822)
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF141722), // Sleek Slate Card (#161822)
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: const Color(0xFFA3E635), // Electric Lime Icon
            size: 26,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _SummaryPressable({
    required this.child,
    required this.onTap,
  });

  @override
  State<_SummaryPressable> createState() => _SummaryPressableState();
}

class _SummaryPressableState extends State<_SummaryPressable> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}
