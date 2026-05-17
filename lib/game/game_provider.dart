import 'package:flutter/material.dart';
import '../data/models/game_models.dart';

class GameProvider extends ChangeNotifier {
  int currentLevel = 1;
  int score = 0;
  int lives = 3;
  int timeLeft = 60;
  double combo = 1.0;
  int comboCount = 0;
  bool isPaused = false;
  bool isPlaying = false;
  String? gameOverReason;
  VoidCallback? onGameOver;

  List<CockroachData> activeCockroaches = [];
  int _cockroachIdCounter = 0;

  LevelConfig get levelConfig => LevelConfig.levels[currentLevel - 1];

  void startGame(int level) {
    currentLevel = level;
    score = 0;
    lives = LevelConfig.levels[level - 1].lives;
    timeLeft = LevelConfig.levels[level - 1].timeLimit;
    combo = 1.0;
    comboCount = 0;
    isPaused = false;
    isPlaying = true;
    gameOverReason = null;
    activeCockroaches.clear();
    _cockroachIdCounter = 0;
    notifyListeners();
  }

  void spawnCockroach() {
    if (!isPlaying || isPaused) return;
    final config = levelConfig;
    final random = DateTime.now().millisecondsSinceEpoch % 100;

    CockroachType type;
    if (random < config.goldenChance) {
      type = CockroachType.golden;
    } else if (random < config.giantChance) {
      type = CockroachType.giant;
    } else if (random < config.fastChance) {
      type = CockroachType.fast;
    } else {
      type = CockroachType.normal;
    }

    final cockroach = CockroachData(
      id: _cockroachIdCounter++,
      type: type,
      position: Offset(
        50 + (DateTime.now().millisecondsSinceEpoch % 300).toDouble(),
        150 + (DateTime.now().millisecondsSinceEpoch % 400).toDouble(),
      ),
      speed: _getSpeed(type),
      points: _getPoints(type),
      createdAt: DateTime.now(),
    );

    activeCockroaches.add(cockroach);
    notifyListeners();
  }

  double _getSpeed(CockroachType type) {
    final base = levelConfig.cockroachSpeed;
    switch (type) {
      case CockroachType.fast:
        return base * 1.8;
      case CockroachType.giant:
        return base * 0.5;
      case CockroachType.golden:
        return base * 1.2;
      default:
        return base;
    }
  }

  int _getPoints(CockroachType type) {
    final base = levelConfig.pointsPerCockroach;
    switch (type) {
      case CockroachType.fast:
        return (base * 1.5).round();
      case CockroachType.giant:
        return (base * 3).round();
      case CockroachType.golden:
        return (base * 5).round();
      default:
        return base;
    }
  }

  void onCockroachTap(int id, Offset position) {
    final index = activeCockroaches.indexWhere((c) => c.id == id);
    if (index != -1) {
      final cockroach = activeCockroaches[index];
      score += (cockroach.points * combo).round();
      comboCount++;

      if (comboCount >= 5) {
        combo = 2.0;
      } else if (comboCount >= 3) {
        combo = 1.5;
      }

      activeCockroaches.removeAt(index);
      notifyListeners();
    }
  }

  void onCockroachEscape(int id) {
    final index = activeCockroaches.indexWhere((c) => c.id == id);
    if (index != -1) {
      activeCockroaches.removeAt(index);
      lives--;

      if (comboCount >= 3) {
        comboCount = 0;
        combo = 1.0;
      }

      if (lives <= 0) {
        gameOverReason = '生命歸零！';
        if (onGameOver != null) onGameOver!();
      }
      notifyListeners();
    }
  }

  void togglePause() {
    isPaused = !isPaused;
    notifyListeners();
  }

  void onTimeUp() {
    gameOverReason = '時間到！';
    if (onGameOver != null) onGameOver!();
    notifyListeners();
  }

  void onWin() {
    isPlaying = false;
    notifyListeners();
  }

  bool checkWin() {
    return score >= levelConfig.targetScore;
  }

  void dispose() {
    activeCockroaches.clear();
    super.dispose();
  }
}