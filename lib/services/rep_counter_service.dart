import 'dart:math' as math;
import '../models/pose_model.dart';
import '../models/session_stats.dart';
import 'audio_service.dart';

enum RepPhase {
  idle,
  down,
  bottom,
  up,
  completed,
}

class RepCounterResult {
  final int reps;
  final RepPhase phase;
  final double progress; // 0.0 to 1.0
  final String feedback;
  final bool isRepFinished;
  final String formQuality;
  final int formStreak;

  const RepCounterResult({
    required this.reps,
    required this.phase,
    required this.progress,
    required this.feedback,
    required this.isRepFinished,
    this.formQuality = 'perfect',
    this.formStreak = 0,
  });
}

class RepCounterService {
  final ExerciseType exerciseType;
  final Function(int newReps)? onRepCounted;
  final bool enableAudio;

  int _reps = 0;
  int _sets = 1;
  int _seconds = 0;
  int _currentCpm = 0;
  int _bestCpm = 0;
  int _formStreak = 0;
  int _maxFormStreak = 0;
  RepPhase _currentPhase = RepPhase.idle;
  double _progress = 0.0;
  String _feedback = 'Ready to start';
  String _formQuality = 'perfect';

  final List<int> _repTimestamps = [];
  int _lastRepTime = 0;
  static const int _repCooldownMs = 1000; // Realistic minimum human rep cycle (1 sec)

  // Running adaptive baseline for distance invariance
  double _standingHipY = 0.0;
  final Map<String, double> _smoothedAngles = {};

  RepCounterService({
    this.exerciseType = ExerciseType.squats,
    this.onRepCounted,
    this.enableAudio = true,
  });

  int get formStreak => _formStreak;
  int get maxFormStreak => _maxFormStreak;

  int get reps => _reps;
  int get sets => _sets;
  int get seconds => _seconds;
  int get currentCpm => _currentCpm;
  int get bestCpm => _bestCpm;
  int get avgCpm =>
      _seconds > 0 && _reps > 0 ? ((_reps / _seconds) * 60).round() : _currentCpm;
  RepPhase get phase => _currentPhase;
  double get progress => _progress;
  String get feedback => _feedback;
  String get formQuality => _formQuality;
  bool get isIsometric => exerciseType == ExerciseType.plank;

  String get formattedDuration {
    final mins = _seconds ~/ 60;
    final secs = _seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Exponential Moving Average (EMA) smoothing for angle stability
  double _getSmoothedAngle(String jointKey, double currentAngle, {double alpha = 0.85}) {
    final prev = _smoothedAngles[jointKey];
    if (prev == null) {
      _smoothedAngles[jointKey] = currentAngle;
      return currentAngle;
    }
    final smoothed = alpha * currentAngle + (1.0 - alpha) * prev;
    _smoothedAngles[jointKey] = smoothed;
    return smoothed;
  }

  /// Calculates dynamic torso scale for distance-invariant spatial thresholds
  double _getTorsoScale(
    KeypointData leftShoulder,
    KeypointData rightShoulder,
    KeypointData leftHip,
    KeypointData rightHip,
  ) {
    final midShoulderX = (leftShoulder.x + rightShoulder.x) / 2.0;
    final midShoulderY = (leftShoulder.y + rightShoulder.y) / 2.0;
    final midHipX = (leftHip.x + rightHip.x) / 2.0;
    final midHipY = (leftHip.y + rightHip.y) / 2.0;
    final dx = midShoulderX - midHipX;
    final dy = midShoulderY - midHipY;
    final dist = math.sqrt(dx * dx + dy * dy);
    return dist.clamp(0.15, 0.60);
  }

  void tickSecond() {
    _seconds++;
    if (exerciseType == ExerciseType.plank) {
      if (_formQuality == 'perfect' && _currentPhase == RepPhase.bottom) {
        _reps++;
        if (enableAudio) {
          AudioCoachService().speakPlankHold(_reps);
        }
        onRepCounted?.call(_reps);
      }
    } else {
      _updateCpmDecay();
    }
  }

  void reset() {
    _reps = 0;
    _sets = 1;
    _seconds = 0;
    _currentCpm = 0;
    _bestCpm = 0;
    _formStreak = 0;
    _currentPhase = RepPhase.idle;
    _progress = 0.0;
    _feedback = 'Ready to start';
    _standingHipY = 0.0;
    _repTimestamps.clear();
    _smoothedAngles.clear();
  }

  void incrementManualRep() {
    _reps++;
    _registerRepTimestamp();
    if (enableAudio) {
      AudioCoachService().speakRep(_reps);
    }
    onRepCounted?.call(_reps);
  }

  /// Validates genuine human presence to prevent false triggers from fans, chairs, or empty rooms
  bool _hasValidHumanPresence(PoseData pose) {
    if (pose.keypoints.isEmpty) return false;

    // Must have at least 3 visible landmarks with solid confidence (e.g. side-view floor pose)
    int visibleKeypoints = 0;
    for (final kp in pose.keypoints) {
      if (kp.score >= 0.35) visibleKeypoints++;
    }
    if (visibleKeypoints < 3) return false;

    final leftShoulder = pose.getKeypoint(JointType.leftShoulder);
    final rightShoulder = pose.getKeypoint(JointType.rightShoulder);
    final leftHip = pose.getKeypoint(JointType.leftHip);
    final rightHip = pose.getKeypoint(JointType.rightHip);

    final hasShoulders = (leftShoulder != null && leftShoulder.score >= 0.35) ||
                         (rightShoulder != null && rightShoulder.score >= 0.35);
    final hasHips = (leftHip != null && leftHip.score >= 0.35) ||
                    (rightHip != null && rightHip.score >= 0.35);

    return hasShoulders || hasHips;
  }

  RepCounterResult processPose(PoseData pose) {
    if (!_hasValidHumanPresence(pose)) {
      return RepCounterResult(
        reps: _reps,
        phase: RepPhase.idle,
        progress: 0.0,
        feedback: 'Position yourself in camera view',
        isRepFinished: false,
      );
    }

    switch (exerciseType) {
      case ExerciseType.squats:
        return _processSquats(pose);
      case ExerciseType.jumpingJacks:
        return _processJumpingJacks(pose);
      case ExerciseType.pushups:
        return _processPushups(pose);
      case ExerciseType.lunges:
        return _processLunges(pose);
      case ExerciseType.highKnees:
        return _processHighKnees(pose);
      case ExerciseType.plank:
        return _processPlank(pose);
      case ExerciseType.crunches:
        return _processCrunches(pose);
      case ExerciseType.ropeSkipping:
        return _processRopeSkipping(pose);
    }
  }

  /// Calculates the 3-point angle (in degrees) between p1-p2-p3 at vertex p2
  double _calculateAngle(KeypointData p1, KeypointData p2, KeypointData p3) {
    final double v1x = p1.x - p2.x;
    final double v1y = p1.y - p2.y;
    final double v2x = p3.x - p2.x;
    final double v2y = p3.y - p2.y;

    final double dot = v1x * v2x + v1y * v2y;
    final double mag1 = math.sqrt(v1x * v1x + v1y * v1y);
    final double mag2 = math.sqrt(v2x * v2x + v2y * v2y);

    if (mag1 * mag2 == 0) return 180.0;
    final double cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return math.acos(cosAngle) * 180.0 / math.pi;
  }

  RepCounterResult _processSquats(PoseData pose) {
    final leftHip = pose.getKeypoint(JointType.leftHip);
    final rightHip = pose.getKeypoint(JointType.rightHip);
    final leftKnee = pose.getKeypoint(JointType.leftKnee);
    final rightKnee = pose.getKeypoint(JointType.rightKnee);
    final leftAnkle = pose.getKeypoint(JointType.leftAnkle);
    final rightAnkle = pose.getKeypoint(JointType.rightAnkle);
    final leftShoulder = pose.getKeypoint(JointType.leftShoulder);
    final rightShoulder = pose.getKeypoint(JointType.rightShoulder);

    // Require both hips and knees to be visible
    if (leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftHip.score < 0.35 ||
        rightHip.score < 0.35 ||
        leftKnee.score < 0.35 ||
        rightKnee.score < 0.35) {
      return RepCounterResult(
        reps: _reps,
        phase: _currentPhase,
        progress: _progress,
        feedback: 'Step back to frame hips & knees',
        isRepFinished: false,
      );
    }

    // Compute Torso Scale for distance-invariant normalization
    double torsoScale = 0.30;
    if (leftShoulder != null && rightShoulder != null) {
      torsoScale = _getTorsoScale(leftShoulder, rightShoulder, leftHip, rightHip);
    }

    // 1. Planted Feet & Single-Leg Asymmetry Check
    // In a squat, both feet MUST stay planted on the floor at the same vertical level
    bool isSingleLegLift = false;
    if (leftAnkle != null &&
        rightAnkle != null &&
        leftAnkle.score > 0.35 &&
        rightAnkle.score > 0.35) {
      final double ankleHeightDiff = (leftAnkle.y - rightAnkle.y).abs();
      // If one ankle is lifted significantly higher than the other (leg raise / stretch / kick)
      if (ankleHeightDiff > torsoScale * 0.35) {
        isSingleLegLift = true;
      }
    }

    // 2. Calculate Biomechanical Knee Angles (Hip-Knee-Ankle) for BOTH legs with EMA Smoothing
    double leftKneeAngle = 180.0;
    double rightKneeAngle = 180.0;
    int angleCount = 0;

    if (leftAnkle != null && leftAnkle.score > 0.35) {
      final rawAngle = _calculateAngle(leftHip, leftKnee, leftAnkle);
      leftKneeAngle = _getSmoothedAngle('squat_left_knee', rawAngle);
      angleCount++;
    }

    if (rightAnkle != null && rightAnkle.score > 0.35) {
      final rawAngle = _calculateAngle(rightHip, rightKnee, rightAnkle);
      rightKneeAngle = _getSmoothedAngle('squat_right_knee', rawAngle);
      angleCount++;
    }

    // Bilateral Symmetry Check: Both legs must bend together
    bool isAsymmetricLegBend = false;
    if (angleCount == 2) {
      final double kneeAngleDiff = (leftKneeAngle - rightKneeAngle).abs();
      // If one knee is bent (<130°) but the other is straight (>155°), it's not a squat!
      if (kneeAngleDiff > 28.0 && (leftKneeAngle < 130.0 || rightKneeAngle < 130.0)) {
        isAsymmetricLegBend = true;
      }
    }

    // 3. Check Torso Inclination (prevent false squats from merely bending back/waist)
    bool isBendingTorsoOnly = false;
    if (leftShoulder != null && rightShoulder != null) {
      final avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2.0;
      final avgHipY = (leftHip.y + rightHip.y) / 2.0;
      final minKneeAngle = math.min(leftKneeAngle, rightKneeAngle);
      // If shoulder drops heavily while knees remain straight (>145°), user is just bending over
      if ((avgHipY - avgShoulderY) < 0.15 && minKneeAngle > 145.0) {
        isBendingTorsoOnly = true;
      }
    }

    // 4. Compute Progress from True Bilateral Knee Flexion
    // Both knees must reach depth! We use the MAX knee angle (the less-bent leg must also reach depth)
    double rawProgress = 0.0;
    const double standingAngle = 168.0;
    const double deepSquatAngle = 106.0;

    final bool isInvalidMovement = isSingleLegLift || isAsymmetricLegBend || isBendingTorsoOnly;

    if (angleCount == 2 && !isInvalidMovement) {
      final double effectiveKneeAngle = math.max(leftKneeAngle, rightKneeAngle);
      rawProgress = ((standingAngle - effectiveKneeAngle) / (standingAngle - deepSquatAngle)).clamp(0.0, 1.0);
    } else if (angleCount == 1 && !isInvalidMovement) {
      final double singleAngle = leftAnkle != null && leftAnkle.score > 0.35 ? leftKneeAngle : rightKneeAngle;
      rawProgress = ((standingAngle - singleAngle) / (standingAngle - deepSquatAngle)).clamp(0.0, 1.0);
    } else if (!isInvalidMovement) {
      final avgHipY = (leftHip.y + rightHip.y) / 2.0;
      final avgKneeY = (leftKnee.y + rightKnee.y) / 2.0;
      if (_standingHipY == 0.0 || (_currentPhase == RepPhase.idle && avgHipY < _standingHipY)) {
        _standingHipY = avgHipY;
      }
      final double hipDrop = (avgHipY - _standingHipY).clamp(0.0, 0.35);
      final double kneeDist = (avgKneeY - avgHipY).clamp(0.08, 0.45);
      rawProgress = (hipDrop / (kneeDist * 0.95)).clamp(0.0, 1.0);
    }

    bool isFinished = false;
    String newFeedback = _feedback;
    String quality = _formQuality;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 5. Form Quality & Wrong-Exercise Feedback Routing
    if (isSingleLegLift) {
      newFeedback = 'Plant both feet firmly on the floor!';
      quality = 'adjust';
    } else if (isAsymmetricLegBend) {
      newFeedback = 'Bend both knees together symmetrically!';
      quality = 'adjust';
    } else if (isBendingTorsoOnly) {
      newFeedback = 'Keep chest upright & bend knees!';
      quality = 'adjust';
    } else if (_currentPhase == RepPhase.idle || _currentPhase == RepPhase.completed) {
      if (rawProgress >= 0.80) {
        // Deep squat reached directly
        _currentPhase = RepPhase.bottom;
        newFeedback = 'Great depth! Push up!';
        quality = 'perfect';
      } else if (rawProgress >= 0.35) {
        _currentPhase = RepPhase.down;
        newFeedback = 'Squat deeper... Lower hips!';
        quality = 'perfect';
      }
    } else if (_currentPhase == RepPhase.down) {
      if (rawProgress >= 0.80) {
        // Full parallel squat depth reached
        _currentPhase = RepPhase.bottom;
        newFeedback = 'Great depth! Push up!';
        quality = 'perfect';
      } else if (rawProgress < 0.20) {
        // Stood back up without reaching bottom depth (shallow bend rejected)
        _currentPhase = RepPhase.idle;
        newFeedback = 'Squat lower for full rep!';
      }
    } else if (_currentPhase == RepPhase.bottom) {
      if (rawProgress <= 0.15 && now - _lastRepTime > _repCooldownMs) {
        _currentPhase = RepPhase.completed;
        isFinished = true;
        _lastRepTime = now;
        newFeedback = 'Squat counted! Excellent form!';
      } else if (rawProgress < 0.55) {
        _currentPhase = RepPhase.up;
        newFeedback = 'Drive back up to standing!';
      }
    } else if (_currentPhase == RepPhase.up) {
      // Returning to fully upright standing position completes the rep
      if (rawProgress <= 0.15 && now - _lastRepTime > _repCooldownMs) {
        _currentPhase = RepPhase.completed;
        isFinished = true;
        _lastRepTime = now;
        newFeedback = 'Squat counted! Excellent form!';
      }
    }

    // Full 2-Way Continuous Progress (0% -> 50% on descent, 50% -> 100% on ascent)
    double continuousProgress = 0.0;
    if (isFinished) {
      continuousProgress = 1.0;
    } else if (_currentPhase == RepPhase.idle || _currentPhase == RepPhase.down) {
      continuousProgress = rawProgress * 0.50;
    } else if (_currentPhase == RepPhase.bottom) {
      continuousProgress = 0.50;
    } else if (_currentPhase == RepPhase.up) {
      final double returnProgress = (1.0 - rawProgress).clamp(0.0, 1.0);
      continuousProgress = 0.50 + (returnProgress * 0.50);
    }

    _progress = isInvalidMovement ? 0.0 : continuousProgress;
    _feedback = newFeedback;
    _formQuality = quality;

    if (isFinished) {
      _reps++;
      _registerRepTimestamp();
      if (enableAudio) {
        AudioCoachService().speakRep(_reps);
      }
      onRepCounted?.call(_reps);
    }

    return RepCounterResult(
      reps: _reps,
      phase: _currentPhase,
      progress: _progress,
      feedback: _feedback,
      isRepFinished: isFinished,
      formQuality: _formQuality,
    );
  }

  RepCounterResult _processJumpingJacks(PoseData pose) {
    final leftWrist = pose.getKeypoint(JointType.leftWrist);
    final rightWrist = pose.getKeypoint(JointType.rightWrist);
    final leftShoulder = pose.getKeypoint(JointType.leftShoulder);
    final rightShoulder = pose.getKeypoint(JointType.rightShoulder);
    final leftAnkle = pose.getKeypoint(JointType.leftAnkle);
    final rightAnkle = pose.getKeypoint(JointType.rightAnkle);
    final leftHip = pose.getKeypoint(JointType.leftHip);
    final rightHip = pose.getKeypoint(JointType.rightHip);

    if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) {
      return RepCounterResult(
        reps: _reps,
        phase: _currentPhase,
        progress: _progress,
        feedback: 'Frame arms & upper body in view',
        isRepFinished: false,
      );
    }

    // Compute Torso Scale for distance-invariant normalization
    double torsoScale = 0.30;
    if (leftHip != null && rightHip != null) {
      torsoScale = _getTorsoScale(leftShoulder, rightShoulder, leftHip, rightHip);
    }

    // 1. Arm Elevation (Wrists must rise above shoulder height for true jumping jacks)
    final avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2.0;
    final avgWristY = (leftWrist.y + rightWrist.y) / 2.0;
    final wristSpread = (rightWrist.x - leftWrist.x).abs();

    // Arms overhead factor: 1.0 when wrists are well above shoulders
    final armLift = ((avgShoulderY - avgWristY) + torsoScale * 0.25) / (torsoScale * 0.85);
    final armProgress = (armLift).clamp(0.0, 1.0);

    // 2. Leg Spread Factor (Ankles must spread wider than hips)
    double legProgress = armProgress; // default follow arm if ankles offscreen
    if (leftAnkle != null && rightAnkle != null && leftHip != null && rightHip != null) {
      final hipWidth = (rightHip.x - leftHip.x).abs();
      final ankleWidth = (rightAnkle.x - leftAnkle.x).abs();
      legProgress = ((ankleWidth - hipWidth * 0.8) / (hipWidth * 1.4)).clamp(0.0, 1.0);
    }

    // Combined Jumping Jack progress requires BOTH arm overhead reach and leg spread
    final rawProgress = (armProgress * 0.65 + legProgress * 0.35).clamp(0.0, 1.0);

    bool isFinished = false;
    String newFeedback = _feedback;
    String quality = 'perfect';
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check for improper form (e.g. moving hands wide sideways without raising overhead)
    if (wristSpread > torsoScale * 1.65 && avgWristY > avgShoulderY) {
      newFeedback = 'Raise hands all the way overhead!';
      quality = 'adjust';
    } else if (_currentPhase == RepPhase.idle || _currentPhase == RepPhase.completed) {
      if (rawProgress >= 0.52) {
        _currentPhase = RepPhase.bottom;
        newFeedback = 'Full extension! Return inward!';
      } else if (rawProgress > 0.22) {
        _currentPhase = RepPhase.down;
        newFeedback = 'Jump outward with arms up!';
      }
    } else if (_currentPhase == RepPhase.down) {
      if (rawProgress >= 0.52) {
        _currentPhase = RepPhase.bottom;
        newFeedback = 'Full extension! Return inward!';
      } else if (rawProgress < 0.12) {
        _currentPhase = RepPhase.idle;
      }
    } else if (_currentPhase == RepPhase.bottom) {
      if (rawProgress <= 0.32 && now - _lastRepTime > 300) {
        _currentPhase = RepPhase.completed;
        isFinished = true;
        _lastRepTime = now;
        newFeedback = 'Jack counted! Great energy!';
      } else if (rawProgress < 0.45) {
        _currentPhase = RepPhase.up;
      }
    } else if (_currentPhase == RepPhase.up) {
      if (rawProgress <= 0.32 && now - _lastRepTime > 300) {
        _currentPhase = RepPhase.completed;
        isFinished = true;
        _lastRepTime = now;
        newFeedback = 'Jack counted! Great energy!';
      }
    }

    // Full 2-Way Continuous Progress (0% -> 50% on outward extension, 50% -> 100% on return inward)
    double continuousProgress = 0.0;
    if (isFinished) {
      continuousProgress = 1.0;
    } else if (_currentPhase == RepPhase.idle || _currentPhase == RepPhase.down) {
      continuousProgress = rawProgress * 0.50;
    } else if (_currentPhase == RepPhase.bottom) {
      continuousProgress = 0.50;
    } else if (_currentPhase == RepPhase.up) {
      final double returnProgress = (1.0 - rawProgress).clamp(0.0, 1.0);
      continuousProgress = 0.50 + (returnProgress * 0.50);
    }

    _progress = continuousProgress;
    _feedback = newFeedback;
    _formQuality = quality;

    if (isFinished) {
      _reps++;
      _registerRepTimestamp();
      if (enableAudio) {
        AudioCoachService().speakRep(_reps);
      }
      onRepCounted?.call(_reps);
    }

    return RepCounterResult(
      reps: _reps,
      phase: _currentPhase,
      progress: _progress,
      feedback: _feedback,
      isRepFinished: isFinished,
      formQuality: _formQuality,
    );
  }



  RepCounterResult _processPushups(PoseData pose) {
    final leftShoulder = pose.getKeypoint(JointType.leftShoulder);
    final rightShoulder = pose.getKeypoint(JointType.rightShoulder);
    final leftElbow = pose.getKeypoint(JointType.leftElbow);
    final rightElbow = pose.getKeypoint(JointType.rightElbow);
    final leftWrist = pose.getKeypoint(JointType.leftWrist);
    final rightWrist = pose.getKeypoint(JointType.rightWrist);
    final leftHip = pose.getKeypoint(JointType.leftHip);
    final rightHip = pose.getKeypoint(JointType.rightHip);

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null) {
      return RepCounterResult(
        reps: _reps,
        phase: _currentPhase,
        progress: _progress,
        feedback: 'Frame arms & upper body in view',
        isRepFinished: false,
      );
    }

    final leftAnkle = pose.getKeypoint(JointType.leftAnkle);
    final rightAnkle = pose.getKeypoint(JointType.rightAnkle);
    final avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2.0;
    final avgWristY = (leftWrist.y + rightWrist.y) / 2.0;

    // Hands floating high in ceiling/air (e.g. ceiling fan or standing waving hands)
    if (avgWristY < 0.20) {
      _currentPhase = RepPhase.idle;
      return RepCounterResult(
        reps: _reps,
        phase: RepPhase.idle,
        progress: 0.0,
        feedback: 'Place hands firmly on the floor',
        isRepFinished: false,
        formQuality: 'adjust',
      );
    }

    // Gate: Check if user is standing upright instead of horizontal pushup stance on floor
    if (leftHip != null && rightHip != null) {
      final avgHipY = (leftHip.y + rightHip.y) / 2.0;
      bool isStanding = false;
      if (leftAnkle != null && rightAnkle != null && leftAnkle.score > 0.35 && rightAnkle.score > 0.35) {
        final avgAnkleY = (leftAnkle.y + rightAnkle.y) / 2.0;
        if ((avgAnkleY - avgHipY > 0.18) && (avgHipY - avgShoulderY > 0.18)) {
          isStanding = true;
        }
      }
      if (isStanding) {
        _currentPhase = RepPhase.idle;
        return RepCounterResult(
          reps: _reps,
          phase: RepPhase.idle,
          progress: 0.0,
          feedback: 'Get down on the floor in pushup position',
          isRepFinished: false,
          formQuality: 'adjust',
        );
      }
    }

    // Compute Torso Scale for distance-invariant normalization
    double torsoScale = 0.30;
    if (leftHip != null && rightHip != null) {
      torsoScale = _getTorsoScale(leftShoulder, rightShoulder, leftHip, rightHip);
    }

    // 1. Calculate Elbow Angles (Shoulder-Elbow-Wrist) for both arms with EMA Smoothing
    double leftElbowAngle = 180.0;
    double rightElbowAngle = 180.0;
    int angleCount = 0;

    if (leftShoulder.score > 0.40 && leftElbow.score > 0.40 && leftWrist.score > 0.40) {
      final rawAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist);
      leftElbowAngle = _getSmoothedAngle('pushup_left_elbow', rawAngle);
      angleCount++;
    }

    if (rightShoulder.score > 0.40 && rightElbow.score > 0.40 && rightWrist.score > 0.40) {
      final rawAngle = _calculateAngle(rightShoulder, rightElbow, rightWrist);
      rightElbowAngle = _getSmoothedAngle('pushup_right_elbow', rawAngle);
      angleCount++;
    }

    if (angleCount == 0) {
      return RepCounterResult(
        reps: _reps,
        phase: _currentPhase,
        progress: _progress,
        feedback: 'Frame arms in view',
        isRepFinished: false,
      );
    }

    // 2. Average Elbow Angle (representative of upper body flexion)
    final double avgElbowAngle = angleCount == 2
        ? (leftElbowAngle + rightElbowAngle) / 2.0
        : (leftElbow.score > 0.30 ? leftElbowAngle : rightElbowAngle);

    // 3. Human Pushup Progress: Lockout (~150°) to Bottom Chest Depth (~98°)
    const double upAngle = 150.0;
    const double downAngle = 98.0;
    final double rawProgress = ((upAngle - avgElbowAngle) / (upAngle - downAngle)).clamp(0.0, 1.0);

    // 4. Form Quality Evaluation (Guidance without blocking rep tracking)
    bool isAsymmetricArmBend = false;
    if (angleCount == 2) {
      final double elbowDiff = (leftElbowAngle - rightElbowAngle).abs();
      if (elbowDiff > 38.0 && (leftElbowAngle < 120.0 || rightElbowAngle < 120.0)) {
        isAsymmetricArmBend = true;
      }
    }

    bool isHipsSagging = false;
    if (leftHip != null && rightHip != null) {
      final avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2.0;
      final avgHipY = (leftHip.y + rightHip.y) / 2.0;
      if (avgHipY - avgShoulderY > torsoScale * 0.95) {
        isHipsSagging = true;
      }
    }

    bool isFinished = false;
    String newFeedback = _feedback;
    String quality = 'perfect';
    final now = DateTime.now().millisecondsSinceEpoch;

    if (isAsymmetricArmBend) {
      newFeedback = 'Lower chest evenly with both arms!';
      quality = 'adjust';
    } else if (isHipsSagging) {
      newFeedback = 'Keep core tight! Don\'t sag hips!';
      quality = 'adjust';
    }

    if (_currentPhase == RepPhase.idle || _currentPhase == RepPhase.completed) {
      if (rawProgress >= 0.75) {
        _currentPhase = RepPhase.bottom;
        if (!isAsymmetricArmBend && !isHipsSagging) {
          newFeedback = 'Chest down! Press up strong!';
        }
      } else if (rawProgress >= 0.30) {
        _currentPhase = RepPhase.down;
        if (!isAsymmetricArmBend && !isHipsSagging) {
          newFeedback = 'Lower chest toward floor...';
        }
      }
    } else if (_currentPhase == RepPhase.down) {
      if (rawProgress >= 0.75) {
        _currentPhase = RepPhase.bottom;
        if (!isAsymmetricArmBend && !isHipsSagging) {
          newFeedback = 'Chest down! Press up strong!';
        }
      } else if (rawProgress < 0.15) {
        _currentPhase = RepPhase.idle;
      }
    } else if (_currentPhase == RepPhase.bottom) {
      if (rawProgress <= 0.25 && now - _lastRepTime > 750) {
        _currentPhase = RepPhase.completed;
        isFinished = true;
        _lastRepTime = now;
        newFeedback = 'Pushup counted! Lock out arms!';
      } else if (rawProgress < 0.50) {
        _currentPhase = RepPhase.up;
        if (!isAsymmetricArmBend && !isHipsSagging) {
          newFeedback = 'Push up & lock out arms!';
        }
      }
    } else if (_currentPhase == RepPhase.up) {
      if (rawProgress <= 0.25 && now - _lastRepTime > 750) {
        _currentPhase = RepPhase.completed;
        isFinished = true;
        _lastRepTime = now;
        newFeedback = 'Pushup counted! Lock out arms!';
      }
    }

    // Full 2-Way Continuous Progress (0% -> 50% on descent, 50% -> 100% on ascent)
    double continuousProgress = 0.0;
    if (isFinished) {
      continuousProgress = 1.0;
    } else if (_currentPhase == RepPhase.idle || _currentPhase == RepPhase.down) {
      continuousProgress = rawProgress * 0.50;
    } else if (_currentPhase == RepPhase.bottom) {
      continuousProgress = 0.50;
    } else if (_currentPhase == RepPhase.up) {
      final double returnProgress = (1.0 - rawProgress).clamp(0.0, 1.0);
      continuousProgress = 0.50 + (returnProgress * 0.50);
    }

    _progress = continuousProgress;
    _feedback = newFeedback;
    _formQuality = quality;

    if (isFinished) {
      _reps++;
      _registerRepTimestamp();
      if (enableAudio) {
        AudioCoachService().speakRep(_reps);
      }
      onRepCounted?.call(_reps);
    }

    return RepCounterResult(
      reps: _reps,
      phase: _currentPhase,
      progress: _progress,
      feedback: _feedback,
      isRepFinished: isFinished,
      formQuality: _formQuality,
    );
  }

  RepCounterResult _processLunges(PoseData pose) {
    final leftHip = pose.getKeypoint(JointType.leftHip);
    final rightHip = pose.getKeypoint(JointType.rightHip);
    final leftKnee = pose.getKeypoint(JointType.leftKnee);
    final rightKnee = pose.getKeypoint(JointType.rightKnee);
    final leftAnkle = pose.getKeypoint(JointType.leftAnkle);
    final rightAnkle = pose.getKeypoint(JointType.rightAnkle);

    if (leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return RepCounterResult(
        reps: _reps,
        phase: _currentPhase,
        progress: _progress,
        feedback: 'Frame full legs and feet in view',
        isRepFinished: false,
      );
    }

    final leftShoulder = pose.getKeypoint(JointType.leftShoulder);
    final rightShoulder = pose.getKeypoint(JointType.rightShoulder);

    // Compute Torso Scale for distance-invariant normalization
    double torsoScale = 0.30;
    if (leftShoulder != null && rightShoulder != null) {
      torsoScale = _getTorsoScale(leftShoulder, rightShoulder, leftHip, rightHip);
    }

    // 1. Calculate Knee Angles for both legs with EMA Smoothing
    double leftKneeAngle = 180.0;
    double rightKneeAngle = 180.0;
    int scoredKnees = 0;

    if (leftAnkle.score > 0.25 && leftKnee.score > 0.25) {
      final rawAngle = _calculateAngle(leftHip, leftKnee, leftAnkle);
      leftKneeAngle = _getSmoothedAngle('lunge_left_knee', rawAngle);
      scoredKnees++;
    }
    if (rightAnkle.score > 0.25 && rightKnee.score > 0.25) {
      final rawAngle = _calculateAngle(rightHip, rightKnee, rightAnkle);
      rightKneeAngle = _getSmoothedAngle('lunge_right_knee', rawAngle);
      scoredKnees++;
    }

    if (scoredKnees == 0) {
      return RepCounterResult(
        reps: _reps,
        phase: _currentPhase,
        progress: _progress,
        feedback: 'Position legs clearly in view',
        isRepFinished: false,
      );
    }

    // Identify front lunging leg (the leg with deeper flexion)
    final double frontKneeAngle = scoredKnees == 2
        ? math.min(leftKneeAngle, rightKneeAngle)
        : (leftAnkle.score > 0.25 ? leftKneeAngle : rightKneeAngle);
    final double rearKneeAngle = scoredKnees == 2
        ? math.max(leftKneeAngle, rightKneeAngle)
        : 180.0;

    // 2. Split Stance (Foot Separation) Check
    final double ankleDistX = (leftAnkle.x - rightAnkle.x).abs();
    final double ankleDistY = (leftAnkle.y - rightAnkle.y).abs();
    final double footSeparation = math.sqrt(ankleDistX * ankleDistX + ankleDistY * ankleDistY);
    final bool isNarrowStance = footSeparation < (torsoScale * 0.30);

    // 3. Vertical Hip Displacement (Hips drop down during lunge)
    final double avgHipY = (leftHip.y + rightHip.y) / 2.0;
    if (_standingHipY == 0.0 || (_currentPhase == RepPhase.idle && avgHipY < _standingHipY)) {
      _standingHipY = avgHipY;
    }
    final double hipDrop = (avgHipY - _standingHipY).clamp(0.0, 0.35);
    final double hipDropProgress = (hipDrop / (torsoScale * 0.22)).clamp(0.0, 1.0);

    // 4. Human-Realistic Lunge Progress:
    // Standing Lockout (~162°) -> Deep / Modified Lunge Depth (~110° to 90°)
    const double standingAngle = 162.0;
    const double deepLungeAngle = 105.0;
    final double kneeProgress =
        ((standingAngle - frontKneeAngle) / (standingAngle - deepLungeAngle)).clamp(0.0, 1.0);

    // Dynamic combined progress: Front knee bend is primary (75%), hip drop is secondary (25%)
    final double rawProgress = (kneeProgress * 0.75 + hipDropProgress * 0.25).clamp(0.0, 1.0);

    // 5. Helpful Real-Time Form Coaching (Non-blocking guidance)
    String quality = 'perfect';
    String newFeedback = _feedback;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (isNarrowStance && frontKneeAngle < 135.0) {
      newFeedback = 'Step feet further apart into split stance!';
      quality = 'adjust';
    } else if (frontKneeAngle < 125.0 && rearKneeAngle > 165.0) {
      newFeedback = 'Drop back knee toward the floor!';
      quality = 'adjust';
    }

    bool isFinished = false;

    // 6. Robust State Machine
    if (_currentPhase == RepPhase.idle || _currentPhase == RepPhase.completed) {
      if (!isNarrowStance && (rawProgress >= 0.65 || frontKneeAngle <= 118.0)) {
        _currentPhase = RepPhase.bottom;
        newFeedback = 'Great depth! Push back to standing!';
      } else if (!isNarrowStance && rawProgress >= 0.28) {
        _currentPhase = RepPhase.down;
        newFeedback = 'Step forward & lower into lunge...';
      }
    } else if (_currentPhase == RepPhase.down) {
      if (!isNarrowStance && (rawProgress >= 0.65 || frontKneeAngle <= 118.0)) {
        _currentPhase = RepPhase.bottom;
        newFeedback = 'Great depth! Push back to standing!';
      } else if (rawProgress < 0.15 && frontKneeAngle >= 152.0) {
        _currentPhase = RepPhase.idle;
      }
    } else if (_currentPhase == RepPhase.bottom) {
      if ((rawProgress <= 0.25 || frontKneeAngle >= 148.0) && now - _lastRepTime > 650) {
        _currentPhase = RepPhase.completed;
        isFinished = true;
        _lastRepTime = now;
        newFeedback = 'Lunge counted! Excellent posture!';
      } else if (rawProgress < 0.50) {
        _currentPhase = RepPhase.up;
        newFeedback = 'Push through front heel to standing!';
      }
    } else if (_currentPhase == RepPhase.up) {
      if ((rawProgress <= 0.25 || frontKneeAngle >= 148.0) && now - _lastRepTime > 650) {
        _currentPhase = RepPhase.completed;
        isFinished = true;
        _lastRepTime = now;
        newFeedback = 'Lunge counted! Alternate legs!';
      }
    }

    // Full 2-Way Continuous Progress (0% -> 50% on descent, 50% -> 100% on ascent)
    double continuousProgress = 0.0;
    if (isFinished) {
      continuousProgress = 1.0;
    } else if (_currentPhase == RepPhase.idle || _currentPhase == RepPhase.down) {
      continuousProgress = rawProgress * 0.50;
    } else if (_currentPhase == RepPhase.bottom) {
      continuousProgress = 0.50;
    } else if (_currentPhase == RepPhase.up) {
      final double returnProgress = (1.0 - rawProgress).clamp(0.0, 1.0);
      continuousProgress = 0.50 + (returnProgress * 0.50);
    }

    _progress = continuousProgress;
    _feedback = newFeedback;
    _formQuality = quality;

    if (isFinished) {
      _reps++;
      _registerRepTimestamp();
      if (enableAudio) {
        AudioCoachService().speakRep(_reps);
      }
      onRepCounted?.call(_reps);
    }

    return RepCounterResult(
      reps: _reps,
      phase: _currentPhase,
      progress: _progress,
      feedback: _feedback,
      isRepFinished: isFinished,
      formQuality: _formQuality,
    );
  }

  RepCounterResult _processHighKnees(PoseData pose) {
    final leftHip = pose.getKeypoint(JointType.leftHip);
    final rightHip = pose.getKeypoint(JointType.rightHip);
    final leftKnee = pose.getKeypoint(JointType.leftKnee);
    final rightKnee = pose.getKeypoint(JointType.rightKnee);

    if (leftHip == null || rightHip == null || leftKnee == null || rightKnee == null) {
      return RepCounterResult(
        reps: _reps,
        phase: _currentPhase,
        progress: _progress,
        feedback: 'Frame full body in view',
        isRepFinished: false,
      );
    }

    final avgHipY = (leftHip.y + rightHip.y) / 2.0;
    if (_standingHipY == 0.0 || (_currentPhase == RepPhase.idle && avgHipY < _standingHipY)) {
      _standingHipY = avgHipY;
    }

    // High knee elevation: Highest knee (minimum Y) relative to standing hip baseline
    final double highestKneeY = math.min(leftKnee.y, rightKnee.y);
    final double kneeLift = (_standingHipY + 0.12 - highestKneeY).clamp(0.0, 0.30);
    final double rawProgress = (kneeLift / 0.18).clamp(0.0, 1.0);

    bool isFinished = false;
    String newFeedback = _feedback;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_currentPhase == RepPhase.idle || _currentPhase == RepPhase.completed) {
      if (rawProgress >= 0.75) {
        _currentPhase = RepPhase.bottom;
        newFeedback = 'Knee high! Keep pumping!';
      } else if (rawProgress > 0.30) {
        _currentPhase = RepPhase.down;
        newFeedback = 'Drive knees up to hip level!';
      }
    } else if (_currentPhase == RepPhase.down) {
      if (rawProgress >= 0.75) {
        _currentPhase = RepPhase.bottom;
        newFeedback = 'Knee high! Keep pumping!';
      }
    } else if (_currentPhase == RepPhase.bottom) {
      if (rawProgress <= 0.25 && now - _lastRepTime > 280) {
        _currentPhase = RepPhase.completed;
        isFinished = true;
        _lastRepTime = now;
        newFeedback = 'Great rhythm! Keep knees high!';
      } else if (rawProgress < 0.50) {
        _currentPhase = RepPhase.up;
      }
    } else if (_currentPhase == RepPhase.up) {
      if (rawProgress <= 0.25 && now - _lastRepTime > 280) {
        _currentPhase = RepPhase.completed;
        isFinished = true;
        _lastRepTime = now;
        newFeedback = 'Great rhythm! Keep knees high!';
      }
    }

    // Full 2-Way Continuous Progress (0% -> 50% on knee drive, 50% -> 100% on foot drop)
    double continuousProgress = 0.0;
    if (isFinished) {
      continuousProgress = 1.0;
    } else if (_currentPhase == RepPhase.idle || _currentPhase == RepPhase.down) {
      continuousProgress = rawProgress * 0.50;
    } else if (_currentPhase == RepPhase.bottom) {
      continuousProgress = 0.50;
    } else if (_currentPhase == RepPhase.up) {
      final double returnProgress = (1.0 - rawProgress).clamp(0.0, 1.0);
      continuousProgress = 0.50 + (returnProgress * 0.50);
    }

    _progress = continuousProgress;
    _feedback = newFeedback;

    if (isFinished) {
      _reps++;
      _registerRepTimestamp();
      if (enableAudio) {
        AudioCoachService().speakRep(_reps);
      }
      onRepCounted?.call(_reps);
    }

    return RepCounterResult(
      reps: _reps,
      phase: _currentPhase,
      progress: _progress,
      feedback: _feedback,
      isRepFinished: isFinished,
    );
  }

  RepCounterResult _processPlank(PoseData pose) {
    final leftShoulder = pose.getKeypoint(JointType.leftShoulder);
    final rightShoulder = pose.getKeypoint(JointType.rightShoulder);
    final leftHip = pose.getKeypoint(JointType.leftHip);
    final rightHip = pose.getKeypoint(JointType.rightHip);
    final leftAnkle = pose.getKeypoint(JointType.leftAnkle);
    final rightAnkle = pose.getKeypoint(JointType.rightAnkle);

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return RepCounterResult(
        reps: _seconds, // For plank, active hold duration is the score
        phase: _currentPhase,
        progress: _progress,
        feedback: 'Frame full body horizontally in plank',
        isRepFinished: false,
      );
    }

    final shoulder = leftShoulder.score > rightShoulder.score ? leftShoulder : rightShoulder;
    final hip = leftHip.score > rightHip.score ? leftHip : rightHip;
    final ankle = leftAnkle != null && rightAnkle != null
        ? (leftAnkle.score > rightAnkle.score ? leftAnkle : rightAnkle)
        : null;

    double spineAngle = 175.0;
    if (ankle != null && ankle.score > 0.30) {
      spineAngle = _calculateAngle(shoulder, hip, ankle);
    }

    String quality = 'perfect';
    String newFeedback = 'Solid plank! Hold strong!';

    if (spineAngle < 150.0) {
      quality = 'adjust';
      newFeedback = 'Hips sagging! Tighten core & raise hips!';
      _currentPhase = RepPhase.down;
    } else if (spineAngle > 200.0) {
      quality = 'adjust';
      newFeedback = 'Hips too high! Lower into a straight line!';
      _currentPhase = RepPhase.up;
    } else {
      quality = 'perfect';
      _currentPhase = RepPhase.bottom; // Active hold in good form
      newFeedback = 'Solid plank! Hold strong!';
    }

    _progress = quality == 'perfect' ? 1.0 : 0.4;
    _feedback = newFeedback;
    _formQuality = quality;

    return RepCounterResult(
      reps: _reps,
      phase: _currentPhase,
      progress: _progress,
      feedback: _feedback,
      isRepFinished: false,
      formQuality: _formQuality,
    );
  }

  RepCounterResult _processCrunches(PoseData pose) {
    final leftShoulder = pose.getKeypoint(JointType.leftShoulder);
    final rightShoulder = pose.getKeypoint(JointType.rightShoulder);
    final leftHip = pose.getKeypoint(JointType.leftHip);
    final rightHip = pose.getKeypoint(JointType.rightHip);
    final leftKnee = pose.getKeypoint(JointType.leftKnee);
    final rightKnee = pose.getKeypoint(JointType.rightKnee);

    // Torso (shoulder + hip) is required. Knee is optional (if framed, used directly; if cut off in half-body view, virtual knee is synthesized).
    final bool hasLeftTorso = leftShoulder != null &&
        leftHip != null &&
        leftShoulder.score > 0.20 &&
        leftHip.score > 0.20;

    final bool hasRightTorso = rightShoulder != null &&
        rightHip != null &&
        rightShoulder.score > 0.20 &&
        rightHip.score > 0.20;

    if (!hasLeftTorso && !hasRightTorso) {
      return RepCounterResult(
        reps: _reps,
        phase: _currentPhase,
        progress: _progress,
        feedback: 'Lie on floor & frame torso and hips in view',
        isRepFinished: false,
      );
    }

    final bool hasLeftKnee = leftKnee != null && leftKnee.score > 0.20;
    final bool hasRightKnee = rightKnee != null && rightKnee.score > 0.20;

    // Calculates or synthesizes crunch angle for a side
    double calculateSideCrunchAngle({
      required KeypointData shoulder,
      required KeypointData hip,
      KeypointData? knee,
    }) {
      if (knee != null && knee.score > 0.20) {
        return _calculateAngle(shoulder, hip, knee);
      }
      // Half-body fallback: synthesize a horizontal knee point relative to hip
      final double dx = (hip.x >= shoulder.x) ? 0.35 : -0.35;
      final virtualKnee = KeypointData(
        type: JointType.leftKnee,
        x: hip.x + dx,
        y: hip.y,
        score: 1.0,
      );
      return _calculateAngle(shoulder, hip, virtualKnee);
    }

    double rawCrunchAngle = 140.0;
    if (hasLeftTorso && hasRightTorso) {
      final double leftAngle = calculateSideCrunchAngle(
        shoulder: leftShoulder,
        hip: leftHip,
        knee: hasLeftKnee ? leftKnee : null,
      );
      final double rightAngle = calculateSideCrunchAngle(
        shoulder: rightShoulder,
        hip: rightHip,
        knee: hasRightKnee ? rightKnee : null,
      );
      final double leftScore = leftShoulder.score + leftHip.score + (hasLeftKnee ? leftKnee.score : 0.5);
      final double rightScore = rightShoulder.score + rightHip.score + (hasRightKnee ? rightKnee.score : 0.5);

      rawCrunchAngle = (leftScore > rightScore + 0.3)
          ? leftAngle
          : (rightScore > leftScore + 0.3 ? rightAngle : (leftAngle + rightAngle) / 2.0);
    } else if (hasLeftTorso) {
      rawCrunchAngle = calculateSideCrunchAngle(
        shoulder: leftShoulder,
        hip: leftHip,
        knee: hasLeftKnee ? leftKnee : null,
      );
    } else if (rightShoulder != null && rightHip != null) {
      rawCrunchAngle = calculateSideCrunchAngle(
        shoulder: rightShoulder,
        hip: rightHip,
        knee: hasRightKnee ? rightKnee : null,
      );
    }

    // 1. Torso Elevation Metric (Vertical shoulder lift off floor relative to hip)
    double torsoLength = 0.30;
    double torsoElevation = 0.0;
    if (hasLeftTorso && hasRightTorso) {
      final avgShoulderX = (leftShoulder.x + rightShoulder.x) / 2.0;
      final avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2.0;
      final avgHipX = (leftHip.x + rightHip.x) / 2.0;
      final avgHipY = (leftHip.y + rightHip.y) / 2.0;
      torsoLength = math.max(0.10, math.sqrt(math.pow(avgShoulderX - avgHipX, 2) + math.pow(avgShoulderY - avgHipY, 2)));
      torsoElevation = ((avgHipY - avgShoulderY) / torsoLength).clamp(0.0, 1.0);
    } else if (hasLeftTorso) {
      torsoLength = math.max(0.10, math.sqrt(math.pow(leftShoulder.x - leftHip.x, 2) + math.pow(leftShoulder.y - leftHip.y, 2)));
      torsoElevation = ((leftHip.y - leftShoulder.y) / torsoLength).clamp(0.0, 1.0);
    } else if (rightShoulder != null && rightHip != null) {
      torsoLength = math.max(0.10, math.sqrt(math.pow(rightShoulder.x - rightHip.x, 2) + math.pow(rightShoulder.y - rightHip.y, 2)));
      torsoElevation = ((rightHip.y - rightShoulder.y) / torsoLength).clamp(0.0, 1.0);
    }

    final double smoothedElevation = _getSmoothedAngle('crunches_elevation', torsoElevation, alpha: 0.85);
    final double elevationProgress = ((smoothedElevation - 0.08) / (0.42 - 0.08)).clamp(0.0, 1.0);

    // 2. Spine Flexion Angle Metric
    // Apply EMA smoothing to prevent jitter / false counts from hand & leg motion
    final double crunchAngle = _getSmoothedAngle('crunches_angle', rawCrunchAngle, alpha: 0.85);

    final bool hasAnyKnee = hasLeftKnee || hasRightKnee;
    // Lying flat vs Peak crunch angles (adaptive for full body with bent knees vs half body with virtual knee)
    final double flatAngle = hasAnyKnee ? 138.0 : 175.0;
    final double peakCrunchAngle = hasAnyKnee ? 102.0 : 128.0;
    final double angleProgress = ((flatAngle - crunchAngle) / (flatAngle - peakCrunchAngle)).clamp(0.0, 1.0);

    // Dual-Metric Fusion: combines torso elevation lift and spine flexion
    final double rawProgress = math.max(angleProgress, elevationProgress);

    bool isFinished = false;
    String newFeedback = _feedback;
    final now = pose.timestamp > 0 ? pose.timestamp : DateTime.now().millisecondsSinceEpoch;

    if (_currentPhase == RepPhase.idle || _currentPhase == RepPhase.completed) {
      if (rawProgress >= 0.65 || crunchAngle <= (hasAnyKnee ? 112.0 : 142.0)) {
        _currentPhase = RepPhase.bottom;
        newFeedback = 'Peak crunch! Squeeze upper abs!';
      } else if (rawProgress >= 0.28) {
        _currentPhase = RepPhase.down;
        newFeedback = 'Curl shoulders up halfway toward knees...';
      }
    } else if (_currentPhase == RepPhase.down) {
      if (rawProgress >= 0.65 || crunchAngle <= (hasAnyKnee ? 112.0 : 142.0)) {
        _currentPhase = RepPhase.bottom;
        newFeedback = 'Peak crunch! Squeeze upper abs!';
      } else if (rawProgress < 0.15) {
        _currentPhase = RepPhase.idle;
      }
    } else if (_currentPhase == RepPhase.bottom) {
      if ((rawProgress <= 0.35 || crunchAngle >= (hasAnyKnee ? 125.0 : 155.0)) && now - _lastRepTime > _repCooldownMs) {
        _currentPhase = RepPhase.completed;
        isFinished = true;
        _lastRepTime = now;
        newFeedback = 'Crunch counted! Great core work!';
      } else if (rawProgress < 0.50) {
        _currentPhase = RepPhase.up;
        newFeedback = 'Lower torso smoothly toward the floor...';
      }
    } else if (_currentPhase == RepPhase.up) {
      if ((rawProgress <= 0.35 || crunchAngle >= (hasAnyKnee ? 125.0 : 155.0)) && now - _lastRepTime > _repCooldownMs) {
        _currentPhase = RepPhase.completed;
        isFinished = true;
        _lastRepTime = now;
        newFeedback = 'Crunch counted! Repeat movement!';
      }
    }

    // Full 2-Way Continuous Progress (0% -> 50% on curl up, 50% -> 100% on return down)
    double continuousProgress = 0.0;
    if (isFinished) {
      continuousProgress = 1.0;
    } else if (_currentPhase == RepPhase.idle || _currentPhase == RepPhase.down) {
      continuousProgress = rawProgress * 0.50;
    } else if (_currentPhase == RepPhase.bottom) {
      continuousProgress = 0.50;
    } else if (_currentPhase == RepPhase.up) {
      final double returnProgress = (1.0 - rawProgress).clamp(0.0, 1.0);
      continuousProgress = 0.50 + (returnProgress * 0.50);
    }

    _progress = continuousProgress;
    _feedback = newFeedback;

    if (isFinished) {
      _reps++;
      _registerRepTimestamp();
      if (enableAudio) {
        AudioCoachService().speakRep(_reps);
      }
      onRepCounted?.call(_reps);
    }

    return RepCounterResult(
      reps: _reps,
      phase: _currentPhase,
      progress: _progress,
      feedback: _feedback,
      isRepFinished: isFinished,
    );
  }

  RepCounterResult _processRopeSkipping(PoseData pose) {
    final leftAnkle = pose.getKeypoint(JointType.leftAnkle);
    final rightAnkle = pose.getKeypoint(JointType.rightAnkle);
    final leftHip = pose.getKeypoint(JointType.leftHip);
    final rightHip = pose.getKeypoint(JointType.rightHip);
    final leftShoulder = pose.getKeypoint(JointType.leftShoulder);
    final rightShoulder = pose.getKeypoint(JointType.rightShoulder);

    if (leftAnkle == null || rightAnkle == null) {
      return RepCounterResult(
        reps: _reps,
        phase: _currentPhase,
        progress: _progress,
        feedback: 'Frame full body & feet in camera view',
        isRepFinished: false,
      );
    }

    double torsoScale = 0.30;
    if (leftShoulder != null && rightShoulder != null && leftHip != null && rightHip != null) {
      torsoScale = _getTorsoScale(leftShoulder, rightShoulder, leftHip, rightHip);
    }

    final avgAnkleY = (leftAnkle.y + rightAnkle.y) / 2.0;

    // Track baseline floor level
    if (_standingHipY == 0.0 || (_currentPhase == RepPhase.idle && avgAnkleY > _standingHipY)) {
      _standingHipY = avgAnkleY;
    }

    // Vertical jump elevation
    final verticalJump = (_standingHipY - avgAnkleY).clamp(0.0, 0.25);
    final rawProgress = (verticalJump / (torsoScale * 0.20)).clamp(0.0, 1.0);

    bool isFinished = false;
    String newFeedback = _feedback;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_currentPhase == RepPhase.idle || _currentPhase == RepPhase.completed) {
      if (rawProgress >= 0.65) {
        _currentPhase = RepPhase.bottom;
        newFeedback = 'Hop peak! Land soft on toes!';
      } else if (rawProgress > 0.25) {
        _currentPhase = RepPhase.down;
        newFeedback = 'Bounce in rhythm!';
      }
    } else if (_currentPhase == RepPhase.down) {
      if (rawProgress >= 0.65) {
        _currentPhase = RepPhase.bottom;
        newFeedback = 'Hop peak! Land soft on toes!';
      }
    } else if (_currentPhase == RepPhase.bottom) {
      if (rawProgress <= 0.20 && now - _lastRepTime > 220) {
        _currentPhase = RepPhase.completed;
        isFinished = true;
        _lastRepTime = now;
        newFeedback = 'Great rhythm! Keep skipping!';
      } else if (rawProgress < 0.45) {
        _currentPhase = RepPhase.up;
      }
    } else if (_currentPhase == RepPhase.up) {
      if (rawProgress <= 0.20 && now - _lastRepTime > 220) {
        _currentPhase = RepPhase.completed;
        isFinished = true;
        _lastRepTime = now;
        newFeedback = 'Great rhythm! Keep skipping!';
      }
    }

    // Full 2-Way Continuous Progress (0% -> 50% on jump peak, 50% -> 100% on floor landing)
    double continuousProgress = 0.0;
    if (isFinished) {
      continuousProgress = 1.0;
    } else if (_currentPhase == RepPhase.idle || _currentPhase == RepPhase.down) {
      continuousProgress = rawProgress * 0.50;
    } else if (_currentPhase == RepPhase.bottom) {
      continuousProgress = 0.50;
    } else if (_currentPhase == RepPhase.up) {
      final double returnProgress = (1.0 - rawProgress).clamp(0.0, 1.0);
      continuousProgress = 0.50 + (returnProgress * 0.50);
    }

    _progress = continuousProgress;
    _feedback = newFeedback;

    if (isFinished) {
      _reps++;
      _registerRepTimestamp();
      if (enableAudio) {
        AudioCoachService().speakRep(_reps);
      }
      onRepCounted?.call(_reps);
    }

    return RepCounterResult(
      reps: _reps,
      phase: _currentPhase,
      progress: _progress,
      feedback: _feedback,
      isRepFinished: isFinished,
    );
  }

  void _registerRepTimestamp() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _repTimestamps.add(now);

    if (_formQuality == 'perfect' || _formQuality == 'good') {
      _formStreak++;
      if (_formStreak > _maxFormStreak) {
        _maxFormStreak = _formStreak;
      }
    } else {
      _formStreak = 0;
    }

    final cutoff = now - 20000;
    _repTimestamps.removeWhere((t) => t < cutoff);

    if (_repTimestamps.length >= 2) {
      final earliest = _repTimestamps.first;
      final windowMinutes = math.max((now - earliest) / 60000.0, 0.05);
      final computedCpm = (_repTimestamps.length / windowMinutes).round();
      _currentCpm = computedCpm;
      _bestCpm = math.max(_bestCpm, computedCpm);
    } else if (_reps > 0 && _seconds > 0) {
      final overallCpm = ((_reps / _seconds) * 60).round();
      _currentCpm = overallCpm;
      _bestCpm = math.max(_bestCpm, overallCpm);
    }
  }

  void _updateCpmDecay() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_repTimestamps.isNotEmpty) {
      final lastRep = _repTimestamps.last;
      if (now - lastRep > 4500 && _currentCpm > 0) {
        _currentCpm = math.max(0, (_currentCpm * 0.75).floor());
      }
    }
  }
}
