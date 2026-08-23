import '../models/coach_persona.dart';

/// Silent Audio Coach Service (Voice completely removed for a sleek Duolingo-style mascot experience)
class AudioCoachService {
  static final AudioCoachService _instance = AudioCoachService._internal();
  factory AudioCoachService() => _instance;

  AudioCoachService._internal();

  CoachPersona _persona = CoachPersona.jax;

  bool get isMuted => true;
  CoachPersona get currentPersona => _persona;

  void setPersona(CoachPersona persona) {
    _persona = persona;
  }

  void toggleMute() {}
  void setMuted(bool muted) {}

  Future<void> speakRep(int count) async {}
  Future<void> speakPlankHold(int seconds) async {}
  Future<void> speakFeedback(String message, {int throttleMs = 2500}) async {}
  Future<void> speakSessionComplete(int reps, int xp) async {}
  Future<void> stop() async {}
}
