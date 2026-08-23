import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/session_stats.dart';
import 'screens/summary_screen.dart';
import 'screens/workout_screen.dart';
import 'services/user_prefs_service.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0E0E10),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const FitteApp());
}

enum AppView {
  home,
  workout,
  summary,
}

class FitteApp extends StatefulWidget {
  const FitteApp({super.key});

  @override
  State<FitteApp> createState() => _FitteAppState();
}

class _FitteAppState extends State<FitteApp> {
  AppView _currentView = AppView.home;
  ExerciseType _selectedExercise = ExerciseType.squats;
  int _userLevel = 1;
  int _currentXp = 78;
  int _targetXp = 150;
  int _streakDays = 1;

  SessionStats _lastSessionStats = const SessionStats(
    reps: 25,
    sets: 1,
    durationSeconds: 74,
    bestCpm: 123,
    avgCpm: 110,
    xpEarned: 51,
    userLevel: 1,
    currentXp: 129,
    targetXp: 150,
    exerciseType: ExerciseType.squats,
    accuracyScore: 96,
    caloriesBurned: 18,
  );

  @override
  void initState() {
    super.initState();
    _loadUserProgress();
  }

  Future<void> _loadUserProgress() async {
    final data = await UserPrefsService.loadUserData();
    if (mounted) {
      setState(() {
        _userLevel = data.level;
        _currentXp = data.currentXp;
        _targetXp = data.targetXp;
        _streakDays = data.streakDays;
      });
    }
  }

  void _handleStartWorkout(ExerciseType exerciseType) {
    setState(() {
      _selectedExercise = exerciseType;
      _currentView = AppView.workout;
    });
  }

  Future<void> _handleFinishWorkout(SessionStats stats) async {
    final updatedData = await UserPrefsService.saveWorkoutStats(
      xpEarned: stats.xpEarned,
    );

    if (mounted) {
      setState(() {
        _userLevel = updatedData.level;
        _currentXp = updatedData.currentXp;
        _targetXp = updatedData.targetXp;
        _streakDays = updatedData.streakDays;
        _lastSessionStats = SessionStats(
          reps: stats.reps,
          sets: stats.sets,
          durationSeconds: stats.durationSeconds,
          bestCpm: stats.bestCpm,
          avgCpm: stats.avgCpm,
          xpEarned: stats.xpEarned,
          userLevel: updatedData.level,
          currentXp: updatedData.currentXp,
          targetXp: updatedData.targetXp,
          exerciseType: stats.exerciseType,
          accuracyScore: stats.accuracyScore,
          caloriesBurned: stats.caloriesBurned,
        );
        _currentView = AppView.summary;
      });
    }
  }

  void _handleRestartWorkout() {
    setState(() {
      _currentView = AppView.workout;
    });
  }

  void _handleGoHome() {
    _loadUserProgress();
    setState(() {
      _currentView = AppView.home;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitte',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E0E10),
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF22C55E),
          surface: Color(0xFF14141A),
        ),
      ),
      home: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentView) {
      case AppView.home:
        return HomeScreen(
          onStartWorkout: _handleStartWorkout,
          initialUserData: UserData(
            level: _userLevel,
            currentXp: _currentXp,
            targetXp: _targetXp,
            streakDays: _streakDays,
          ),
        );
      case AppView.workout:
        return WorkoutScreen(
          initialExercise: _selectedExercise,
          onFinishSession: _handleFinishWorkout,
          onExit: _handleGoHome,
        );
      case AppView.summary:
        return SummaryScreen(
          stats: _lastSessionStats,
          onRestart: _handleRestartWorkout,
          onHome: _handleGoHome,
        );
    }
  }
}

