import 'package:shared_preferences/shared_preferences.dart';

class UserData {
  final int level;
  final int currentXp;
  final int targetXp;
  final int streakDays;

  const UserData({
    required this.level,
    required this.currentXp,
    required this.targetXp,
    required this.streakDays,
  });

  double get xpProgressRatio {
    if (targetXp <= 0) return 1.0;
    return (currentXp / targetXp).clamp(0.0, 1.0);
  }
}

class UserPrefsService {
  static const String _keyLevel = 'user_level';
  static const String _keyCurrentXp = 'current_xp';
  static const String _keyTargetXp = 'target_xp';
  static const String _keyStreakDays = 'streak_days';
  static const String _keyLastWorkoutDate = 'last_workout_date';

  /// Load current user stats from SharedPreferences
  static Future<UserData> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final level = prefs.getInt(_keyLevel) ?? 1;
    final currentXp = prefs.getInt(_keyCurrentXp) ?? 78;
    final targetXp = prefs.getInt(_keyTargetXp) ?? 150;
    final streakDays = prefs.getInt(_keyStreakDays) ?? 1;

    return UserData(
      level: level,
      currentXp: currentXp,
      targetXp: targetXp,
      streakDays: streakDays,
    );
  }

  /// Update user level, XP, and streak after completing a workout session
  static Future<UserData> saveWorkoutStats({
    required int xpEarned,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    int level = prefs.getInt(_keyLevel) ?? 1;
    int currentXp = prefs.getInt(_keyCurrentXp) ?? 78;
    int targetXp = prefs.getInt(_keyTargetXp) ?? 150;
    int streakDays = prefs.getInt(_keyStreakDays) ?? 1;

    currentXp += xpEarned;

    // Handle level up
    while (currentXp >= targetXp) {
      level += 1;
      targetXp = 100 * level + 50;
    }

    // Update streak based on date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDateStr = prefs.getString(_keyLastWorkoutDate);

    if (lastDateStr != null) {
      final lastDateRaw = DateTime.tryParse(lastDateStr);
      if (lastDateRaw != null) {
        final lastDate = DateTime(lastDateRaw.year, lastDateRaw.month, lastDateRaw.day);
        final diffDays = today.difference(lastDate).inDays;
        if (diffDays == 1) {
          streakDays += 1;
        } else if (diffDays > 1) {
          streakDays = 1;
        }
      }
    } else {
      streakDays = 1;
    }

    await prefs.setInt(_keyLevel, level);
    await prefs.setInt(_keyCurrentXp, currentXp);
    await prefs.setInt(_keyTargetXp, targetXp);
    await prefs.setInt(_keyStreakDays, streakDays);
    await prefs.setString(_keyLastWorkoutDate, today.toIso8601String());

    return UserData(
      level: level,
      currentXp: currentXp,
      targetXp: targetXp,
      streakDays: streakDays,
    );
  }
}
