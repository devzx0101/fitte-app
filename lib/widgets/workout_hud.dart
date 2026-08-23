import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/rep_counter_service.dart';
import 'bubo_widget.dart';

class WorkoutHUD extends StatefulWidget {
  final int reps;
  final int cpm;
  final int sets;
  final String durationText;
  final RepPhase phase;
  final double progress;
  final String feedbackText;
  final VoidCallback onManualRepIncrement;
  final bool isIsometric;
  final int formStreak;
  final String? coachName;

  const WorkoutHUD({
    super.key,
    required this.reps,
    required this.cpm,
    required this.sets,
    required this.durationText,
    required this.phase,
    required this.progress,
    required this.feedbackText,
    required this.onManualRepIncrement,
    this.isIsometric = false,
    this.formStreak = 0,
    this.coachName,
  });

  @override
  State<WorkoutHUD> createState() => _WorkoutHUDState();
}

class _WorkoutHUDState extends State<WorkoutHUD> {
  Color _getIndicatorColor() {
    switch (widget.phase) {
      case RepPhase.bottom:
        return const Color(0xFFA3E635);
      case RepPhase.down:
      case RepPhase.up:
        return const Color(0xFF38BDF8);
      case RepPhase.completed:
        return const Color(0xFF22C55E);
      case RepPhase.idle:
        return const Color(0xFF94A3B8);
    }
  }

  BuboMood _getBuboMood() {
    if (widget.formStreak >= 2) return BuboMood.fireStreak;
    final text = widget.feedbackText.toLowerCase();
    if (text.contains('deeper') ||
        text.contains('straight') ||
        text.contains('adjust') ||
        text.contains('raise') ||
        text.contains('bend') ||
        text.contains('floor')) {
      return BuboMood.warning;
    }
    if (widget.phase == RepPhase.completed) return BuboMood.correct;
    return BuboMood.watching;
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final repText = widget.isIsometric ? '${widget.reps}s' : '${widget.reps}';

    if (isLandscape) {
      // Sleek, compact landscape HUD that doesn't obstruct the wide floor video feed
      return RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.only(left: 32, right: 32, bottom: 12),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24).withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.70),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rolling Reps Counter
                      GestureDetector(
                        onTap: widget.onManualRepIncrement,
                        child: SizedBox(
                          height: 52,
                          child: Center(
                            child: _RollingNumberDisplay(
                              numberString: repText,
                              textStyle: GoogleFonts.outfit(
                                fontSize: widget.isIsometric ? 38 : 46,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 1,
                        height: 38,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      const SizedBox(width: 16),
                      // Feedback + Stats column
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Feedback Pill with Bubo Coach
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BuboWidget(
                                  mood: _getBuboMood(),
                                  role: BuboRole.coach,
                                  size: 18,
                                  isAnimated: false,
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _getIndicatorColor(),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    widget.feedbackText,
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFF1F5F9),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Cadence + Total Stats
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.speed_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.isIsometric
                                      ? '${(widget.progress * 100).round()}%'
                                      : '${widget.cpm} cpm',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFCBD5E1),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Text(
                                  'Σ',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.isIsometric
                                      ? widget.durationText
                                      : '${widget.reps} total',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFCBD5E1),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
        ),
      );
    }

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Combo Multiplier Banner
            if (widget.formStreak >= 2) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEF4444)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF97316).withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '🔥 ${widget.formStreak}x PERFECT FORM COMBO!',
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
            ],

            // Dynamic Feedback Pill with Bubo Coach
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E10).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFF00E0C7).withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BuboWidget(
                    mood: _getBuboMood(),
                    role: BuboRole.coach,
                    size: 24,
                    isAnimated: false,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _getIndicatorColor(),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _getIndicatorColor().withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.feedbackText,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFF1F5F9),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Frosted Glass HUD Container (Glassmorphism)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24).withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.80),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rolling Number Counter (Odometer / Slot Machine Effect)
                      GestureDetector(
                        onTap: widget.onManualRepIncrement,
                        child: SizedBox(
                          height: 76,
                          child: Center(
                            child: _RollingNumberDisplay(
                              numberString: repText,
                              textStyle: GoogleFonts.outfit(
                                fontSize: widget.isIsometric ? 54 : 64,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                                letterSpacing: -1.0,
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Bottom Sub-Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Left: Dial icon + Cadence
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.speed_rounded,
                                color: Color(0xFFCBD5E1),
                                size: 15,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                widget.isIsometric
                                    ? '${(widget.progress * 100).round()}% posture'
                                    : '${widget.cpm} cpm',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFCBD5E1),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 24),

                          // Right: Sigma icon + Total Count
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Σ',
                                style: TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                widget.isIsometric
                                    ? widget.durationText
                                    : '${widget.reps} total',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFCBD5E1),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a row of independent rolling digits with vertical slide & motion blur
class _RollingNumberDisplay extends StatelessWidget {
  final String numberString;
  final TextStyle textStyle;

  const _RollingNumberDisplay({
    required this.numberString,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final chars = numberString.split('');

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < chars.length; i++)
          _RollingDigit(
            key: ValueKey('digit_pos_${chars.length - 1 - i}'),
            char: chars[i],
            textStyle: textStyle,
          ),
      ],
    );
  }
}

/// An individual digit column with smooth rolling transition and subtle vertical motion blur
class _RollingDigit extends StatelessWidget {
  final String char;
  final TextStyle textStyle;

  const _RollingDigit({
    super.key,
    required this.char,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isIncoming = child.key == ValueKey(char);

          final slideAnimation = Tween<Offset>(
            begin: isIncoming ? const Offset(0.0, 1.0) : Offset.zero,
            end: isIncoming ? Offset.zero : const Offset(0.0, -1.0),
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));

          return SlideTransition(
            position: slideAnimation,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, c) {
                // Subtle vertical motion blur during transition
                final blurAmount = (1.0 - animation.value) * 3.5;
                if (blurAmount > 0.4) {
                  return ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 0.0, sigmaY: blurAmount),
                    child: FadeTransition(
                      opacity: animation,
                      child: c,
                    ),
                  );
                }
                return FadeTransition(
                  opacity: animation,
                  child: c,
                );
              },
              child: child,
            ),
          );
        },
        child: Text(
          char,
          key: ValueKey<String>(char),
          style: textStyle,
        ),
      ),
    );
  }
}
