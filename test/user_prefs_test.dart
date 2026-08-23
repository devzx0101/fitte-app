import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitte/services/user_prefs_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserPrefsService & UserData', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Loads default user data when storage is empty', () async {
      final data = await UserPrefsService.loadUserData();
      expect(data.level, 1);
      expect(data.currentXp, 78);
      expect(data.targetXp, 150);
      expect(data.streakDays, 1);
      expect(data.xpProgressRatio, closeTo(78 / 150, 0.01));
    });

    test('Saves workout stats, increments XP, and handles level up milestone', () async {
      // Earn enough XP to trigger level up (78 + 100 = 178 >= 150)
      final updated = await UserPrefsService.saveWorkoutStats(xpEarned: 100);

      expect(updated.level, 2);
      expect(updated.currentXp, 178);
      expect(updated.targetXp, 250); // Level 2 target: 100 * 2 + 50 = 250
    });
  });
}
