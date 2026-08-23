import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/pose_model.dart';
import '../models/session_stats.dart';

/// Result from processing a camera frame: raw ML Kit data + our normalized PoseData
class PoseDetectionResult {
  final List<Pose> rawPoses;
  final PoseData poseData;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;

  const PoseDetectionResult({
    required this.rawPoses,
    required this.poseData,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
  });
}

class PoseDetectorService {
  late final PoseDetector _poseDetector;
  bool _isProcessing = false;

  PoseDetectorService() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  }

  Future<PoseDetectionResult?> processCameraImage(
    CameraImage image,
    CameraDescription camera, {
    DeviceOrientation deviceOrientation = DeviceOrientation.portraitUp,
  }) async {
    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      final rotation = _getImageRotation(camera, deviceOrientation);
      final inputImage = _convertCameraImageToInputImage(image, camera, rotation);
      if (inputImage == null) return null;

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isEmpty) return null;

      final firstPose = poses.first;
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final now = DateTime.now().millisecondsSinceEpoch;

      final isFrontCamera = camera.lensDirection == CameraLensDirection.front;
      final lensDirection = isFrontCamera
          ? CameraLensDirection.front
          : CameraLensDirection.back;

      return PoseDetectionResult(
        rawPoses: poses,
        poseData: PoseData.fromMLKitPose(
          firstPose,
          imageSize,
          now,
          rotation: rotation,
          isFrontCamera: isFrontCamera,
        ),
        imageSize: imageSize,
        rotation: rotation,
        lensDirection: lensDirection,
      );
    } catch (e) {
      debugPrint('Pose detection error: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  InputImageRotation _getImageRotation(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final sensorOrientation = camera.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;
    }

    int deviceDegrees = 0;
    switch (deviceOrientation) {
      case DeviceOrientation.portraitUp:
        deviceDegrees = 0;
        break;
      case DeviceOrientation.landscapeLeft:
        deviceDegrees = 90;
        break;
      case DeviceOrientation.portraitDown:
        deviceDegrees = 180;
        break;
      case DeviceOrientation.landscapeRight:
        deviceDegrees = 270;
        break;
    }

    int rotationCompensation;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + deviceDegrees) % 360;
    } else {
      rotationCompensation = (sensorOrientation - deviceDegrees + 360) % 360;
    }

    return InputImageRotationValue.fromRawValue(rotationCompensation) ??
        InputImageRotation.rotation0deg;
  }

  InputImage? _convertCameraImageToInputImage(
    CameraImage image,
    CameraDescription camera,
    InputImageRotation rotation,
  ) {
    InputImageFormat? format =
        InputImageFormatValue.fromRawValue(image.format.raw);
    if (Platform.isAndroid &&
        (format == null ||
            format == InputImageFormat.yuv420 ||
            format == InputImageFormat.yuv_420_888)) {
      format = InputImageFormat.nv21;
    } else if (Platform.isIOS && format == null) {
      format = InputImageFormat.bgra8888;
    }
    if (format == null || image.planes.isEmpty) return null;

    final Uint8List bytes;
    if (image.planes.length == 1) {
      bytes = image.planes.first.bytes;
    } else if (image.planes.length == 3 && format == InputImageFormat.nv21) {
      // Robust YUV_420_888 to NV21 conversion for Android Camera2 API
      final int width = image.width;
      final int height = image.height;
      final int ySize = width * height;
      final int uvSize = width * height ~/ 2;
      final Uint8List nv21 = Uint8List(ySize + uvSize);

      // Copy Y channel
      final Plane yPlane = image.planes[0];
      final int yRowStride = yPlane.bytesPerRow;
      if (yRowStride == width) {
        nv21.setRange(0, ySize, yPlane.bytes);
      } else {
        int yOffset = 0;
        for (int row = 0; row < height; row++) {
          final int rowStart = row * yRowStride;
          nv21.setRange(yOffset, yOffset + width, yPlane.bytes, rowStart);
          yOffset += width;
        }
      }

      // Interleave V and U channels for NV21
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

      int uvOffset = ySize;
      final int halfHeight = height ~/ 2;
      final int halfWidth = width ~/ 2;
      for (int row = 0; row < halfHeight; row++) {
        for (int col = 0; col < halfWidth; col++) {
          final int uIndex = row * uvRowStride + col * uvPixelStride;
          final int vIndex = row * vPlane.bytesPerRow + col * (vPlane.bytesPerPixel ?? 1);
          if (vIndex < vPlane.bytes.length && uIndex < uPlane.bytes.length) {
            nv21[uvOffset++] = vPlane.bytes[vIndex];
            nv21[uvOffset++] = uPlane.bytes[uIndex];
          }
        }
      }
      bytes = nv21;
    } else {
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      bytes = allBytes.done().buffer.asUint8List();
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  /// Simulated pose generator for testing and demo environments
  PoseData generateSimulatedPose(ExerciseType exercise, int elapsedTimeMs) {
    const cyclePeriodMs = 2400; // ~25 reps per minute
    final phase = (elapsedTimeMs % cyclePeriodMs) / cyclePeriodMs.toDouble();
    final sinFactor =
        (math.sin(phase * math.pi * 2 - math.pi / 2) + 1.0) / 2.0;

    const centerX = 0.5;
    const baseY = 0.2;

    List<KeypointData> keypoints = [];

    if (exercise == ExerciseType.squats) {
      final hipDrop = sinFactor * 0.14;
      final kneeBendX = sinFactor * 0.04;
      final chestDrop = sinFactor * 0.08;

      keypoints = [
        KeypointData(
            type: JointType.nose, x: centerX, y: baseY + chestDrop),
        KeypointData(
            type: JointType.leftShoulder,
            x: centerX - 0.12,
            y: baseY + 0.09 + chestDrop),
        KeypointData(
            type: JointType.rightShoulder,
            x: centerX + 0.12,
            y: baseY + 0.09 + chestDrop),
        KeypointData(
            type: JointType.leftElbow,
            x: centerX - 0.18,
            y: baseY + 0.20 + chestDrop),
        KeypointData(
            type: JointType.rightElbow,
            x: centerX + 0.18,
            y: baseY + 0.20 + chestDrop),
        KeypointData(
            type: JointType.leftWrist,
            x: centerX - 0.10,
            y: baseY + 0.18 + chestDrop),
        KeypointData(
            type: JointType.rightWrist,
            x: centerX + 0.10,
            y: baseY + 0.18 + chestDrop),
        KeypointData(
            type: JointType.leftHip,
            x: centerX - 0.08,
            y: baseY + 0.32 + hipDrop),
        KeypointData(
            type: JointType.rightHip,
            x: centerX + 0.08,
            y: baseY + 0.32 + hipDrop),
        KeypointData(
            type: JointType.leftKnee,
            x: centerX - 0.11 - kneeBendX,
            y: baseY + 0.48 + hipDrop * 0.5),
        KeypointData(
            type: JointType.rightKnee,
            x: centerX + 0.11 + kneeBendX,
            y: baseY + 0.48 + hipDrop * 0.5),
        const KeypointData(
            type: JointType.leftAnkle, x: centerX - 0.10, y: baseY + 0.68),
        const KeypointData(
            type: JointType.rightAnkle, x: centerX + 0.10, y: baseY + 0.68),
      ];
    } else if (exercise == ExerciseType.ropeSkipping) {
      const skipCyclePeriodMs = 600;
      final skipPhase = (elapsedTimeMs % skipCyclePeriodMs) / skipCyclePeriodMs.toDouble();
      final jumpFactor = (math.sin(skipPhase * math.pi * 2 - math.pi / 2) + 1.0) / 2.0;
      final bounceY = jumpFactor * 0.05;
      final wristCircleX = math.cos(skipPhase * math.pi * 2) * 0.03;
      final wristCircleY = math.sin(skipPhase * math.pi * 2) * 0.03;

      keypoints = [
        KeypointData(type: JointType.nose, x: centerX, y: baseY - bounceY),
        KeypointData(
            type: JointType.leftShoulder,
            x: centerX - 0.12,
            y: baseY + 0.09 - bounceY),
        KeypointData(
            type: JointType.rightShoulder,
            x: centerX + 0.12,
            y: baseY + 0.09 - bounceY),
        KeypointData(
            type: JointType.leftElbow,
            x: centerX - 0.18,
            y: baseY + 0.22 - bounceY),
        KeypointData(
            type: JointType.rightElbow,
            x: centerX + 0.18,
            y: baseY + 0.22 - bounceY),
        KeypointData(
            type: JointType.leftWrist,
            x: centerX - 0.22 + wristCircleX,
            y: baseY + 0.30 + wristCircleY - bounceY),
        KeypointData(
            type: JointType.rightWrist,
            x: centerX + 0.22 - wristCircleX,
            y: baseY + 0.30 + wristCircleY - bounceY),
        KeypointData(
            type: JointType.leftHip,
            x: centerX - 0.08,
            y: baseY + 0.32 - bounceY),
        KeypointData(
            type: JointType.rightHip,
            x: centerX + 0.08,
            y: baseY + 0.32 - bounceY),
        KeypointData(
            type: JointType.leftKnee,
            x: centerX - 0.09,
            y: baseY + 0.48 - bounceY),
        KeypointData(
            type: JointType.rightKnee,
            x: centerX + 0.09,
            y: baseY + 0.48 - bounceY),
        KeypointData(
            type: JointType.leftAnkle,
            x: centerX - 0.08,
            y: baseY + 0.68 - bounceY),
        KeypointData(
            type: JointType.rightAnkle,
            x: centerX + 0.08,
            y: baseY + 0.68 - bounceY),
      ];
    } else {
      final armSpread = sinFactor * 0.25;
      final legSpread = sinFactor * 0.15;

      keypoints = [
        const KeypointData(type: JointType.nose, x: centerX, y: baseY),
        const KeypointData(
            type: JointType.leftShoulder,
            x: centerX - 0.12,
            y: baseY + 0.09),
        const KeypointData(
            type: JointType.rightShoulder,
            x: centerX + 0.12,
            y: baseY + 0.09),
        KeypointData(
            type: JointType.leftElbow,
            x: centerX - 0.20 - armSpread,
            y: baseY + 0.15 - armSpread * 0.6),
        KeypointData(
            type: JointType.rightElbow,
            x: centerX + 0.20 + armSpread,
            y: baseY + 0.15 - armSpread * 0.6),
        KeypointData(
            type: JointType.leftWrist,
            x: centerX - 0.22 - armSpread * 1.2,
            y: baseY + 0.25 - armSpread * 1.3),
        KeypointData(
            type: JointType.rightWrist,
            x: centerX + 0.22 + armSpread * 1.2,
            y: baseY + 0.25 - armSpread * 1.3),
        const KeypointData(
            type: JointType.leftHip, x: centerX - 0.08, y: baseY + 0.32),
        const KeypointData(
            type: JointType.rightHip, x: centerX + 0.08, y: baseY + 0.32),
        KeypointData(
            type: JointType.leftKnee,
            x: centerX - 0.10 - legSpread * 0.5,
            y: baseY + 0.48),
        KeypointData(
            type: JointType.rightKnee,
            x: centerX + 0.10 + legSpread * 0.5,
            y: baseY + 0.48),
        KeypointData(
            type: JointType.leftAnkle,
            x: centerX - 0.10 - legSpread,
            y: baseY + 0.68),
        KeypointData(
            type: JointType.rightAnkle,
            x: centerX + 0.10 + legSpread,
            y: baseY + 0.68),
      ];
    }

    return PoseData(
      keypoints: keypoints,
      timestamp: elapsedTimeMs,
      score: 0.95,
    );
  }

  void dispose() {
    _poseDetector.close();
  }
}
