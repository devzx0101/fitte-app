import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class SkeletonPainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final double repProgress;
  final String formQuality;

  // Curated core body biomechanic joints only (no face/nose dot)
  static const List<PoseLandmarkType> _coreJoints = [
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftElbow,
    PoseLandmarkType.rightElbow,
    PoseLandmarkType.leftWrist,
    PoseLandmarkType.rightWrist,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
    PoseLandmarkType.leftKnee,
    PoseLandmarkType.rightKnee,
    PoseLandmarkType.leftAnkle,
    PoseLandmarkType.rightAnkle,
  ];

  SkeletonPainter({
    required this.poses,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
    this.repProgress = 0.0,
    this.formQuality = 'perfect',
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty) return;

    const Color limeGreen = Color(0xFFA3E635); // Electric lime (#A3E635)
    const Color neonGreen = Color(0xFF22C55E); // Electric green (#22C55E)
    final Color boneColor = repProgress > 0.65 ? limeGreen : neonGreen;

    final paintGlow = Paint()
      ..color = boneColor.withValues(alpha: 0.30)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintLine = Paint()
      ..color = boneColor
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintJointFill = Paint()
      ..color = limeGreen
      ..style = PaintingStyle.fill;

    final paintJointGlow = Paint()
      ..color = limeGreen.withValues(alpha: 0.40)
      ..style = PaintingStyle.fill;

    final paintJointRing = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    // Source dimensions from camera buffer (derived from exact ML Kit rotation)
    final bool isRotated90or270 =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    final double rawW = imageSize.width;
    final double rawH = imageSize.height;
    if (rawW <= 0 || rawH <= 0) return;

    // Visual dimensions after camera rotation
    final double previewW = isRotated90or270 ? rawH : rawW;
    final double previewH = isRotated90or270 ? rawW : rawH;

    // BoxFit.cover scaling and center crop offsets to match full-screen preview
    final double scale = max(size.width / previewW, size.height / previewH);
    final double offsetX = (size.width - previewW * scale) / 2;
    final double offsetY = (size.height - previewH * scale) / 2;

    // Direct 1:1 real-time landmark projection (zero lag, moves instantly with human body)
    Offset transformPoint(double rawX, double rawY) {
      double screenX;
      if (cameraLensDirection == CameraLensDirection.front) {
        screenX = (previewW - rawX) * scale + offsetX;
      } else {
        screenX = rawX * scale + offsetX;
      }
      final double screenY = rawY * scale + offsetY;
      return Offset(screenX, screenY);
    }

    final pose = poses.first;
    final Map<PoseLandmarkType, Offset> currentFramePoints = {};

    // 1. Calculate only the core body joints with verified confidence
    for (final type in _coreJoints) {
      final landmark = pose.landmarks[type];
      if (landmark != null && landmark.likelihood >= 0.35) {
        currentFramePoints[type] = transformPoint(landmark.x, landmark.y);
      }
    }

    // 2. Draw Connected Bones
    void drawBone(PoseLandmarkType type1, PoseLandmarkType type2) {
      final p1 = currentFramePoints[type1];
      final p2 = currentFramePoints[type2];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, paintGlow);
        canvas.drawLine(p1, p2, paintLine);
      }
    }

    // Torso Frame
    drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawBone(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawBone(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);

    // Left Arm
    drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawBone(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);

    // Right Arm
    drawBone(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawBone(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    // Left Leg
    drawBone(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawBone(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);

    // Right Leg
    drawBone(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawBone(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

    // 3. Draw Joint Nodes with Concentric Rings
    for (final entry in currentFramePoints.entries) {
      final pt = entry.value;
      canvas.drawCircle(pt, 8.0, paintJointGlow);
      canvas.drawCircle(pt, 4.0, paintJointFill);
      canvas.drawCircle(pt, 4.0, paintJointRing);
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) => true;
}
