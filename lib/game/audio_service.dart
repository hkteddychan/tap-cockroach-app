import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum SoundType {
  tap, hit, kill, waveStart, waveClear,
  gameWin, gameLose, achievement, placeTower,
  gold, lifeLost, bossAlert,
}

class AudioService {
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;
  AudioService._();

  final Map<SoundType, AudioPlayer> _sfxPlayers = {};
  AudioPlayer? _bgmPlayer;
  bool _muted = false;
  double _sfxVolume = 0.7;
  double _bgmVolume = 0.3;

  static const _sfxFiles = {
    SoundType.tap: 'audio/sfx_tap.wav',
    SoundType.hit: 'audio/sfx_hit.wav',
    SoundType.kill: 'audio/sfx_kill.wav',
    SoundType.waveStart: 'audio/sfx_wave_start.wav',
    SoundType.waveClear: 'audio/sfx_wave_clear.wav',
    SoundType.gameWin: 'audio/sfx_game_win.wav',
    SoundType.gameLose: 'audio/sfx_game_lose.wav',
    SoundType.achievement: 'audio/sfx_achievement.wav',
    SoundType.placeTower: 'audio/sfx_place_tower.wav',
    SoundType.gold: 'audio/sfx_gold.wav',
    SoundType.lifeLost: 'audio/sfx_life_lost.wav',
    SoundType.bossAlert: 'audio/sfx_boss_alert.wav',
  };

  Future<void> init() async {
    for (final type in SoundType.values) {
      final player = AudioPlayer();
      await player.setVolume(_sfxVolume);
      _sfxPlayers[type] = player;
    }
    _bgmPlayer = AudioPlayer();
    await _bgmPlayer!.setVolume(_bgmVolume);
    await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
  }

  void playSfx(SoundType type) {
    if (_muted) return;
    final player = _sfxPlayers[type];
    if (player == null) return;
    final file = _sfxFiles[type];
    if (file == null) return;
    player.play(AssetSource(file)).catchError((e) {
      debugPrint('SFX error: $e');
    });
  }

  Future<void> playBgm() async {
    if (_muted || _bgmPlayer == null) return;
    await _bgmPlayer!.stop();
    await _bgmPlayer!.play(AssetSource('audio/bgm_gameplay.wav')).catchError((e) {
      debugPrint('BGM error: $e');
    });
  }

  Future<void> stopBgm() async {
    await _bgmPlayer?.stop();
  }

  void toggleMute() { _muted = !_muted; if (_muted) _bgmPlayer?.pause(); }
  bool get isMuted => _muted;
  void setSfxVolume(double v) { _sfxVolume = v.clamp(0, 1); }
  void setBgmVolume(double v) { _bgmVolume = v.clamp(0, 1); }

  void dispose() {
    for (final p in _sfxPlayers.values) { p.dispose(); }
    _bgmPlayer?.dispose();
  }
}