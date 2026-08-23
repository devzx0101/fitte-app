import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/session_stats.dart';

class TopBar extends StatelessWidget {
  final ExerciseType exerciseType;
  final VoidCallback onExit;
  final VoidCallback onFinish;
  final bool showSkeleton;
  final VoidCallback? onToggleSkeleton;

  const TopBar({
    super.key,
    required this.exerciseType,
    required this.onExit,
    required this.onFinish,
    this.showSkeleton = true,
    this.onToggleSkeleton,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.only(
        top: topPadding + 6,
        left: 18,
        right: 18,
        bottom: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Exit Button (✕)
          GestureDetector(
            onTap: onExit,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF14141A).withValues(alpha: 0.75),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          // Center: Pose Silhouette Toggle Icon
          GestureDetector(
            onTap: onToggleSkeleton,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF14141A).withValues(alpha: 0.75),
                shape: BoxShape.circle,
                border: Border.all(
                  color: showSkeleton
                      ? const Color(0xFFA3E635).withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.directions_walk_rounded,
                color: showSkeleton ? const Color(0xFFA3E635) : Colors.white60,
                size: 22,
              ),
            ),
          ),

          // Right: Finish Pill Button
          GestureDetector(
            onTap: onFinish,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFA3E635), // Vibrant electric lime
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA3E635).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF0E0E10),
                    size: 17,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Finish',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0E0E10),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
