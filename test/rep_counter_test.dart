import 'package:flutter_test/flutter_test.dart';
import 'package:fitte/models/pose_model.dart';
import 'package:fitte/models/session_stats.dart';
import 'package:fitte/services/rep_counter_service.dart';

void main() {
  group('RepCounterService - Squats', () {
    late RepCounterService repCounter;

    setUp(() {
      repCounter = RepCounterService(
        exerciseType: ExerciseType.squats,
        enableAudio: false,
      );
    });

    test('Full deep squat rep increases rep count', () {
      // 1. Standing Pose (Knee Angle ~ 170°)
      final standingPose = PoseData(
        timestamp: 100,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.4, y: 0.2, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.6, y: 0.2, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.42, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.58, y: 0.45, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.42, y: 0.65, score: 0.9),
          KeypointData(type: JointType.rightKnee, x: 0.58, y: 0.65, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.42, y: 0.85, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.58, y: 0.85, score: 0.9),
        ],
      );

      var result = repCounter.processPose(standingPose);
      expect(result.reps, 0);
      expect(result.phase, RepPhase.idle);

      // 2. Descending into Squat (Knees bend outward/forward, angle drops to ~110°)
      final deepSquatPose = PoseData(
        timestamp: 500,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.4, y: 0.35, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.6, y: 0.35, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.40, y: 0.62, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.60, y: 0.62, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.32, y: 0.64, score: 0.9),
          KeypointData(type: JointType.rightKnee, x: 0.68, y: 0.64, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.40, y: 0.85, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.60, y: 0.85, score: 0.9),
        ],
      );

      result = repCounter.processPose(deepSquatPose);
      expect(result.phase, RepPhase.bottom);
      expect(result.formQuality, 'perfect');

      // 3. Returning to Standing Pose
      final standingAgainPose = PoseData(
        timestamp: 1200,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.4, y: 0.2, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.6, y: 0.2, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.42, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.58, y: 0.45, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.42, y: 0.65, score: 0.9),
          KeypointData(type: JointType.rightKnee, x: 0.58, y: 0.65, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.42, y: 0.85, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.58, y: 0.85, score: 0.9),
        ],
      );

      result = repCounter.processPose(standingAgainPose);
      expect(result.reps, 1);
      expect(repCounter.reps, 1);
    });

    test('Bending forward with straight knees is rejected as a false squat', () {
      // User bends shoulders/chest forward while knees remain straight
      final bendingPose = PoseData(
        timestamp: 300,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.4, y: 0.40, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.6, y: 0.40, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.42, y: 0.48, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.58, y: 0.48, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.42, y: 0.66, score: 0.9),
          KeypointData(type: JointType.rightKnee, x: 0.58, y: 0.66, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.42, y: 0.85, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.58, y: 0.85, score: 0.9),
        ],
      );

      final result = repCounter.processPose(bendingPose);
      expect(result.reps, 0);
      expect(result.formQuality, 'adjust');
    });

    test('Slight knee bend is not counted as a squat rep', () {
      // 1. Standing
      final standingPose = PoseData(
        timestamp: 100,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.4, y: 0.2, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.6, y: 0.2, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.42, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.58, y: 0.45, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.42, y: 0.65, score: 0.9),
          KeypointData(type: JointType.rightKnee, x: 0.58, y: 0.65, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.42, y: 0.85, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.58, y: 0.85, score: 0.9),
        ],
      );
      repCounter.processPose(standingPose);

      // 2. Slight knee bend (~145° knee angle)
      final slightBendPose = PoseData(
        timestamp: 400,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.4, y: 0.23, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.6, y: 0.23, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.42, y: 0.48, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.58, y: 0.48, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.40, y: 0.65, score: 0.9),
          KeypointData(type: JointType.rightKnee, x: 0.60, y: 0.65, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.42, y: 0.85, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.58, y: 0.85, score: 0.9),
        ],
      );
      var result = repCounter.processPose(slightBendPose);
      expect(result.phase, isNot(RepPhase.bottom));

      // 3. Return to standing without having reached bottom depth
      result = repCounter.processPose(standingPose);
      expect(result.reps, 0);
      expect(repCounter.reps, 0);
    });

    test('Single leg lift / kick / stretch is rejected and prompts to plant both feet', () {
      // User stands on right leg and lifts left leg up in the air (y: 0.50 vs 0.85)
      final legLiftPose = PoseData(
        timestamp: 400,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.4, y: 0.2, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.6, y: 0.2, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.42, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.58, y: 0.45, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.35, y: 0.42, score: 0.9),
          KeypointData(type: JointType.rightKnee, x: 0.58, y: 0.65, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.25, y: 0.40, score: 0.9), // Lifted high
          KeypointData(type: JointType.rightAnkle, x: 0.58, y: 0.85, score: 0.9), // Standing on floor
        ],
      );

      final result = repCounter.processPose(legLiftPose);
      expect(result.reps, 0);
      expect(result.formQuality, 'adjust');
      expect(result.feedback, 'Plant both feet firmly on the floor!');
    });

    test('Asymmetric one-knee bend is rejected as not a squat', () {
      // One knee bends sharply while other leg remains straight
      final asymmetricPose = PoseData(
        timestamp: 400,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.4, y: 0.2, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.6, y: 0.2, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.42, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.58, y: 0.45, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.32, y: 0.64, score: 0.9), // Bent
          KeypointData(type: JointType.rightKnee, x: 0.58, y: 0.65, score: 0.9), // Straight
          KeypointData(type: JointType.leftAnkle, x: 0.42, y: 0.85, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.58, y: 0.85, score: 0.9),
        ],
      );

      final result = repCounter.processPose(asymmetricPose);
      expect(result.reps, 0);
      expect(result.formQuality, 'adjust');
      expect(result.feedback, 'Bend both knees together symmetrically!');
    });
  });

  group('RepCounterService - Jumping Jacks', () {
    late RepCounterService repCounter;

    setUp(() {
      repCounter = RepCounterService(
        exerciseType: ExerciseType.jumpingJacks,
        enableAudio: false,
      );
    });

    test('Valid jumping jack counts rep with arms overhead and feet apart', () {
      // 1. Starting Pose (Hands at sides, feet together)
      final startPose = PoseData(
        timestamp: 100,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.4, y: 0.25, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.6, y: 0.25, score: 0.9),
          KeypointData(type: JointType.leftWrist, x: 0.35, y: 0.55, score: 0.9),
          KeypointData(type: JointType.rightWrist, x: 0.65, y: 0.55, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.43, y: 0.50, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.57, y: 0.50, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.45, y: 0.85, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.55, y: 0.85, score: 0.9),
        ],
      );

      var result = repCounter.processPose(startPose);
      expect(result.reps, 0);

      // 2. Full Extension (Hands overhead: y < shoulder.y, feet spread wide)
      final openPose = PoseData(
        timestamp: 500,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.4, y: 0.25, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.6, y: 0.25, score: 0.9),
          KeypointData(type: JointType.leftWrist, x: 0.25, y: 0.08, score: 0.9),
          KeypointData(type: JointType.rightWrist, x: 0.75, y: 0.08, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.43, y: 0.50, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.57, y: 0.50, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.25, y: 0.85, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.75, y: 0.85, score: 0.9),
        ],
      );

      result = repCounter.processPose(openPose);
      expect(result.phase, RepPhase.bottom);

      // 3. Return to start position
      final returnPose = PoseData(
        timestamp: 1100,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.4, y: 0.25, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.6, y: 0.25, score: 0.9),
          KeypointData(type: JointType.leftWrist, x: 0.35, y: 0.55, score: 0.9),
          KeypointData(type: JointType.rightWrist, x: 0.65, y: 0.55, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.43, y: 0.50, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.57, y: 0.50, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.45, y: 0.85, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.55, y: 0.85, score: 0.9),
        ],
      );

      result = repCounter.processPose(returnPose);
      expect(result.reps, 1);
    });

    test('Waving hands sideways without lifting overhead prompts adjustment', () {
      final sideWavePose = PoseData(
        timestamp: 300,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.4, y: 0.25, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.6, y: 0.25, score: 0.9),
          KeypointData(type: JointType.leftWrist, x: 0.15, y: 0.35, score: 0.9),
          KeypointData(type: JointType.rightWrist, x: 0.85, y: 0.35, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.43, y: 0.50, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.57, y: 0.50, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.45, y: 0.85, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.55, y: 0.85, score: 0.9),
        ],
      );

      final result = repCounter.processPose(sideWavePose);
      expect(result.formQuality, 'adjust');
      expect(result.reps, 0);
    });
  });

  group('RepCounterService - Pushups', () {
    late RepCounterService repCounter;

    setUp(() {
      repCounter = RepCounterService(
        exerciseType: ExerciseType.pushups,
        enableAudio: false,
      );
    });

    test('Full pushup rep from lockout to chest down and back to lockout', () {
      // 1. Top Plank / Lockout Position (Elbows ~ 170°)
      final lockoutPose = PoseData(
        timestamp: 100,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.35, y: 0.35, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.65, y: 0.35, score: 0.9),
          KeypointData(type: JointType.leftElbow, x: 0.35, y: 0.50, score: 0.9),
          KeypointData(type: JointType.rightElbow, x: 0.65, y: 0.50, score: 0.9),
          KeypointData(type: JointType.leftWrist, x: 0.35, y: 0.65, score: 0.9),
          KeypointData(type: JointType.rightWrist, x: 0.65, y: 0.65, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.38, y: 0.40, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.62, y: 0.40, score: 0.9),
        ],
      );
      var result = repCounter.processPose(lockoutPose);
      expect(result.reps, 0);

      // 2. Chest Down to Floor (Elbows flexed to ~85°)
      final downPose = PoseData(
        timestamp: 500,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.35, y: 0.55, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.65, y: 0.55, score: 0.9),
          KeypointData(type: JointType.leftElbow, x: 0.22, y: 0.55, score: 0.9),
          KeypointData(type: JointType.rightElbow, x: 0.78, y: 0.55, score: 0.9),
          KeypointData(type: JointType.leftWrist, x: 0.35, y: 0.65, score: 0.9),
          KeypointData(type: JointType.rightWrist, x: 0.65, y: 0.65, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.38, y: 0.58, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.62, y: 0.58, score: 0.9),
        ],
      );
      result = repCounter.processPose(downPose);
      expect(result.phase, RepPhase.bottom);

      // 3. Pressing back to Lockout
      final backUpPose = PoseData(
        timestamp: 1500,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.35, y: 0.35, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.65, y: 0.35, score: 0.9),
          KeypointData(type: JointType.leftElbow, x: 0.35, y: 0.50, score: 0.9),
          KeypointData(type: JointType.rightElbow, x: 0.65, y: 0.50, score: 0.9),
          KeypointData(type: JointType.leftWrist, x: 0.35, y: 0.65, score: 0.9),
          KeypointData(type: JointType.rightWrist, x: 0.65, y: 0.65, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.38, y: 0.40, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.62, y: 0.40, score: 0.9),
        ],
      );
      result = repCounter.processPose(backUpPose);
      expect(result.reps, 1);
    });

    test('Asymmetric one-arm bend is rejected as an invalid pushup', () {
      final asymmetricPose = PoseData(
        timestamp: 400,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.35, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.65, y: 0.35, score: 0.9),
          KeypointData(type: JointType.leftElbow, x: 0.22, y: 0.45, score: 0.9), // Deep bend (85°)
          KeypointData(type: JointType.rightElbow, x: 0.65, y: 0.50, score: 0.9), // Straight (170°)
          KeypointData(type: JointType.leftWrist, x: 0.35, y: 0.65, score: 0.9),
          KeypointData(type: JointType.rightWrist, x: 0.65, y: 0.65, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.38, y: 0.40, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.62, y: 0.40, score: 0.9),
        ],
      );
      final result = repCounter.processPose(asymmetricPose);
      expect(result.formQuality, 'adjust');
      expect(result.feedback, contains('both arms'));
      expect(result.reps, 0);
    });

    test('Standing upright is rejected in pushup mode with get down feedback', () {
      final standingInPushupMode = PoseData(
        timestamp: 100,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.40, y: 0.20, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.60, y: 0.20, score: 0.9),
          KeypointData(type: JointType.leftElbow, x: 0.40, y: 0.35, score: 0.9),
          KeypointData(type: JointType.rightElbow, x: 0.60, y: 0.35, score: 0.9),
          KeypointData(type: JointType.leftWrist, x: 0.40, y: 0.50, score: 0.9),
          KeypointData(type: JointType.rightWrist, x: 0.60, y: 0.50, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.42, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.58, y: 0.45, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.42, y: 0.85, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.58, y: 0.85, score: 0.9),
        ],
      );

      final result = repCounter.processPose(standingInPushupMode);
      expect(result.reps, 0);
      expect(result.feedback, contains('pushup position'));
      expect(result.phase, RepPhase.idle);
    });

    test('Empty room or background noise without valid human presence is rejected', () {
      final noisyBackgroundPose = PoseData(
        timestamp: 100,
        score: 0.20,
        keypoints: const [
          KeypointData(type: JointType.nose, x: 0.50, y: 0.10, score: 0.2),
          KeypointData(type: JointType.leftElbow, x: 0.55, y: 0.12, score: 0.15),
        ],
      );

      final result = repCounter.processPose(noisyBackgroundPose);
      expect(result.reps, 0);
      expect(result.feedback, contains('Position yourself'));
      expect(result.phase, RepPhase.idle);
    });
  });

  group('RepCounterService - Lunges', () {
    late RepCounterService repCounter;

    setUp(() {
      repCounter = RepCounterService(
        exerciseType: ExerciseType.lunges,
        enableAudio: false,
      );
    });

    test('Full lunge cycle increments rep', () {
      // 1. Standing Upright
      final standingPose = PoseData(
        timestamp: 100,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftHip, x: 0.45, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.55, y: 0.45, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.45, y: 0.65, score: 0.9),
          KeypointData(type: JointType.rightKnee, x: 0.55, y: 0.65, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.45, y: 0.85, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.55, y: 0.85, score: 0.9),
        ],
      );
      var result = repCounter.processPose(standingPose);
      expect(result.reps, 0);

      // 2. Deep Lunge (Front knee at ~90°, rear knee bent & dropped)
      final deepLungePose = PoseData(
        timestamp: 500,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftHip, x: 0.45, y: 0.60, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.55, y: 0.60, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.35, y: 0.60, score: 0.9),
          KeypointData(type: JointType.rightKnee, x: 0.65, y: 0.70, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.35, y: 0.85, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.55, y: 0.85, score: 0.9),
        ],
      );
      result = repCounter.processPose(deepLungePose);
      expect(result.phase, RepPhase.bottom);

      // 3. Stand back up
      result = repCounter.processPose(standingPose);
      expect(result.reps, 1);
    });

    test('Bending one knee without split stance is rejected as invalid lunge', () {
      final narrowStanceBendPose = PoseData(
        timestamp: 300,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftHip, x: 0.45, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.55, y: 0.45, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.35, y: 0.55, score: 0.9), // Bent (110°)
          KeypointData(type: JointType.rightKnee, x: 0.55, y: 0.65, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.48, y: 0.85, score: 0.9), // Feet close together (<0.05)
          KeypointData(type: JointType.rightAnkle, x: 0.52, y: 0.85, score: 0.9),
        ],
      );

      final result = repCounter.processPose(narrowStanceBendPose);
      expect(result.formQuality, 'adjust');
      expect(result.feedback, contains('split stance'));
      expect(result.reps, 0);
    });
  });

  group('RepCounterService - High Knees', () {
    late RepCounterService repCounter;

    setUp(() {
      repCounter = RepCounterService(
        exerciseType: ExerciseType.highKnees,
        enableAudio: false,
      );
    });

    test('High knee elevation increments rep on cadence', () {
      final basePose = PoseData(
        timestamp: 100,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftHip, x: 0.45, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.55, y: 0.45, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.45, y: 0.65, score: 0.9),
          KeypointData(type: JointType.rightKnee, x: 0.55, y: 0.65, score: 0.9),
        ],
      );
      var result = repCounter.processPose(basePose);
      expect(result.reps, 0);

      // Left knee lifted up to hip level
      final kneeUpPose = PoseData(
        timestamp: 300,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftHip, x: 0.45, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.55, y: 0.45, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.45, y: 0.42, score: 0.9), // Above hip line
          KeypointData(type: JointType.rightKnee, x: 0.55, y: 0.65, score: 0.9),
        ],
      );
      result = repCounter.processPose(kneeUpPose);
      expect(result.phase, RepPhase.bottom);

      // Foot back down
      final kneeDownPose = PoseData(
        timestamp: 700,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftHip, x: 0.45, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.55, y: 0.45, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.45, y: 0.65, score: 0.9),
          KeypointData(type: JointType.rightKnee, x: 0.55, y: 0.65, score: 0.9),
        ],
      );
      result = repCounter.processPose(kneeDownPose);
      expect(result.reps, 1);
    });
  });

  group('RepCounterService - Plank', () {
    test('Plank checks spine straightness and detects sagging hips', () {
      final repCounter = RepCounterService(
        exerciseType: ExerciseType.plank,
        enableAudio: false,
      );

      // Straight plank line (Shoulder: 0.3, 0.4 -> Hip: 0.5, 0.45 -> Ankle: 0.8, 0.5)
      final straightPlank = PoseData(
        timestamp: 100,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.3, y: 0.40, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.3, y: 0.40, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.5, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.5, y: 0.45, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.8, y: 0.50, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.8, y: 0.50, score: 0.9),
        ],
      );
      final result = repCounter.processPose(straightPlank);
      expect(result.formQuality, 'perfect');
      expect(result.feedback, contains('Solid plank'));

      // Ticking seconds while holding perfect form counts hold duration
      repCounter.tickSecond();
      repCounter.tickSecond();
      expect(repCounter.reps, 2);
      expect(repCounter.isIsometric, true);
    });
  });

  group('RepCounterService - Crunches', () {
    test('Crunch curls shoulders toward knees and counts rep', () {
      final repCounter = RepCounterService(
        exerciseType: ExerciseType.crunches,
        enableAudio: false,
      );

      // Flat on back (open angle ~150°)
      final flatPose = PoseData(
        timestamp: 100,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.3, y: 0.60, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.3, y: 0.60, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.5, y: 0.60, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.5, y: 0.60, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.65, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightKnee, x: 0.65, y: 0.45, score: 0.9),
        ],
      );
      var result = repCounter.processPose(flatPose);
      expect(result.reps, 0);

      // Curled up crunch (Shoulders lift towards knees, angle contracts <= 95°)
      final crunchCurledPose = PoseData(
        timestamp: 500,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.42, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.42, y: 0.45, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.50, y: 0.60, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.50, y: 0.60, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.65, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightKnee, x: 0.65, y: 0.45, score: 0.9),
        ],
      );
      result = repCounter.processPose(crunchCurledPose);
      expect(result.phase, RepPhase.bottom);

      // Return flat on back
      final flatAgainPose = PoseData(
        timestamp: 1500,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.3, y: 0.60, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.3, y: 0.60, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.5, y: 0.60, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.5, y: 0.60, score: 0.9),
          KeypointData(type: JointType.leftKnee, x: 0.65, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightKnee, x: 0.65, y: 0.45, score: 0.9),
        ],
      );
      result = repCounter.processPose(flatAgainPose);
      expect(result.reps, 1);
    });

    test('Horizontal side-view floor crunches count rep with only one side visible', () {
      final repCounter = RepCounterService(
        exerciseType: ExerciseType.crunches,
        enableAudio: false,
      );

      // Flat on back horizontally (Only left side visible to camera)
      final sideFlatPose = PoseData(
        timestamp: 100,
        score: 0.90,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.20, y: 0.70, score: 0.88),
          KeypointData(type: JointType.leftHip, x: 0.45, y: 0.70, score: 0.88),
          KeypointData(type: JointType.leftKnee, x: 0.60, y: 0.55, score: 0.88),
        ],
      );
      var result = repCounter.processPose(sideFlatPose);
      expect(result.reps, 0);

      // Halfway curl up horizontally
      final sideCurledPose = PoseData(
        timestamp: 500,
        score: 0.90,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.35, y: 0.55, score: 0.88),
          KeypointData(type: JointType.leftHip, x: 0.45, y: 0.70, score: 0.88),
          KeypointData(type: JointType.leftKnee, x: 0.60, y: 0.55, score: 0.88),
        ],
      );
      result = repCounter.processPose(sideCurledPose);
      expect(result.phase, RepPhase.bottom);

      // Lower back to flat
      final sideFlatAgainPose = PoseData(
        timestamp: 1500,
        score: 0.90,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.20, y: 0.70, score: 0.88),
          KeypointData(type: JointType.leftHip, x: 0.45, y: 0.70, score: 0.88),
          KeypointData(type: JointType.leftKnee, x: 0.60, y: 0.55, score: 0.88),
        ],
      );
      result = repCounter.processPose(sideFlatAgainPose);
      expect(result.reps, 1);
    });

    test('Half-body floor crunches count rep when knees are cut off or not framed', () {
      final repCounter = RepCounterService(
        exerciseType: ExerciseType.crunches,
        enableAudio: false,
      );

      // Flat on back with only torso framed (shoulder, ear & hip, no knees)
      final halfBodyFlatPose = PoseData(
        timestamp: 100,
        score: 0.90,
        keypoints: const [
          KeypointData(type: JointType.leftEar, x: 0.15, y: 0.65, score: 0.88),
          KeypointData(type: JointType.leftShoulder, x: 0.20, y: 0.70, score: 0.88),
          KeypointData(type: JointType.leftHip, x: 0.50, y: 0.70, score: 0.88),
        ],
      );
      var result = repCounter.processPose(halfBodyFlatPose);
      expect(result.reps, 0);

      // Curl upper body up
      final halfBodyCurledPose = PoseData(
        timestamp: 600,
        score: 0.90,
        keypoints: const [
          KeypointData(type: JointType.leftEar, x: 0.32, y: 0.48, score: 0.88),
          KeypointData(type: JointType.leftShoulder, x: 0.38, y: 0.52, score: 0.88),
          KeypointData(type: JointType.leftHip, x: 0.50, y: 0.70, score: 0.88),
        ],
      );
      result = repCounter.processPose(halfBodyCurledPose);
      expect(result.phase, RepPhase.bottom);

      // Lower back to flat
      final halfBodyFlatAgainPose = PoseData(
        timestamp: 1700,
        score: 0.90,
        keypoints: const [
          KeypointData(type: JointType.leftEar, x: 0.15, y: 0.65, score: 0.88),
          KeypointData(type: JointType.leftShoulder, x: 0.20, y: 0.70, score: 0.88),
          KeypointData(type: JointType.leftHip, x: 0.50, y: 0.70, score: 0.88),
        ],
      );
      result = repCounter.processPose(halfBodyFlatAgainPose);
      expect(result.reps, 1);
    });

    test('Fast keypoint noise from hand or leg twitches does not trigger rapid rep counts within cooldown', () {
      final repCounter = RepCounterService(
        exerciseType: ExerciseType.crunches,
        enableAudio: false,
      );

      final baseFlatPose = PoseData(
        timestamp: 100,
        score: 0.90,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.20, y: 0.70, score: 0.88),
          KeypointData(type: JointType.leftHip, x: 0.45, y: 0.70, score: 0.88),
          KeypointData(type: JointType.leftKnee, x: 0.60, y: 0.55, score: 0.88),
        ],
      );
      repCounter.processPose(baseFlatPose);

      // Rapid twitch 1 (t = 200ms, too fast / jitter)
      final twitchPose = PoseData(
        timestamp: 200,
        score: 0.90,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.35, y: 0.55, score: 0.88),
          KeypointData(type: JointType.leftHip, x: 0.45, y: 0.70, score: 0.88),
          KeypointData(type: JointType.leftKnee, x: 0.60, y: 0.55, score: 0.88),
        ],
      );
      repCounter.processPose(twitchPose);

      // Rapid return 1 (t = 300ms, well within 1000ms cooldown)
      var result = repCounter.processPose(baseFlatPose);
      expect(result.reps, 0); // Must NOT count rep because cooldown (1000ms) has not elapsed
    });

    test('Hands-behind-head floor crunches track torso elevation and count rep', () {
      final repCounter = RepCounterService(
        exerciseType: ExerciseType.crunches,
        enableAudio: false,
      );

      // 1. Flat on back with hands behind head (shoulders level with hips on floor)
      final handsBehindHeadFlatPose = PoseData(
        timestamp: 100,
        score: 0.92,
        keypoints: const [
          KeypointData(type: JointType.leftEar, x: 0.20, y: 0.70, score: 0.90),
          KeypointData(type: JointType.leftWrist, x: 0.22, y: 0.68, score: 0.90),
          KeypointData(type: JointType.leftElbow, x: 0.25, y: 0.65, score: 0.90),
          KeypointData(type: JointType.leftShoulder, x: 0.28, y: 0.70, score: 0.90),
          KeypointData(type: JointType.leftHip, x: 0.52, y: 0.70, score: 0.90),
          KeypointData(type: JointType.leftKnee, x: 0.68, y: 0.55, score: 0.90),
        ],
      );
      var result = repCounter.processPose(handsBehindHeadFlatPose);
      expect(result.reps, 0);

      // 2. Curled up: Shoulders and elbows lift off the floor towards knees (elevation increases)
      final handsBehindHeadCurledPose = PoseData(
        timestamp: 600,
        score: 0.92,
        keypoints: const [
          KeypointData(type: JointType.leftEar, x: 0.32, y: 0.48, score: 0.90),
          KeypointData(type: JointType.leftWrist, x: 0.33, y: 0.47, score: 0.90),
          KeypointData(type: JointType.leftElbow, x: 0.38, y: 0.42, score: 0.90),
          KeypointData(type: JointType.leftShoulder, x: 0.40, y: 0.50, score: 0.90),
          KeypointData(type: JointType.leftHip, x: 0.52, y: 0.70, score: 0.90),
          KeypointData(type: JointType.leftKnee, x: 0.68, y: 0.55, score: 0.90),
        ],
      );
      result = repCounter.processPose(handsBehindHeadCurledPose);
      expect(result.phase, RepPhase.bottom);

      // 3. Torso lowers smoothly back flat on floor
      final handsBehindHeadFlatAgainPose = PoseData(
        timestamp: 1700,
        score: 0.92,
        keypoints: const [
          KeypointData(type: JointType.leftEar, x: 0.20, y: 0.70, score: 0.90),
          KeypointData(type: JointType.leftWrist, x: 0.22, y: 0.68, score: 0.90),
          KeypointData(type: JointType.leftElbow, x: 0.25, y: 0.65, score: 0.90),
          KeypointData(type: JointType.leftShoulder, x: 0.28, y: 0.70, score: 0.90),
          KeypointData(type: JointType.leftHip, x: 0.52, y: 0.70, score: 0.90),
          KeypointData(type: JointType.leftKnee, x: 0.68, y: 0.55, score: 0.90),
        ],
      );
      result = repCounter.processPose(handsBehindHeadFlatAgainPose);
      expect(result.reps, 1);
    });
  });

  group('RepCounterService - Rope Skipping', () {
    late RepCounterService repCounter;

    setUp(() {
      repCounter = RepCounterService(
        exerciseType: ExerciseType.ropeSkipping,
        enableAudio: false,
      );
    });

    test('Vertical hop and landing increments rope skip count', () {
      // Standing on floor
      final standingPose = PoseData(
        timestamp: 100,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.45, y: 0.25, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.55, y: 0.25, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.46, y: 0.50, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.54, y: 0.50, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.47, y: 0.88, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.53, y: 0.88, score: 0.9),
        ],
      );
      var result = repCounter.processPose(standingPose);
      expect(result.reps, 0);

      // Hop peak into the air (Ankles rise)
      final hopPeakPose = PoseData(
        timestamp: 250,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.45, y: 0.20, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.55, y: 0.20, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.46, y: 0.45, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.54, y: 0.45, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.47, y: 0.72, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.53, y: 0.72, score: 0.9),
        ],
      );
      result = repCounter.processPose(hopPeakPose);
      expect(result.phase, RepPhase.bottom);

      // Landing back on floor
      final landPose = PoseData(
        timestamp: 550,
        score: 0.95,
        keypoints: const [
          KeypointData(type: JointType.leftShoulder, x: 0.45, y: 0.25, score: 0.9),
          KeypointData(type: JointType.rightShoulder, x: 0.55, y: 0.25, score: 0.9),
          KeypointData(type: JointType.leftHip, x: 0.46, y: 0.50, score: 0.9),
          KeypointData(type: JointType.rightHip, x: 0.54, y: 0.50, score: 0.9),
          KeypointData(type: JointType.leftAnkle, x: 0.47, y: 0.88, score: 0.9),
          KeypointData(type: JointType.rightAnkle, x: 0.53, y: 0.88, score: 0.9),
        ],
      );
      result = repCounter.processPose(landPose);
      expect(result.reps, 1);
    });
  });

  group('RepCounterService - General & Duration', () {
    test('tickSecond formats duration and handles manual increment', () {
      final repCounter = RepCounterService(enableAudio: false);
      expect(repCounter.formattedDuration, '00:00');

      repCounter.tickSecond();
      repCounter.tickSecond();
      expect(repCounter.seconds, 2);
      expect(repCounter.formattedDuration, '00:02');

      repCounter.incrementManualRep();
      expect(repCounter.reps, 1);

      repCounter.reset();
      expect(repCounter.reps, 0);
      expect(repCounter.seconds, 0);
      expect(repCounter.formattedDuration, '00:00');
    });
  });
}
