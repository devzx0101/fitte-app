<div align="center">

# ⚡ Fitte — AI Movement Coach & Fitness Companion

**Real-time on-device computer vision form tracking meets gamified fitness with BUBO 🐣**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Google ML Kit](https://img.shields.io/badge/Google_ML_Kit-Pose_Detection-4285F4?logo=google&logoColor=white)](https://developers.google.com/ml-kit)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-3DDC84?logo=android&logoColor=white)](https://github.com/devzx0101/fitte-app)
[![Submission](https://img.shields.io/badge/Hackathon-Quantum%20Hacks%202026-CCFF00?style=flat-square)](#)

---

</div>

## 📖 Overview

**Fitte** is a next-generation AI fitness application that turns your smartphone camera into an intelligent, real-time personal trainer. Using 100% on-device neural pose estimation, Fitte tracks your biomechanical joint angles, validates workout form, counts reps with zero false triggers, and levels up your athletic journey alongside **BUBO**, your energetic AI companion creature.

---

## 🤖 Meet BUBO — Your AI Training Partner

BUBO isn't just a generic mascot—he has a dedicated UX role across the 3 core layers of Fitte:

1. **🏠 Home Screen (Companion)**: Welcomes you with dynamic Duolingo-style speech bubble dialogues, tracks your streak, and displays your active level progress.
2. **📷 Workout Camera HUD (Real-Time Coach)**: Reacts live to your exercise cadence with procedural LED eye states (`👀 Watching`, `^‿^ Good Form`, `>_< Form Warning`, `🔥 Combo Streak`).
3. **🎉 Session Summary (Celebrator)**: Celebrates your finished workout inside a radiant neon victory aura with XP level badges and detailed performance stats.

---

## ✨ Key Features

- **⚡ 100% On-Device & Zero Cloud Latency**: Pose estimation runs at ~15ms per frame locally on your device with Google ML Kit—no video feeds ever leave your phone (100% private & secure).
- **📐 Biomechanical Form Analysis**: Real-time 3-point joint angle triangulation across shoulders, elbows, hips, knees, and ankles.
- **🏋️ Multiple Supported Exercises**:
  - 🦵 **Squats** (Depth tracking, knee flexion angle & chest posture)
  - 💪 **Pushups** (Chest-to-floor depth & elbow flexion tracking)
  - 🏃 **Jumping Jacks** (Arm extension & leg abduction tempo)
  - 🧘 **Crunches** (Torso-to-thigh angle closure with EMA noise filtering)
  - ⏱️ **Plank** (Spine-to-hip alignment hold timer)
- **📊 Dopamine Gamification & Stats**: Persistent XP engine, level progression, rep velocity (CPM rate), active duration timer, and streak combos.
- **🔇 Visual-First HUD**: Clean, high-focus interface free of annoying synthetic robot voiceovers.

---

## 🚀 How to Download & Run the App

### Option 1: Direct Android APK Build (Quickest)

If you have a physical Android device or emulator connected:

```bash
# 1. Clone the repository
git clone https://github.com/devzx0101/fitte-app.git
cd fitte-app

# 2. Install dependencies
flutter pub get

# 3. Build release APK
flutter build apk --release
```
The compiled APK will be located at: `build/app/outputs/flutter-apk/app-release.apk`

---

### Option 2: Run in Development Mode

#### Prerequisites:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.24.0 or higher)
- [Android Studio](https://developer.android.com/studio) / Android SDK (API Level 21+)
- Physical Android phone with USB Debugging enabled (recommended for live camera testing)

#### Step-by-step Execution:

```bash
# 1. Clone the project
git clone https://github.com/devzx0101/fitte-app.git
cd fitte-app

# 2. Fetch Flutter packages
flutter pub get

# 3. Verify connected device
flutter devices

# 4. Run the app on your device
flutter run
```

---

## 🏗️ Architecture & Project Structure

```
lib/
├── main.dart                  # App bootstrap & global theme config
├── models/
│   ├── coach_persona.dart     # AI persona definitions
│   ├── pose_model.dart        # 17-point kinematic pose & landmark types
│   └── session_stats.dart     # Workout session metrics & XP leveling model
├── painters/
│   └── skeleton_painter.dart  # 1:1 hardware-accelerated glowing skeletal overlay
├── screens/
│   ├── home_screen.dart       # Dashboard & exercise picker
│   ├── summary_screen.dart    # Dark victory celebration with 4 metric cards
│   └── workout_screen.dart    # Full-screen camera HUD & live tracking controller
├── services/
│   ├── audio_service.dart     # Silent audio coach interface
│   ├── pose_detector_service.dart # Google ML Kit neural pose pipeline
│   ├── rep_counter_service.dart   # Biomechanical rep validation algorithms
│   └── user_prefs_service.dart    # SharedPreferences persistent XP storage
├── ui/screens/
│   └── home_screen.dart       # Modernized Obsidian UI home experience
└── widgets/
    ├── bubo_widget.dart       # Vector BUBO mascot with procedural blinking & speech tails
    ├── stat_card.dart         # Slate metric card widgets
    ├── top_bar.dart           # Workout screen exit & silhouette toggle controls
    └── workout_hud.dart       # Real-time rep, combo, and form feedback overlay
```

---

## 🧪 Testing

Fitte includes a complete automated unit and widget test suite:

```bash
# Run static analysis
flutter analyze

# Execute all test suites
flutter test
```

---

## 🏆 Quantum Hacks Submission

- **Team**: Fitte
- **Tech Stack**: Flutter, Dart, Google ML Kit Vision, Camera2 API, Google Fonts Outfit
- **GitHub**: [https://github.com/devzx0101/fitte-app](https://github.com/devzx0101/fitte-app)
