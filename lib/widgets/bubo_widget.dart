import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum BuboMood {
  happy,       // ^ ‿ ^ (Home Screen companion)
  watching,    // • _ • (Camera HUD detecting movement)
  correct,     // ^ ‿ ^ (Good rep)
  warning,     // > _ < (Form correction)
  fireStreak,  // ★ ‿ ★ (5-rep combo / streak on fire)
  celebrate,   // ★ o ★ (Summary screen victory with confetti)
  levelUp,     // ⚡ ‿ ⚡ (XP milestone)
}

enum BuboRole {
  companion,   // Home Screen hero
  coach,       // Workout Camera HUD (compact 40-52px)
  celebrator,  // Result screen (large 120-160px)
}

class BuboWidget extends StatefulWidget {
  final BuboMood mood;
  final BuboRole role;
  final double size;
  final String? speechText;
  final bool showSpeechBubble;
  final bool isAnimated;

  const BuboWidget({
    super.key,
    this.mood = BuboMood.happy,
    this.role = BuboRole.companion,
    this.size = 100,
    this.speechText,
    this.showSpeechBubble = false,
    this.isAnimated = true,
  });

  @override
  State<BuboWidget> createState() => _BuboWidgetState();
}

class _BuboWidgetState extends State<BuboWidget>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final AnimationController _blinkController;
  late final Animation<double> _idleAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    _idleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOutSine,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOutSine,
      ),
    );

    // Natural Eye Blink Curve (92% fully open, quick 8% blink closure & reopen)
    _blinkAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 90),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.06).chain(CurveTween(curve: Curves.easeInQuad)), weight: 5),
      TweenSequenceItem(tween: Tween<double>(begin: 0.06, end: 1.0).chain(CurveTween(curve: Curves.easeOutQuad)), weight: 5),
    ]).animate(_blinkController);

    if (widget.isAnimated) {
      _animController.repeat(reverse: true);
      _blinkController.repeat();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buboSize = widget.size;

    return ListenableBuilder(
      listenable: Listenable.merge([_animController, _blinkController]),
      builder: (context, child) {
        final idle = widget.isAnimated ? _idleAnimation.value : 0.5;
        final glow = widget.isAnimated ? _glowAnimation.value : 0.8;
        final blink = widget.isAnimated ? _blinkAnimation.value : 1.0;

        Widget buboAvatar = CustomPaint(
          size: Size(buboSize, buboSize * 1.15),
          painter: _BuboPainter(
            mood: widget.mood,
            glowIntensity: glow,
            blinkProgress: blink,
            idleProgress: idle,
          ),
        );

        if (widget.showSpeechBubble && widget.speechText != null) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              buboAvatar,
              const SizedBox(width: 8),
              Flexible(
                child: DuolingoSpeechBubble(text: widget.speechText!),
              ),
            ],
          );
        }

        return buboAvatar;
      },
    );
  }
}

/// Duolingo-style Speech Bubble with a sleek pointer tail pointing at the mascot
class DuolingoSpeechBubble extends StatelessWidget {
  final String text;

  const DuolingoSpeechBubble({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DuolingoBubblePainter(
        backgroundColor: const Color(0xFF0F172A),
        borderColor: const Color(0xFF334155),
      ),
      child: Container(
        padding: const EdgeInsets.only(left: 20, right: 16, top: 14, bottom: 14),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            color: const Color(0xFFF8FAFC),
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _DuolingoBubblePainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;

  _DuolingoBubblePainter({
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double tailWidth = 9.0;
    const double tailHeight = 13.0;
    const double radius = 18.0;

    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tailWidth, 0, size.width - tailWidth, size.height),
      const Radius.circular(radius),
    );

    final path = Path()..addRRect(bubbleRect);

    // Left-pointing speech tail (aligned with mascot mouth/visor)
    final double tailCenterY = size.height * 0.48;
    final tailPath = Path()
      ..moveTo(tailWidth + 0.5, tailCenterY - tailHeight / 2)
      ..lineTo(0, tailCenterY)
      ..lineTo(tailWidth + 0.5, tailCenterY + tailHeight / 2)
      ..close();

    final combinedPath = Path.combine(PathOperation.union, path, tailPath);

    // Soft elevation shadow
    canvas.drawShadow(combinedPath, Colors.black.withValues(alpha: 0.18), 10, false);

    // Fill
    final paintFill = Paint()..color = backgroundColor;
    canvas.drawPath(combinedPath, paintFill);

    // Border
    final paintStroke = Paint()
      ..color = borderColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawPath(combinedPath, paintStroke);
  }

  @override
  bool shouldRepaint(covariant _DuolingoBubblePainter oldDelegate) =>
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.borderColor != borderColor;
}

class _BuboPainter extends CustomPainter {
  final BuboMood mood;
  final double glowIntensity;
  final double blinkProgress;
  final double idleProgress;

  _BuboPainter({
    required this.mood,
    required this.glowIntensity,
    this.blinkProgress = 1.0,
    this.idleProgress = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Palette tokens
    const Color mintColor = Color(0xFF00E0C7);       // Primary Cyber Mint Body (#00E0C7)
    const Color mintShadow = Color(0xFF00A896);      // Shaded Mint Base
    const Color electricLime = Color(0xFFB6FF3B);    // Electric Lime Energy Sprout (#B6FF3B)

    // 1. Sprout Flame (Top signature energy antenna)
    final sproutPaint = Paint()
      ..color = electricLime
      ..style = PaintingStyle.fill;

    final sproutGlow = Paint()
      ..color = electricLime.withValues(alpha: 0.35 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final sproutPath = Path();
    final sproutBaseX = w * 0.50;
    final sproutBaseY = h * 0.22;
    final sproutTipX = w * 0.52 + (idleProgress - 0.5) * w * 0.04;
    final sproutTipY = h * 0.04;

    sproutPath.moveTo(sproutBaseX - w * 0.08, sproutBaseY);
    sproutPath.quadraticBezierTo(
      sproutBaseX - w * 0.02,
      sproutBaseY - h * 0.10,
      sproutTipX,
      sproutTipY,
    );
    sproutPath.quadraticBezierTo(
      sproutBaseX + w * 0.12,
      sproutBaseY - h * 0.06,
      sproutBaseX + w * 0.08,
      sproutBaseY,
    );
    sproutPath.close();

    canvas.drawPath(sproutPath, sproutGlow);
    canvas.drawPath(sproutPath, sproutPaint);

    // 2. Athletic Runner Feet & Grip Soles
    final footPaint = Paint()
      ..color = mintShadow
      ..style = PaintingStyle.fill;

    final footSolePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final limeGripPaint = Paint()
      ..color = electricLime
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Left Foot
    final leftFootRect = Rect.fromCenter(
      center: Offset(w * 0.35, h * 0.94),
      width: w * 0.24,
      height: h * 0.13,
    );
    canvas.drawOval(leftFootRect, footPaint);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.35, h * 0.97),
        width: w * 0.20,
        height: h * 0.05,
      ),
      footSolePaint,
    );
    canvas.drawLine(
      Offset(w * 0.28, h * 0.97),
      Offset(w * 0.42, h * 0.97),
      limeGripPaint,
    );

    // Right Foot
    final rightFootRect = Rect.fromCenter(
      center: Offset(w * 0.65, h * 0.94),
      width: w * 0.24,
      height: h * 0.13,
    );
    canvas.drawOval(rightFootRect, footPaint);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.65, h * 0.97),
        width: w * 0.20,
        height: h * 0.05,
      ),
      footSolePaint,
    );
    canvas.drawLine(
      Offset(w * 0.58, h * 0.97),
      Offset(w * 0.72, h * 0.97),
      limeGripPaint,
    );

    // 3. Main Bean/Droplet Body
    final bodyRect = Rect.fromLTWH(w * 0.10, h * 0.16, w * 0.80, h * 0.78);
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [mintColor, mintShadow],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(bodyRect);

    final bodyGlow = Paint()
      ..color = mintColor.withValues(alpha: 0.20 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final bodyRRect = RRect.fromRectAndCorners(
      bodyRect,
      topLeft: Radius.circular(w * 0.40),
      topRight: Radius.circular(w * 0.40),
      bottomLeft: Radius.circular(w * 0.35),
      bottomRight: Radius.circular(w * 0.35),
    );

    canvas.drawRRect(bodyRRect, bodyGlow);
    canvas.drawRRect(bodyRRect, bodyPaint);

    // 4. Athletic Compression Shorts / Waistband (Sporty fit)
    final shortsRect = Rect.fromLTWH(w * 0.14, h * 0.74, w * 0.72, h * 0.20);
    final shortsPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    final shortsRRect = RRect.fromRectAndCorners(
      shortsRect,
      bottomLeft: Radius.circular(w * 0.32),
      bottomRight: Radius.circular(w * 0.32),
      topLeft: Radius.circular(w * 0.08),
      topRight: Radius.circular(w * 0.08),
    );
    canvas.drawRRect(shortsRRect, shortsPaint);

    // Neon athletic racing trim on shorts
    final stripePaint = Paint()
      ..color = electricLime
      ..strokeWidth = w * 0.025
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(w * 0.22, h * 0.76),
      Offset(w * 0.22, h * 0.88),
      stripePaint,
    );
    canvas.drawLine(
      Offset(w * 0.78, h * 0.76),
      Offset(w * 0.78, h * 0.88),
      stripePaint,
    );

    // 5. Tiny Stubby Arms + Curved Round Athletic Wristbands
    final armPaint = Paint()
      ..color = mintColor
      ..style = PaintingStyle.fill;

    final wristbandPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final wristbandLimeStripe = Paint()
      ..color = electricLime
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final armOffsetY = (idleProgress - 0.5) * h * 0.015;

    // Left Arm
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.10, h * 0.58 + armOffsetY),
        width: w * 0.16,
        height: h * 0.22,
      ),
      armPaint,
    );
    // Left Round Wristband Wrap
    final leftWristPath = Path()
      ..moveTo(w * 0.03, h * 0.58 + armOffsetY)
      ..quadraticBezierTo(w * 0.10, h * 0.61 + armOffsetY, w * 0.17, h * 0.58 + armOffsetY)
      ..lineTo(w * 0.17, h * 0.66 + armOffsetY)
      ..quadraticBezierTo(w * 0.10, h * 0.69 + armOffsetY, w * 0.03, h * 0.66 + armOffsetY)
      ..close();
    canvas.drawPath(leftWristPath, wristbandPaint);

    final leftWristStripe = Path()
      ..moveTo(w * 0.04, h * 0.625 + armOffsetY)
      ..quadraticBezierTo(w * 0.10, h * 0.65 + armOffsetY, w * 0.16, h * 0.625 + armOffsetY);
    canvas.drawPath(leftWristStripe, wristbandLimeStripe);

    // Right Arm
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.90, h * 0.58 - armOffsetY),
        width: w * 0.16,
        height: h * 0.22,
      ),
      armPaint,
    );
    // Right Round Wristband Wrap
    final rightWristPath = Path()
      ..moveTo(w * 0.83, h * 0.58 - armOffsetY)
      ..quadraticBezierTo(w * 0.90, h * 0.61 - armOffsetY, w * 0.97, h * 0.58 - armOffsetY)
      ..lineTo(w * 0.97, h * 0.66 - armOffsetY)
      ..quadraticBezierTo(w * 0.90, h * 0.69 - armOffsetY, w * 0.83, h * 0.66 - armOffsetY)
      ..close();
    canvas.drawPath(rightWristPath, wristbandPaint);

    final rightWristStripe = Path()
      ..moveTo(w * 0.84, h * 0.625 - armOffsetY)
      ..quadraticBezierTo(w * 0.90, h * 0.65 - armOffsetY, w * 0.96, h * 0.625 - armOffsetY);
    canvas.drawPath(rightWristStripe, wristbandLimeStripe);

    // 6. Athletic Round Wrap-Around Headband (Positioned high on forehead)
    final headbandPath = Path()
      ..moveTo(w * 0.12, h * 0.20)
      ..quadraticBezierTo(w * 0.50, h * 0.25, w * 0.88, h * 0.20)
      ..quadraticBezierTo(w * 0.90, h * 0.28, w * 0.88, h * 0.32)
      ..quadraticBezierTo(w * 0.50, h * 0.37, w * 0.12, h * 0.32)
      ..quadraticBezierTo(w * 0.10, h * 0.28, w * 0.12, h * 0.20)
      ..close();

    final headbandPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final headbandBorder = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(headbandPath, headbandPaint);
    canvas.drawPath(headbandPath, headbandBorder);

    // Dual Lime Racing Stripes on Curved Headband
    final headStripe = Paint()
      ..color = electricLime
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final stripePath1 = Path()
      ..moveTo(w * 0.16, h * 0.23)
      ..quadraticBezierTo(w * 0.50, h * 0.28, w * 0.84, h * 0.23);
    canvas.drawPath(stripePath1, headStripe);

    final stripePath2 = Path()
      ..moveTo(w * 0.16, h * 0.28)
      ..quadraticBezierTo(w * 0.50, h * 0.33, w * 0.84, h * 0.28);
    canvas.drawPath(stripePath2, headStripe);

    // Center Lightning Bolt ⚡ Emblem on Curved Headband
    final boltPath = Path();
    final boltCenterX = w * 0.50;
    final boltCenterY = h * 0.30;
    final boltSize = w * 0.034;
    boltPath.moveTo(boltCenterX + boltSize * 0.2, boltCenterY - boltSize * 1.1);
    boltPath.lineTo(boltCenterX - boltSize * 0.8, boltCenterY + boltSize * 0.1);
    boltPath.lineTo(boltCenterX - boltSize * 0.1, boltCenterY + boltSize * 0.1);
    boltPath.lineTo(boltCenterX - boltSize * 0.3, boltCenterY + boltSize * 1.1);
    boltPath.lineTo(boltCenterX + boltSize * 0.8, boltCenterY - boltSize * 0.1);
    boltPath.lineTo(boltCenterX + boltSize * 0.1, boltCenterY - boltSize * 0.1);
    boltPath.close();

    final boltPaint = Paint()
      ..color = electricLime
      ..style = PaintingStyle.fill;
    canvas.drawPath(boltPath, boltPaint);

    // 7. OLED Peanut / Goggle Visor Screen (Organic curved mask from reference)
    final visorPath = Path()
      ..moveTo(w * 0.28, h * 0.38)
      ..quadraticBezierTo(w * 0.50, h * 0.41, w * 0.72, h * 0.38)
      ..quadraticBezierTo(w * 0.88, h * 0.42, w * 0.88, h * 0.58)
      ..quadraticBezierTo(w * 0.88, h * 0.74, w * 0.72, h * 0.76)
      ..quadraticBezierTo(w * 0.50, h * 0.73, w * 0.28, h * 0.76)
      ..quadraticBezierTo(w * 0.12, h * 0.74, w * 0.12, h * 0.58)
      ..quadraticBezierTo(w * 0.12, h * 0.42, w * 0.28, h * 0.38)
      ..close();

    final visorPaint = Paint()..color = const Color(0xFF060913); // Deep OLED Black
    final visorStroke = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final visorGlow = Paint()
      ..color = const Color(0xFF00E0C7).withValues(alpha: 0.15 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawPath(visorPath, visorGlow);
    canvas.drawPath(visorPath, visorPaint);
    canvas.drawPath(visorPath, visorStroke);

    // 8. Glowing LED Oval Eyes & Face (Exact match to reference)
    _drawVisorFace(canvas, size, Offset(w * 0.50, h * 0.57));
  }

  void _drawVisorFace(Canvas canvas, Size size, Offset center) {
    final w = size.width;
    final h = size.height;

    // Glowing Neon Cyan-Mint Eye Color from Reference
    const Color eyeColor = Color(0xFF00F5D4);
    const Color blushColor = Color(0xFFB6FF3B);

    final leftEyeCenter = Offset(w * 0.34, h * 0.56);
    final rightEyeCenter = Offset(w * 0.66, h * 0.56);

    // 1. Cheek Blush Dashes (Tiny diagonal ticks from reference)
    final blushPaint = Paint()
      ..color = blushColor
      ..strokeWidth = w * 0.024
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final blushGlow = Paint()
      ..color = blushColor.withValues(alpha: 0.40)
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..style = PaintingStyle.stroke;

    // Left cheek tick
    canvas.drawLine(Offset(w * 0.22, h * 0.67), Offset(w * 0.26, h * 0.65), blushGlow);
    canvas.drawLine(Offset(w * 0.22, h * 0.67), Offset(w * 0.26, h * 0.65), blushPaint);

    // Right cheek tick
    canvas.drawLine(Offset(w * 0.74, h * 0.65), Offset(w * 0.78, h * 0.67), blushGlow);
    canvas.drawLine(Offset(w * 0.74, h * 0.65), Offset(w * 0.78, h * 0.67), blushPaint);

    switch (mood) {
      case BuboMood.happy:
      case BuboMood.correct:
      case BuboMood.watching:
        // Pure Glowing Vertical Oval LED Eyes (Exact to reference image)
        _drawGlowingOvalEye(canvas, leftEyeCenter, w * 0.14, h * 0.20, eyeColor);
        _drawGlowingOvalEye(canvas, rightEyeCenter, w * 0.14, h * 0.20, eyeColor);
        break;

      case BuboMood.warning:
        // Determined Wincing Eyes: >  <
        final p = Paint()
          ..color = const Color(0xFFFBBF24)
          ..strokeWidth = w * 0.04
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(leftEyeCenter + Offset(-w * 0.06, -w * 0.05), leftEyeCenter + Offset(w * 0.05, 0), p);
        canvas.drawLine(leftEyeCenter + Offset(w * 0.05, 0), leftEyeCenter + Offset(-w * 0.06, w * 0.05), p);
        canvas.drawLine(rightEyeCenter + Offset(w * 0.06, -w * 0.05), rightEyeCenter + Offset(-w * 0.05, 0), p);
        canvas.drawLine(rightEyeCenter + Offset(-w * 0.05, 0), rightEyeCenter + Offset(w * 0.06, w * 0.05), p);
        break;

      case BuboMood.fireStreak:
      case BuboMood.celebrate:
        // Big Golden Star Sparkle Eyes: ★  ★
        final starPaint = Paint()..color = const Color(0xFFFACC15);
        final starGlow = Paint()
          ..color = const Color(0xFFFACC15).withValues(alpha: 0.50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        _drawStar(canvas, leftEyeCenter, w * 0.09, starPaint, starGlow);
        _drawStar(canvas, rightEyeCenter, w * 0.09, starPaint, starGlow);
        break;

      case BuboMood.levelUp:
        // Lightning Bolt Eyes: ⚡  ⚡
        final boltPaint = Paint()..color = eyeColor;
        final boltGlow = Paint()
          ..color = eyeColor.withValues(alpha: 0.50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        _drawBolt(canvas, leftEyeCenter, w * 0.09, boltPaint, boltGlow);
        _drawBolt(canvas, rightEyeCenter, w * 0.09, boltPaint, boltGlow);
        break;
    }

    // 2. Cute Floating Glowing Smile in Center (from reference)
    final mouthPaint = Paint()
      ..color = eyeColor
      ..strokeWidth = w * 0.026
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final mouthGlow = Paint()
      ..color = eyeColor.withValues(alpha: 0.45)
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..style = PaintingStyle.stroke;

    final mouthPath = Path()
      ..moveTo(w * 0.46, h * 0.67)
      ..quadraticBezierTo(w * 0.50, h * 0.70, w * 0.54, h * 0.67);

    canvas.drawPath(mouthPath, mouthGlow);
    canvas.drawPath(mouthPath, mouthPaint);
  }

  void _drawGlowingOvalEye(Canvas canvas, Offset center, double width, double height, Color color) {
    final currentHeight = height * blinkProgress;

    if (blinkProgress < 0.20) {
      // Slit blink arc (Closed eyelid with neon glow)
      final slitPaint = Paint()
        ..color = color
        ..strokeWidth = width * 0.35
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final slitGlow = Paint()
        ..color = color.withValues(alpha: 0.50)
        ..strokeWidth = width * 0.50
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..style = PaintingStyle.stroke;

      final leftPoint = Offset(center.dx - width * 0.45, center.dy);
      final rightPoint = Offset(center.dx + width * 0.45, center.dy);
      canvas.drawLine(leftPoint, rightPoint, slitGlow);
      canvas.drawLine(leftPoint, rightPoint, slitPaint);
      return;
    }

    final rect = Rect.fromCenter(center: center, width: width, height: currentHeight);

    // 1. Soft Outer Neon Atmospheric Glow
    final outerGlow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(rect, outerGlow);

    // 2. Medium Glow
    final midGlow = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(rect, midGlow);

    // 3. Solid Bright Glowing Core
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawOval(rect, corePaint);

    // 4. Subtle Bright Center Highlight for LED depth
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: width * 0.55, height: currentHeight * 0.65),
      highlightPaint,
    );
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint, Paint glow) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final double angle = (i * 4 * math.pi / 5) - math.pi / 2;
      final double x = center.dx + radius * math.cos(angle);
      final double y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, glow);
    canvas.drawPath(path, paint);
  }

  void _drawBolt(Canvas canvas, Offset center, double radius, Paint paint, Paint glow) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx - radius * 0.6, center.dy + radius * 0.1)
      ..lineTo(center.dx + radius * 0.1, center.dy + radius * 0.1)
      ..lineTo(center.dx - radius * 0.2, center.dy + radius)
      ..lineTo(center.dx + radius * 0.6, center.dy - radius * 0.1)
      ..lineTo(center.dx - radius * 0.1, center.dy - radius * 0.1)
      ..close();
    canvas.drawPath(path, glow);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BuboPainter oldDelegate) =>
      oldDelegate.mood != mood ||
      oldDelegate.glowIntensity != glowIntensity ||
      oldDelegate.blinkProgress != blinkProgress;
}
