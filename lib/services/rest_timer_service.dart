import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lift_league/services/notifications_service.dart';

class RestTimerService {
  RestTimerService._internal();
  static final RestTimerService _instance = RestTimerService._internal();
  factory RestTimerService() => _instance;

  Timer? _timer;
  int _remainingSeconds = 0;
  int get remainingSeconds => _remainingSeconds;

  final StreamController<int> _streamController = StreamController<int>.broadcast();
  Stream<int> get stream => _streamController.stream;

  bool _playSound = true;

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _playSound = prefs.getBool('playRestSound') ?? true;
  }

  Future<void> _playChime() async {
    if (!_playSound) return;
    try {
      final player = AudioPlayer();
      await player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.duckOthers},
          ),
        ),
      );
      await player.play(AssetSource('sounds/chime.wav'));
      await player.onPlayerComplete.first;
      await player.release();
    } catch (_) {}
  }


  void start(int seconds) {
    _timer?.cancel();
    _remainingSeconds = seconds;
    _streamController.add(_remainingSeconds);
    _loadPrefs();
    //NotificationService().showOngoingTimerNotification(_remainingSeconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds > 1) {
        _remainingSeconds--;
        _streamController.add(_remainingSeconds);
        //NotificationService().showOngoingTimerNotification(_remainingSeconds);
      } else {
        timer.cancel();
        _remainingSeconds = 0;
        _streamController.add(_remainingSeconds);
        NotificationService().cancelOngoingTimerNotification();
        Vibration.hasVibrator().then((hasVibrator) {
          if (hasVibrator) {
            Vibration.vibrate(duration: 500);
          }
        });
        await _playChime();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _remainingSeconds = 0;
    _streamController.add(_remainingSeconds);
    NotificationService().cancelOngoingTimerNotification();
  }
}
