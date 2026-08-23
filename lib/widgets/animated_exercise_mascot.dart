import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/session_stats.dart';

/// Renders a dynamic, smoothly animated athletic vector mascot for each exercise
class AnimatedExerciseMascot extends StatefulWidget {
  final ExerciseType exerciseType;
  final double size;
  final Color primaryColor;
  final Color? backgroundColor;

  const AnimatedExerciseMascot({
    super.key,
    required this.exerciseType,
    this.size = 58.0,
    this.primaryColor = const Color(0xFF16A34A),
    this.backgroundColor,
  });

  @override
  State<AnimatedExerciseMascot> createState() => _AnimatedExerciseMascotState();
}

class _AnimatedExerciseMascotState extends State<AnimatedExerciseMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? const Color(0xFFF1F5F9);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _MascotPainter(
              exerciseType: widget.exerciseType,
              progress: _controller.value,
              primaryColor: widget.primaryColor,
            ),
          );
        },
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final ExerciseType exerciseType;
  final double progress; // 0.0 to 1.0
  final Color primaryColor;

  _MascotPainter({
    required this.exerciseType,
    required this.progress,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Smooth sinusoidal motion cycle: 0 -> 1 -> 0
    final cycle = (math.sin(progress * 2 * math.pi - (math.pi / 2)) + 1.0) / 2.0;

    final paintMat = Paint()
      ..color = primaryColor.withValues(alpha: 0.40)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final paintTorso = Paint()
      ..color = const Color(0xFF0284C7) // Athletic Cyan Top
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final paintShorts = Paint()
      ..color = const Color(0xFF1E293B) // Slate Shorts
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final paintSkin = Paint()
      ..color = const Color(0xFFFDBA74) // Warm peach skin tone
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final paintHead = Paint()
      ..color = const Color(0xFFFDBA74)
      ..style = PaintingStyle.fill;

    final paintHair = Paint()
      ..color = const Color(0xFF92400E) // Cap / Hair
      ..style = PaintingStyle.fill;

    switch (exerciseType) {
      case ExerciseType.pushups:
        // Floor Mat
        canvas.drawLine(Offset(w * 0.10, h * 0.75), Offset(w * 0.90, h * 0.75), paintMat);

        final depth = cycle * (h * 0.16); // pushup depth
        final headPos = Offset(w * 0.80, h * 0.46 + depth);
        final shoulderPos = Offset(w * 0.70, h * 0.50 + depth);
        final hipPos = Offset(w * 0.40, h * 0.56 + depth * 0.4);
        final feetPos = Offset(w * 0.20, h * 0.72);
        final handPos = Offset(w * 0.68, h * 0.73);
        final elbowPos = Offset(
          shoulderPos.dx - 4 + (cycle * 5),
          shoulderPos.dy + (handPos.dy - shoulderPos.dy) * 0.55,
        );

        // Body & Legs
        canvas.drawLine(feetPos, hipPos, paintShorts);
        canvas.drawLine(hipPos, shoulderPos, paintTorso);

        // Arms
        canvas.drawLine(shoulderPos, elbowPos, paintSkin);
        canvas.drawLine(elbowPos, handPos, paintSkin);

        // Head
        canvas.drawCircle(headPos, 4.5, paintHead);
        canvas.drawArc(
          Rect.fromCircle(center: headPos, radius: 4.5),
          math.pi * 0.8,
          math.pi * 1.0,
          true,
          paintHair,
        );
        break;

      case ExerciseType.crunches:
        // Floor Mat
        canvas.drawLine(Offset(w * 0.12, h * 0.76), Offset(w * 0.88, h * 0.76), paintMat);

        final curl = cycle * (h * 0.18); // crunch curl height
        final hipPos = Offset(w * 0.48, h * 0.73);
        final kneePos = Offset(w * 0.68, h * 0.52);
        final feetPos = Offset(w * 0.78, h * 0.73);

        final shoulderPos = Offset(w * 0.30 + (curl * 0.4), h * 0.72 - curl);
        final headPos = Offset(shoulderPos.dx - 8, shoulderPos.dy - 6);
        final handPos = Offset(shoulderPos.dx + 12 + (curl * 0.6), shoulderPos.dy - 4);

        // Legs (bent knees)
        canvas.drawLine(hipPos, kneePos, paintShorts);
        canvas.drawLine(kneePos, feetPos, paintSkin);

        // Torso curling up
        canvas.drawLine(hipPos, shoulderPos, paintTorso);

        // Arms reaching toward knees
        canvas.drawLine(shoulderPos, handPos, paintSkin);

        // Head
        canvas.drawCircle(headPos, 4.5, paintHead);
        canvas.drawArc(
          Rect.fromCircle(center: headPos, radius: 4.5),
          math.pi * 0.2,
          math.pi * 1.0,
          true,
          paintHair,
        );
        break;

      case ExerciseType.squats:
        final drop = cycle * (h * 0.20);
        final headPos = Offset(w * 0.50, h * 0.22 + drop);
        final shoulderPos = Offset(w * 0.50, h * 0.32 + drop);
        final hipPos = Offset(w * 0.46 - (drop * 0.2), h * 0.52 + drop);
        final kneePos = Offset(w * 0.56 + (drop * 0.1), h * 0.68 + (drop * 0.4));
        final feetPos = Offset(w * 0.52, h * 0.86);

        final handPos = Offset(w * 0.72, h * 0.42 + drop);

        // Legs
        canvas.drawLine(hipPos, kneePos, paintShorts);
        canvas.drawLine(kneePos, feetPos, paintSkin);

        // Torso
        canvas.drawLine(hipPos, shoulderPos, paintTorso);

        // Arms out for balance
        canvas.drawLine(shoulderPos, handPos, paintSkin);

        // Head
        canvas.drawCircle(headPos, 4.8, paintHead);
        canvas.drawArc(
          Rect.fromCircle(center: headPos, radius: 4.8),
          math.pi * 1.0,
          math.pi * 1.0,
          true,
          paintHair,
        );
        break;

      case ExerciseType.plank:
        // Floor Mat
        canvas.drawLine(Offset(w * 0.10, h * 0.75), Offset(w * 0.90, h * 0.75), paintMat);

        final breathe = math.sin(progress * 4 * math.pi) * 1.5;
        final headPos = Offset(w * 0.78, h * 0.50 + breathe);
        final shoulderPos = Offset(w * 0.68, h * 0.54 + breathe);
        final hipPos = Offset(w * 0.42, h * 0.58 + breathe);
        final feetPos = Offset(w * 0.20, h * 0.73);
        final elbowPos = Offset(w * 0.68, h * 0.73);

        // Body straight line
        canvas.drawLine(feetPos, hipPos, paintShorts);
        canvas.drawLine(hipPos, shoulderPos, paintTorso);

        // Forearm on floor
        canvas.drawLine(shoulderPos, elbowPos, paintSkin);
        canvas.drawLine(elbowPos, Offset(elbowPos.dx + 8, elbowPos.dy), paintSkin);

        // Head
        canvas.drawCircle(headPos, 4.5, paintHead);
        canvas.drawArc(
          Rect.fromCircle(center: headPos, radius: 4.5),
          math.pi * 0.8,
          math.pi * 1.0,
          true,
          paintHair,
        );
        break;

      case ExerciseType.jumpingJacks:
        final spread = cycle;
        final headPos = Offset(w * 0.50, h * 0.20 + (cycle * 2.0));
        final shoulderPos = Offset(w * 0.50, h * 0.30 + (cycle * 2.0));
        final hipPos = Offset(w * 0.50, h * 0.52 + (cycle * 2.0));

        final leftFoot = Offset(w * 0.50 - (6 + spread * 14), h * 0.84);
        final rightFoot = Offset(w * 0.50 + (6 + spread * 14), h * 0.84);

        final leftHand = Offset(w * 0.50 - (10 + spread * 14), h * 0.50 - (spread * 22));
        final rightHand = Offset(w * 0.50 + (10 + spread * 14), h * 0.50 - (spread * 22));

        // Legs
        canvas.drawLine(hipPos, leftFoot, paintShorts);
        canvas.drawLine(hipPos, rightFoot, paintShorts);

        // Torso
        canvas.drawLine(hipPos, shoulderPos, paintTorso);

        // Arms
        canvas.drawLine(shoulderPos, leftHand, paintSkin);
        canvas.drawLine(shoulderPos, rightHand, paintSkin);

        // Head
        canvas.drawCircle(headPos, 4.8, paintHead);
        canvas.drawArc(
          Rect.fromCircle(center: headPos, radius: 4.8),
          math.pi * 1.0,
          math.pi * 1.0,
          true,
          paintHair,
        );
        break;

      case ExerciseType.lunges:
        final drop = cycle * (h * 0.16);
        final headPos = Offset(w * 0.48, h * 0.24 + drop);
        final shoulderPos = Offset(w * 0.48, h * 0.34 + drop);
        final hipPos = Offset(w * 0.46, h * 0.54 + drop);

        final frontKnee = Offset(w * 0.66, h * 0.66 + drop * 0.5);
        final frontFoot = Offset(w * 0.66, h * 0.84);

        final backKnee = Offset(w * 0.28, h * 0.70 + drop);
        final backFoot = Offset(w * 0.20, h * 0.84);

        // Front & Back Legs
        canvas.drawLine(hipPos, frontKnee, paintShorts);
        canvas.drawLine(frontKnee, frontFoot, paintSkin);
        canvas.drawLine(hipPos, backKnee, paintShorts);
        canvas.drawLine(backKnee, backFoot, paintSkin);

        // Torso
        canvas.drawLine(hipPos, shoulderPos, paintTorso);

        // Hands on hips
        canvas.drawLine(shoulderPos, Offset(w * 0.44, h * 0.46 + drop), paintSkin);

        // Head
        canvas.drawCircle(headPos, 4.8, paintHead);
        canvas.drawArc(
          Rect.fromCircle(center: headPos, radius: 4.8),
          math.pi * 0.9,
          math.pi * 1.0,
          true,
          paintHair,
        );
        break;

      case ExerciseType.highKnees:
        final alt = math.sin(progress * 2 * math.pi);
        final leftUp = alt > 0;
        final kneeHeight = alt.abs() * (h * 0.18);

        final headPos = Offset(w * 0.50, h * 0.22);
        final shoulderPos = Offset(w * 0.50, h * 0.32);
        final hipPos = Offset(w * 0.50, h * 0.54);

        final leftKnee = Offset(w * 0.42, leftUp ? h * 0.64 - kneeHeight : h * 0.68);
        final leftFoot = Offset(w * 0.42, leftUp ? h * 0.76 - kneeHeight : h * 0.84);

        final rightKnee = Offset(w * 0.58, !leftUp ? h * 0.64 - kneeHeight : h * 0.68);
        final rightFoot = Offset(w * 0.58, !leftUp ? h * 0.76 - kneeHeight : h * 0.84);

        // Legs
        canvas.drawLine(hipPos, leftKnee, paintShorts);
        canvas.drawLine(leftKnee, leftFoot, paintSkin);
        canvas.drawLine(hipPos, rightKnee, paintShorts);
        canvas.drawLine(rightKnee, rightFoot, paintSkin);

        // Torso
        canvas.drawLine(hipPos, shoulderPos, paintTorso);

        // Running Arms
        canvas.drawLine(shoulderPos, Offset(w * 0.36, leftUp ? h * 0.46 : h * 0.38), paintSkin);
        canvas.drawLine(shoulderPos, Offset(w * 0.64, leftUp ? h * 0.38 : h * 0.46), paintSkin);

        // Head
        canvas.drawCircle(headPos, 4.8, paintHead);
        canvas.drawArc(
          Rect.fromCircle(center: headPos, radius: 4.8),
          math.pi * 1.0,
          math.pi * 1.0,
          true,
          paintHair,
        );
        break;

      case ExerciseType.ropeSkipping:
        final hop = math.sin(progress * 2 * math.pi).abs() * (h * 0.12);
        final headPos = Offset(w * 0.50, h * 0.22 - hop);
        final shoulderPos = Offset(w * 0.50, h * 0.32 - hop);
        final hipPos = Offset(w * 0.50, h * 0.52 - hop);
        final feetPos = Offset(w * 0.50, h * 0.82 - hop);

        // Body
        canvas.drawLine(hipPos, feetPos, paintShorts);
        canvas.drawLine(hipPos, shoulderPos, paintTorso);

        // Hands & Skipping Rope Arc
        final leftHand = Offset(w * 0.34, h * 0.48 - hop);
        final rightHand = Offset(w * 0.66, h * 0.48 - hop);
        canvas.drawLine(shoulderPos, leftHand, paintSkin);
        canvas.drawLine(shoulderPos, rightHand, paintSkin);

        final ropePath = Path()
          ..moveTo(leftHand.dx, leftHand.dy)
          ..quadraticBezierTo(w * 0.50, h * 0.88 - hop * 0.5, rightHand.dx, rightHand.dy);
        canvas.drawPath(
          ropePath,
          Paint()
            ..color = const Color(0xFF16A34A)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );

        // Head
        canvas.drawCircle(headPos, 4.8, paintHead);
        canvas.drawArc(
          Rect.fromCircle(center: headPos, radius: 4.8),
          math.pi * 1.0,
          math.pi * 1.0,
          true,
          paintHair,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.exerciseType != exerciseType ||
        oldDelegate.primaryColor != primaryColor;
  }
}
