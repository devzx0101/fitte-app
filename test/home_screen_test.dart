import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitte/models/session_stats.dart';
import 'package:fitte/services/user_prefs_service.dart';
import 'package:fitte/ui/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeScreen renders header, stats, and handles workout card selection', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ExerciseType? selectedExercise;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          initialUserData: const UserData(
            level: 3,
            currentXp: 120,
            targetXp: 350,
            streakDays: 5,
          ),
          onStartWorkout: (type) {
            selectedExercise = type;
          },
        ),
      ),
    );

    // Verify Sections
    expect(find.text('WARM UP'), findsOneWidget);
    expect(find.text('TRAINING'), findsOneWidget);
    expect(find.text('COOL DOWN'), findsOneWidget);

    // Verify Exercises
    expect(find.text('Jumping Jacks'), findsOneWidget);
    expect(find.text('Push-Ups'), findsOneWidget);
    expect(find.text('Abdominal Crunches'), findsOneWidget);

    // Tap Push-Ups card
    await tester.tap(find.text('Push-Ups'));
    expect(selectedExercise, ExerciseType.pushups);

    // Tap Jumping Jacks card
    selectedExercise = null;
    await tester.tap(find.text('Jumping Jacks'));
    expect(selectedExercise, ExerciseType.jumpingJacks);
  });
}
