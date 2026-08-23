import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/session_stats.dart';
import '../../services/user_prefs_service.dart';
import '../../widgets/animated_exercise_mascot.dart';
import '../../widgets/bubo_widget.dart';

class RoutinePlan {
  final String id;
  final String title;
  final String durationText;
  final String difficulty;
  final String introText;
  final List<ExerciseRoutineItem> warmUp;
  final List<ExerciseRoutineItem> training;
  final List<ExerciseRoutineItem> coolDown;

  const RoutinePlan({
    required this.id,
    required this.title,
    required this.durationText,
    required this.difficulty,
    required this.introText,
    required this.warmUp,
    required this.training,
    required this.coolDown,
  });

  int get totalExercises => warmUp.length + training.length + coolDown.length;
}

class ExerciseRoutineItem {
  final ExerciseType exerciseType;
  final String title;
  final String targetText;
  final String category;

  const ExerciseRoutineItem({
    required this.exerciseType,
    required this.title,
    required this.targetText,
    required this.category,
  });
}

class HomeScreen extends StatefulWidget {
  final Function(ExerciseType exerciseType) onStartWorkout;
  final UserData? initialUserData;

  const HomeScreen({
    super.key,
    required this.onStartWorkout,
    this.initialUserData,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _streakDays = 1;
  final int _selectedRoutineIndex = 0;

  final List<RoutinePlan> _routines = const [
    RoutinePlan(
      id: 'day_1',
      title: 'DAY 1: FULL BODY',
      durationText: '8 MINS',
      difficulty: 'BEGINNER',
      introText:
          'High-precision neural body tracking with real-time biomechanics feedback. Zero equipment needed.',
      warmUp: [
        ExerciseRoutineItem(
          exerciseType: ExerciseType.jumpingJacks,
          title: 'Jumping Jacks',
          targetText: '00:30',
          category: 'Warm Up',
        ),
        ExerciseRoutineItem(
          exerciseType: ExerciseType.highKnees,
          title: 'High Knees',
          targetText: '00:30',
          category: 'Warm Up',
        ),
      ],
      training: [
        ExerciseRoutineItem(
          exerciseType: ExerciseType.pushups,
          title: 'Push-Ups',
          targetText: '15 REPS',
          category: 'Training',
        ),
        ExerciseRoutineItem(
          exerciseType: ExerciseType.crunches,
          title: 'Abdominal Crunches',
          targetText: '20 REPS',
          category: 'Training',
        ),
        ExerciseRoutineItem(
          exerciseType: ExerciseType.squats,
          title: 'Bodyweight Squats',
          targetText: '15 REPS',
          category: 'Training',
        ),
        ExerciseRoutineItem(
          exerciseType: ExerciseType.lunges,
          title: 'Split Lunges',
          targetText: '12 REPS',
          category: 'Training',
        ),
      ],
      coolDown: [
        ExerciseRoutineItem(
          exerciseType: ExerciseType.plank,
          title: 'Core Plank Hold',
          targetText: '00:45',
          category: 'Cool Down',
        ),
      ],
    ),
    RoutinePlan(
      id: 'leg_workout',
      title: '7 MIN LEG & CORE',
      durationText: '7 MINS',
      difficulty: 'INTERMEDIATE',
      introText:
          'Explosive lower body strength & stability. Real-time knee angle verification and core alignment.',
      warmUp: [
        ExerciseRoutineItem(
          exerciseType: ExerciseType.highKnees,
          title: 'High Knees',
          targetText: '00:30',
          category: 'Warm Up',
        ),
      ],
      training: [
        ExerciseRoutineItem(
          exerciseType: ExerciseType.squats,
          title: 'Deep Squats',
          targetText: '20 REPS',
          category: 'Training',
        ),
        ExerciseRoutineItem(
          exerciseType: ExerciseType.lunges,
          title: 'Alternating Lunges',
          targetText: '16 REPS',
          category: 'Training',
        ),
        ExerciseRoutineItem(
          exerciseType: ExerciseType.crunches,
          title: 'Floor Crunches',
          targetText: '25 REPS',
          category: 'Training',
        ),
      ],
      coolDown: [
        ExerciseRoutineItem(
          exerciseType: ExerciseType.plank,
          title: 'Plank Finisher',
          targetText: '01:00',
          category: 'Cool Down',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialUserData != null) {
      _applyUserData(widget.initialUserData!);
    }
    _loadUserProgress();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUserData != null &&
        widget.initialUserData != oldWidget.initialUserData) {
      _applyUserData(widget.initialUserData!);
    } else {
      _loadUserProgress();
    }
  }

  void _applyUserData(UserData data) {
    setState(() {
      _streakDays = data.streakDays;
    });
  }

  Future<void> _loadUserProgress() async {
    final userData = await UserPrefsService.loadUserData();
    if (mounted) {
      setState(() {
        _streakDays = userData.streakDays;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeRoutine = _routines[_selectedRoutineIndex];
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Clean Porcelain White Base
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Hero Mascot Header (Seamless Porcelain White)
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: const Color(0xFFFFFFFF),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
              onPressed: () {},
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroAthleteBanner(
                routineTitle: activeRoutine.title,
                streakDays: _streakDays,
              ),
            ),
          ),

          // 2. Clean White Porcelain Routine Sheet
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF), // Pure White Sheet
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section: Warm Up
                  if (activeRoutine.warmUp.isNotEmpty) ...[
                    _buildSectionHeader('WARM UP'),
                    ...activeRoutine.warmUp.map((item) => _buildExerciseRow(item)),
                    const SizedBox(height: 16),
                  ],

                  // Section: Training
                  if (activeRoutine.training.isNotEmpty) ...[
                    _buildSectionHeader('TRAINING'),
                    ...activeRoutine.training.map((item) => _buildExerciseRow(item)),
                    const SizedBox(height: 16),
                  ],

                  // Section: Cool Down
                  if (activeRoutine.coolDown.isNotEmpty) ...[
                    _buildSectionHeader('COOL DOWN'),
                    ...activeRoutine.coolDown.map((item) => _buildExerciseRow(item)),
                  ],

                  SizedBox(height: bottomPadding + 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: const Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildExerciseRow(ExerciseRoutineItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _PressableScale(
        onTap: () => widget.onStartWorkout(item.exerciseType),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Reorder / Drag Handle Icon
              const Icon(
                Icons.drag_indicator_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
              const SizedBox(width: 10),

              // Animated Mascot Box
              AnimatedExerciseMascot(
                exerciseType: item.exerciseType,
                size: 58,
                backgroundColor: const Color(0xFFF1F5F9),
              ),
              const SizedBox(width: 14),

              // Title and Target Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          item.targetText,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF16A34A),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Color(0xFFCBD5E1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI Camera',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Launch/Play Icon
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFF16A34A),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive Touch Scale Micro-Animation
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableScale({
    required this.child,
    required this.onTap,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
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

/// High-End Hero Athlete Banner with Duolingo-style Duo layout
class _HeroAthleteBanner extends StatelessWidget {
  final String routineTitle;
  final int streakDays;

  const _HeroAthleteBanner({
    required this.routineTitle,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFFFFF), // Seamless Porcelain White Base
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 36, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Grounded BUBO with internal blinking & micro-motions
              BuboWidget(
                mood: BuboMood.happy,
                role: BuboRole.companion,
                size: 115,
                isAnimated: true,
              ),
              SizedBox(width: 8),

              // Right: Duolingo-style speech bubble with pointed tail
              Flexible(
                child: DuolingoSpeechBubble(
                  text: "Pick an exercise and let's get stronger!",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
