import 'dart:ui';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum JointType {
  nose,
  leftEye,
  rightEye,
  leftEar,
  rightEar,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

class KeypointData {
  final JointType type;
  final double x; // Normalized 0.0 to 1.0 (or pixel space)
  final double y; // Normalized 0.0 to 1.0 (or pixel space)
  final double score; // Confidence 0.0 to 1.0

  const KeypointData({
    required this.type,
    required this.x,
    required this.y,
    this.score = 1.0,
  });

  Offset toOffset(Size canvasSize) {
    return Offset(x * canvasSize.width, y * canvasSize.height);
  }
}

class BoneConnection {
  final JointType jointA;
  final JointType jointB;

  const BoneConnection(this.jointA, this.jointB);
}

class PoseData {
  final List<KeypointData> keypoints;
  final int timestamp;
  final double score;

  const PoseData({
    required this.keypoints,
    required this.timestamp,
    this.score = 1.0,
  });

  KeypointData? getKeypoint(JointType type) {
    for (final kp in keypoints) {
      if (kp.type == type) return kp;
    }
    return null;
  }

  // Convert Google ML Kit Pose into our normalized PoseData (True gravity-aligned coordinates)
  factory PoseData.fromMLKitPose(
    Pose pose,
    Size imageSize,
    int timestamp, {
    InputImageRotation rotation = InputImageRotation.rotation0deg,
    bool isFrontCamera = true,
  }) {
    final keypoints = <KeypointData>[];

    final landmarkMap = {
      PoseLandmarkType.nose: JointType.nose,
      PoseLandmarkType.leftEye: JointType.leftEye,
      PoseLandmarkType.rightEye: JointType.rightEye,
      PoseLandmarkType.leftEar: JointType.leftEar,
      PoseLandmarkType.rightEar: JointType.rightEar,
      PoseLandmarkType.leftShoulder: JointType.leftShoulder,
      PoseLandmarkType.rightShoulder: JointType.rightShoulder,
      PoseLandmarkType.leftElbow: JointType.leftElbow,
      PoseLandmarkType.rightElbow: JointType.rightElbow,
      PoseLandmarkType.leftWrist: JointType.leftWrist,
      PoseLandmarkType.rightWrist: JointType.rightWrist,
      PoseLandmarkType.leftHip: JointType.leftHip,
      PoseLandmarkType.rightHip: JointType.rightHip,
      PoseLandmarkType.leftKnee: JointType.leftKnee,
      PoseLandmarkType.rightKnee: JointType.rightKnee,
      PoseLandmarkType.leftAnkle: JointType.leftAnkle,
      PoseLandmarkType.rightAnkle: JointType.rightAnkle,
    };

    final bool isRotated90or270 =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    final double previewW = isRotated90or270 ? imageSize.height : imageSize.width;
    final double previewH = isRotated90or270 ? imageSize.width : imageSize.height;

    landmarkMap.forEach((mlType, jointType) {
      final landmark = pose.landmarks[mlType];
      if (landmark != null && previewW > 0 && previewH > 0) {
        double normX = landmark.x / previewW;
        double normY = landmark.y / previewH;

        // For front camera, mirror horizontal axis so user's visual reflection matches screen left/right
        if (isFrontCamera) {
          normX = 1.0 - normX;
        }

        keypoints.add(KeypointData(
          type: jointType,
          x: normX.clamp(0.0, 1.0),
          y: normY.clamp(0.0, 1.0),
          score: landmark.likelihood,
        ));
      }
    });

    return PoseData(
      keypoints: keypoints,
      timestamp: timestamp,
      score: 0.95,
    );
  }

  static const List<BoneConnection> bones = [
    // Torso
    BoneConnection(JointType.leftShoulder, JointType.rightShoulder),
    BoneConnection(JointType.leftShoulder, JointType.leftHip),
    BoneConnection(JointType.rightShoulder, JointType.rightHip),
    BoneConnection(JointType.leftHip, JointType.rightHip),

    // Head
    BoneConnection(JointType.nose, JointType.leftShoulder),
    BoneConnection(JointType.nose, JointType.rightShoulder),

    // Left Arm
    BoneConnection(JointType.leftShoulder, JointType.leftElbow),
    BoneConnection(JointType.leftElbow, JointType.leftWrist),

    // Right Arm
    BoneConnection(JointType.rightShoulder, JointType.rightElbow),
    BoneConnection(JointType.rightElbow, JointType.rightWrist),

    // Left Leg
    BoneConnection(JointType.leftHip, JointType.leftKnee),
    BoneConnection(JointType.leftKnee, JointType.leftAnkle),

    // Right Leg
    BoneConnection(JointType.rightHip, JointType.rightKnee),
    BoneConnection(JointType.rightKnee, JointType.rightAnkle),
  ];
}
