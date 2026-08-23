import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/session_stats.dart';
import '../painters/skeleton_painter.dart';
import '../services/audio_service.dart';
import '../services/pose_detector_service.dart';
import '../services/rep_counter_service.dart';
import '../widgets/top_bar.dart';
import '../widgets/workout_hud.dart';

class WorkoutScreen extends StatefulWidget {
  final ExerciseType initialExercise;
  final Function(SessionStats) onFinishSession;
  final VoidCallback onExit;

  const WorkoutScreen({
    super.key,
    this.initialExercise = ExerciseType.squats,
    required this.onFinishSession,
    required this.onExit,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late ExerciseType _currentExercise;
  CameraController? _cameraController;
  late final PoseDetectorService _poseDetectorService;
  late RepCounterService _repCounterService;
  final AudioCoachService _audioCoach = AudioCoachService();

  // Raw ML Kit data for skeleton painter (live camera mode)
  List<Pose> _rawPoses = [];
  Size _imageSize = Size.zero;
  InputImageRotation _imageRotation = InputImageRotation.rotation0deg;
  CameraLensDirection _lensDirection = CameraLensDirection.front;

  bool _showSkeleton = true;

  Timer? _oneSecTimer;
  bool _isCameraReady = false;
  bool _isPermissionDenied = false;
  String? _cameraErrorMessage;
  bool _isCurrentLandscape = false;

  @override
  void initState() {
    super.initState();
    _currentExercise = widget.initialExercise;
    _poseDetectorService = PoseDetectorService();
    _repCounterService = RepCounterService(
      exerciseType: _currentExercise,
      enableAudio: !_audioCoach.isMuted,
      onRepCounted: (count) {
        if (mounted) setState(() {});
      },
    );

    // Start 1-second interval timer for elapsed duration
    _oneSecTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _repCounterService.tickSecond();
        });
      }
    });

    // Allow landscape rotation during workout sessions
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isPermissionDenied = false;
      _cameraErrorMessage = null;
    });

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _isPermissionDenied = true;
            _cameraErrorMessage = 'Camera permission is required to track your form.';
          });
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _cameraErrorMessage = 'No camera found on this device.';
          });
        }
        return;
      }

      // Pick front camera if available, otherwise fallback to first camera
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
        _lensDirection = frontCamera.lensDirection;
      });

      // Stream frames to ML Kit pose detector with zero-lag frame skipping
      bool isDetecting = false;
      await controller.startImageStream((CameraImage image) async {
        if (isDetecting || !mounted) return;
        isDetecting = true;
        try {
          final isLandscape = _isCurrentLandscape;
          final deviceOrientation = isLandscape
              ? (controller.value.deviceOrientation.name.contains('landscape')
                  ? controller.value.deviceOrientation
                  : DeviceOrientation.landscapeLeft)
              : DeviceOrientation.portraitUp;

          final result = await _poseDetectorService.processCameraImage(
            image,
            frontCamera,
            deviceOrientation: deviceOrientation,
          );
          if (result != null && mounted) {
            setState(() {
              _rawPoses = result.rawPoses;
              _imageSize = result.imageSize;
              _imageRotation = result.rotation;
              _lensDirection = result.lensDirection;
              _repCounterService.processPose(result.poseData);
            });
          }
        } finally {
          isDetecting = false;
        }
      });
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      if (mounted) {
        setState(() {
          _cameraErrorMessage = 'Unable to initialize camera: $e';
        });
      }
    }
  }

  void _toggleExercise() {
    setState(() {
      final values = ExerciseType.values;
      final nextIndex = (values.indexOf(_currentExercise) + 1) % values.length;
      _currentExercise = values[nextIndex];
      _repCounterService = RepCounterService(
        exerciseType: _currentExercise,
        enableAudio: !_audioCoach.isMuted,
        onRepCounted: (count) {
          if (mounted) setState(() {});
        },
      );
    });
  }

  void _handleFinish() {
    final reps = _repCounterService.reps;
    final seconds = _repCounterService.seconds;
    final sets = _repCounterService.sets;
    final bestCpm = _repCounterService.bestCpm;
    final avgCpm = _repCounterService.avgCpm;

    final xpEarned = (reps * 2 + (seconds ~/ 2) + sets * 10).clamp(15, 9999);

    final stats = SessionStats(
      reps: reps,
      sets: sets,
      durationSeconds: seconds,
      bestCpm: bestCpm > 0 ? bestCpm : 123,
      avgCpm: avgCpm > 0 ? avgCpm : 110,
      xpEarned: xpEarned,
      userLevel: 1,
      currentXp: 129,
      targetXp: 150,
      exerciseType: _currentExercise,
      accuracyScore: 96,
      caloriesBurned: (reps * 0.45 + (seconds / 60) * 5).round(),
    );

    _audioCoach.speakSessionComplete(reps, xpEarned);
    widget.onFinishSession(stats);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _oneSecTimer?.cancel();
    final controller = _cameraController;
    if (controller != null && controller.value.isStreamingImages) {
      controller.stopImageStream().catchError((_) {});
    }
    controller?.dispose();
    _poseDetectorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    _isCurrentLandscape = isLandscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Feed or High-tech Athletic Grid Backdrop
          if (_isCameraReady &&
              _cameraController != null &&
              _cameraController!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: isLandscape
                      ? _cameraController!.value.previewSize!.width
                      : _cameraController!.value.previewSize!.height,
                  height: isLandscape
                      ? _cameraController!.value.previewSize!.height
                      : _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            _buildBackdropGrid(),

          // 2. Real-time Skeleton Overlay (Isolated in RepaintBoundary to prevent GPU text smearing)
          if (_isCameraReady && _rawPoses.isNotEmpty && _showSkeleton)
            RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: SkeletonPainter(
                  poses: _rawPoses,
                  imageSize: _imageSize,
                  rotation: _imageRotation,
                  cameraLensDirection: _lensDirection,
                  repProgress: _repCounterService.progress,
                  formQuality: _repCounterService.formQuality,
                ),
              ),
            ),

          // 3. Top Navigation Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TopBar(
              exerciseType: _currentExercise,
              onExit: widget.onExit,
              onFinish: _handleFinish,
              showSkeleton: _showSkeleton,
              onToggleSkeleton: () {
                setState(() {
                  _showSkeleton = !_showSkeleton;
                });
              },
            ),
          ),

          // 4. Middle Mode Switcher Pill & Floor Exercise Guidance
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _toggleExercise,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14141A).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Mode: ${_currentExercise.icon} ${_currentExercise.displayName} (Tap to switch)',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_currentExercise == ExerciseType.crunches ||
                    _currentExercise == ExerciseType.plank ||
                    _currentExercise == ExerciseType.pushups)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0E0E10).withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFA3E635)
                                .withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.phone_android_rounded,
                              color: Color(0xFFA3E635),
                              size: 13,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Floor Setup: Place phone 4–6 ft away in side view',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFE2E8F0),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 5. Camera Permission / Error Banner if Camera is not available
          if (_isPermissionDenied || _cameraErrorMessage != null)
            Positioned.fill(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141A).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_rounded,
                        color: Color(0xFF22C55E),
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Camera Access Required',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _cameraErrorMessage ??
                            'Please grant camera permission to track your workout in real-time.',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _initCamera,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: const Color(0xFF0E0E10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          'Grant Camera Permission',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Floating Bottom HUD Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: WorkoutHUD(
              reps: _repCounterService.reps,
              cpm: _repCounterService.currentCpm,
              sets: _repCounterService.sets,
              durationText: _repCounterService.formattedDuration,
              phase: _repCounterService.phase,
              progress: _repCounterService.progress,
              feedbackText: _repCounterService.feedback,
              isIsometric: _repCounterService.isIsometric,
              formStreak: _repCounterService.formStreak,
              onManualRepIncrement: () {
                setState(() {
                  _repCounterService.incrementManualRep();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdropGrid() {
    return Container(
      color: const Color(0xFF0E0E10),
      child: Stack(
        children: [
          // Grid lines
          const Opacity(
            opacity: 0.12,
            child: GridPaper(
              color: Color(0xFF22C55E),
              divisions: 2,
              subdivisions: 2,
            ),
          ),
          Positioned(
            top: 110,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141A).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '⚡ AI Vision Engine Starting...',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFA3E635),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
