import 'package:flutter/material.dart';

enum CoachPersona {
  jax,  // Drill Sergeant
  nova, // Cyber Bio-Analyst
  kai,  // Zen Athlete
}

extension CoachPersonaDetails on CoachPersona {
  String get name {
    switch (this) {
      case CoachPersona.jax:
        return 'Coach Jax';
      case CoachPersona.nova:
        return 'Nova AI';
      case CoachPersona.kai:
        return 'Master Kai';
    }
  }

  String get title {
    switch (this) {
      case CoachPersona.jax:
        return 'Drill Sergeant';
      case CoachPersona.nova:
        return 'Cyber Bio-Analyst';
      case CoachPersona.kai:
        return 'Zen Athlete';
    }
  }

  String get emoji {
    switch (this) {
      case CoachPersona.jax:
        return '🎖️';
      case CoachPersona.nova:
        return '🤖';
      case CoachPersona.kai:
        return '🧘';
    }
  }

  String get tagline {
    switch (this) {
      case CoachPersona.jax:
        return 'High energy, intense, no excuses!';
      case CoachPersona.nova:
        return 'Analytical, robotic, surgical precision.';
      case CoachPersona.kai:
        return 'Calm, breath-focused, mindful flow.';
    }
  }

  Color get accentColor {
    switch (this) {
      case CoachPersona.jax:
        return const Color(0xFFF97316); // Fiery Orange
      case CoachPersona.nova:
        return const Color(0xFF38BDF8); // Cyber Blue
      case CoachPersona.kai:
        return const Color(0xFF22C55E); // Emerald Green
    }
  }
}
