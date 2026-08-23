import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitte/main.dart';
import 'package:fitte/widgets/workout_hud.dart';
import 'package:fitte/services/rep_counter_service.dart';

void main() {
  testWidgets('Fitte smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FitteApp());
    expect(find.byType(FitteApp), findsOneWidget);
  });

  testWidgets('WorkoutHUD renders properly in portrait and landscape', (WidgetTester tester) async {
    // 1. Portrait Test (width: 400, height: 800)
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutHUD(
            reps: 12,
            cpm: 24,
            sets: 1,
            durationText: '00:35',
            phase: RepPhase.bottom,
            progress: 0.85,
            feedbackText: 'Peak crunch! Squeeze upper abs!',
            onManualRepIncrement: () {},
          ),
        ),
      ),
    );

    expect(find.byType(WorkoutHUD), findsOneWidget);
    expect(find.text('Peak crunch! Squeeze upper abs!'), findsOneWidget);

    // 2. Landscape Test (width: 800, height: 400)
    tester.view.physicalSize = const Size(800, 400);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutHUD(
            reps: 12,
            cpm: 24,
            sets: 1,
            durationText: '00:35',
            phase: RepPhase.bottom,
            progress: 0.85,
            feedbackText: 'Peak crunch! Squeeze upper abs!',
            onManualRepIncrement: () {},
          ),
        ),
      ),
    );

    expect(find.byType(WorkoutHUD), findsOneWidget);
    expect(find.text('Peak crunch! Squeeze upper abs!'), findsOneWidget);
  });
}
