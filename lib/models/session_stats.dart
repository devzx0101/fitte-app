enum ExerciseType {
  squats,
  jumpingJacks,
  pushups,
  lunges,
  highKnees,
  plank,
  crunches,
  ropeSkipping,
}

extension ExerciseTypeExtension on ExerciseType {
  String get displayName {
    switch (this) {
      case ExerciseType.squats:
        return 'Squats';
      case ExerciseType.jumpingJacks:
        return 'Jumping Jacks';
      case ExerciseType.pushups:
        return 'Pushups';
      case ExerciseType.lunges:
        return 'Lunges';
      case ExerciseType.highKnees:
        return 'High Knees';
      case ExerciseType.plank:
        return 'Plank';
      case ExerciseType.crunches:
        return 'Crunches';
      case ExerciseType.ropeSkipping:
        return 'Rope Skipping';
    }
  }

  String get icon {
    switch (this) {
      case ExerciseType.squats:
        return '🏋️';
      case ExerciseType.jumpingJacks:
        return '⭐';
      case ExerciseType.pushups:
        return '💪';
      case ExerciseType.lunges:
        return '🦵';
      case ExerciseType.highKnees:
        return '🏃';
      case ExerciseType.plank:
        return '🧱';
      case ExerciseType.crunches:
        return '🔥';
      case ExerciseType.ropeSkipping:
        return '⚡';
    }
  }
}

class SessionStats {
  final int reps;
  final int sets;
  final int durationSeconds;
  final int bestCpm;
  final int avgCpm;
  final int xpEarned;
  final int userLevel;
  final int currentXp;
  final int targetXp;
  final ExerciseType exerciseType;
  final int accuracyScore;
  final int caloriesBurned;

  const SessionStats({
    required this.reps,
    required this.sets,
    required this.durationSeconds,
    required this.bestCpm,
    required this.avgCpm,
    required this.xpEarned,
    required this.userLevel,
    required this.currentXp,
    required this.targetXp,
    required this.exerciseType,
    this.accuracyScore = 95,
    this.caloriesBurned = 18,
  });

  String get formattedDuration {
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double get xpProgressRatio {
    if (targetXp <= 0) return 1.0;
    return (currentXp / targetXp).clamp(0.0, 1.0);
  }
}
