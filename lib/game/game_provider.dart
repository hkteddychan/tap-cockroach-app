import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models/game_models.dart';

// 簡化版持久化 — 用檔案儲存
class SimpleStorage {
  static File? _file;

  static Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = Directory.current.path;
    _file = File('$dir/.tap_cockroach_save.json');
    return _file!;
  }

  static Future<String?> read() async {
    try {
      final f = await _getFile();
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String data) async {
    try {
      final f = await _getFile();
      await f.writeAsString(data);
    } catch (_) {}
  }
}

class GameProvider extends ChangeNotifier {
  GameState _gameState = GameState();

  // 遊戲運行狀態
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
  int _goldenCountThisRun = 0;
  int _timeUsedThisRun = 0;

  bool _isLoaded = false;

  GameState get gameState => _gameState;
  LevelConfig get levelConfig => LevelConfig.levels[currentLevel - 1];

  int get effectiveTimeLimit {
    final base = levelConfig.timeLimit;
    final timeSkill = _gameState.skillLevels[SkillType.timeExt.index] ?? 0;
    return base + [0, 5, 10, 15][timeSkill];
  }

  int get effectiveLives {
    final base = levelConfig.lives;
    final sturdySkill = _gameState.skillLevels[SkillType.sturdy.index] ?? 0;
    final petBonus = _gameState.extraLives;
    return base + [0, 1, 2, 3][sturdySkill] + petBonus;
  }

  double get tapRadiusMultiplier {
    final skill = _gameState.skillLevels[SkillType.precise.index] ?? 0;
    return 1.0 + [0, 0.2, 0.4, 0.6][skill];
  }

  double get goldenChanceBonus {
    final skill = _gameState.skillLevels[SkillType.lucky.index] ?? 0;
    return [0, 3, 6, 10][skill] / 100;
  }

  double get speedMultiplier => _gameState.cockroachSpeedMultiplier;

  double get comboDecayMultiplier {
    final skill = _gameState.skillLevels[SkillType.combo.index] ?? 0;
    return 1.0 - [0, 0.2, 0.4, 0.6][skill];
  }

  bool get isLoaded => _isLoaded;

  Future<void> loadState() async {
    if (_isLoaded) return;
    final saved = await SimpleStorage.read();
    if (saved != null) {
      try {
        final map = jsonDecode(saved) as Map<String, dynamic>;
        _gameState = GameState(
          coins: map['coins'] ?? 0,
          essence: map['essence'] ?? 0,
          playerLevel: map['playerLevel'] ?? 1,
          totalXp: map['totalXp'] ?? 0,
          skillLevels: Map<int, int>.from(
            (map['skillLevels'] as Map?)?.map(
              (k, v) => MapEntry(int.parse(k.toString()), (v as num).toInt()),
            ) ?? {},
          ),
          completedLevels: List<int>.from(map['completedLevels'] ?? []),
          unlockedPetIds: List<String>.from(map['unlockedPetIds'] ?? []),
          unlockedAchievementIds: Set<String>.from(map['unlockedAchievementIds'] ?? []),
          highestSingleScore: map['highestSingleScore'] ?? 0,
          maxCombo: map['maxCombo'] ?? 0,
          perfectClearCount: map['perfectClearCount'] ?? 0,
          threeStarCount: map['threeStarCount'] ?? 0,
          goldenPerRun: map['goldenPerRun'] ?? 0,
          speedClearCount: map['speedClearCount'] ?? 0,
          levelStars: Map<int, int>.from(
            (map['levelStars'] as Map?)?.map(
              (k, v) => MapEntry(int.parse(k.toString()), (v as num).toInt()),
            ) ?? {},
          ),
        );
      } catch (_) {
        _gameState = GameState();
      }
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> saveState() async {
    final map = {
      'coins': _gameState.coins,
      'essence': _gameState.essence,
      'playerLevel': _gameState.playerLevel,
      'totalXp': _gameState.totalXp,
      'skillLevels': _gameState.skillLevels.map((k, v) => MapEntry(k.toString(), v)),
      'completedLevels': _gameState.completedLevels,
      'unlockedPetIds': _gameState.unlockedPetIds,
      'unlockedAchievementIds': _gameState.unlockedAchievementIds.toList(),
      'highestSingleScore': _gameState.highestSingleScore,
      'maxCombo': _gameState.maxCombo,
      'perfectClearCount': _gameState.perfectClearCount,
      'threeStarCount': _gameState.threeStarCount,
      'goldenPerRun': _gameState.goldenPerRun,
      'speedClearCount': _gameState.speedClearCount,
      'levelStars': _gameState.levelStars.map((k, v) => MapEntry(k.toString(), v)),
    };
    await SimpleStorage.write(jsonEncode(map));
  }

  void startGame(int level) {
    currentLevel = level;
    score = 0;
    lives = effectiveLives;
    timeLeft = effectiveTimeLimit;
    combo = 1.0;
    comboCount = 0;
    isPaused = false;
    isPlaying = true;
    gameOverReason = null;
    activeCockroaches.clear();
    _cockroachIdCounter = 0;
    _goldenCountThisRun = 0;
    _timeUsedThisRun = 0;
    notifyListeners();
  }

  void spawnCockroach() {
    if (!isPlaying || isPaused) return;
    final config = levelConfig;
    final rand = Random();

    double goldenRate = (config.goldenChance + goldenChanceBonus * 100) / 100;
    double giantRate = config.giantChance / 100;
    double fastRate = config.fastChance / 100;

    double roll = rand.nextDouble();
    CockroachType type;
    if (roll < goldenRate) {
      type = CockroachType.golden;
    } else if (roll < goldenRate + giantRate) {
      type = CockroachType.giant;
    } else if (roll < goldenRate + giantRate + fastRate) {
      type = CockroachType.fast;
    } else {
      type = CockroachType.normal;
    }

    final speedMod = speedMultiplier;
    final speedSkill = _gameState.skillLevels[SkillType.speed.index] ?? 0;
    final speedReduction = 1.0 - [0, 0.1, 0.2, 0.3][speedSkill];

    final cockroach = CockroachData(
      id: _cockroachIdCounter++,
      type: type,
      position: Offset(
        30 + rand.nextDouble() * 300,
        100 + rand.nextDouble() * 500,
      ),
      speed: _getSpeed(type) * speedMod * speedReduction,
      points: _getPoints(type),
      createdAt: DateTime.now(),
    );

    activeCockroaches.add(cockroach);
    notifyListeners();
  }

  double _getSpeed(CockroachType type) {
    final base = levelConfig.cockroachSpeed;
    switch (type) {
      case CockroachType.fast:   return base * 1.8;
      case CockroachType.giant:  return base * 0.5;
      case CockroachType.golden: return base * 1.2;
      default:                   return base;
    }
  }

  int _getPoints(CockroachType type) {
    final base = levelConfig.pointsPerCockroach;
    switch (type) {
      case CockroachType.fast:   return (base * 1.5).round();
      case CockroachType.giant:  return (base * 3).round();
      case CockroachType.golden: return (base * 5).round();
      default:                   return base;
    }
  }

  void onCockroachTap(int id, Offset position) {
    final index = activeCockroaches.indexWhere((c) => c.id == id);
    if (index != -1) {
      final cockroach = activeCockroaches[index];
      score += (cockroach.points * combo).round();
      comboCount++;

      if (comboCount >= 10) {
        combo = 2.0 + _gameState.comboBonus;
      } else if (comboCount >= 5) {
        combo = 1.5;
      } else if (comboCount >= 3) {
        combo = 1.2;
      }

      if (_gameState.maxCombo < comboCount) {
        _gameState.maxCombo = comboCount;
      }

      if (cockroach.type == CockroachType.golden) {
        _goldenCountThisRun++;
        _gameState.essence += 2;
      }

      activeCockroaches.removeAt(index);
      HapticFeedback.mediumImpact();
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
      } else {
        comboCount = (comboCount - 1).clamp(0, 999);
      }

      if (lives <= 0) {
        gameOverReason = '生命歸零！';
        isPlaying = false;
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
    _timeUsedThisRun = effectiveTimeLimit - timeLeft;
    gameOverReason = '時間到！';
    if (onGameOver != null) onGameOver!();
    notifyListeners();
  }

  void onWin() {
    _timeUsedThisRun = effectiveTimeLimit - timeLeft;
    isPlaying = false;
    notifyListeners();
  }

  bool checkWin() => score >= levelConfig.targetScore;

  void onLevelEnd(bool wasWin) {
    if (wasWin) {
      _gameState.onLevelComplete(
        currentLevel,
        score,
        _goldenCountThisRun,
        lives == effectiveLives && lives > 0,
        _timeUsedThisRun,
      );
      _gameState.checkNewAchievements();
    }
    saveState();
  }

  bool upgradeSkill(int index) {
    final ok = _gameState.upgradeSkill(index);
    if (ok) {
      _gameState.checkNewAchievements();
      saveState();
      notifyListeners();
    }
    return ok;
  }

  bool isPetUnlocked(String petId) => _gameState.unlockedPetIds.contains(petId);

  List<Pet> get currentPets => defaultPets.map((p) {
    return p.copyWith(unlocked: _gameState.unlockedPetIds.contains(p.id));
  }).toList();

  List<Achievement> get achievementsWithStatus => allAchievements;

  bool isAchievementUnlocked(String id) => _gameState.unlockedAchievementIds.contains(id);

  Set<String> getNewAchievements() => _gameState.checkNewAchievements();

  void dispose() {
    activeCockroaches.clear();
    super.dispose();
  }
}