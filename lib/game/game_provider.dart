import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/game_models.dart';
import '../components/cockroach_widget.dart';

class GameProvider extends ChangeNotifier {
  LevelConfig get currentLevel => LevelConfig.levels[_currentLevel - 1];
  int _currentLevel = 1;
  int get currentLevelIndex => _currentLevel - 1;
  
  final GameStats stats = GameStats();
  final Random _random = Random();
  
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  
  Timer? _spawnTimer;
  Timer? _gameTimer;
  int _timeLeft = 0;
  int get timeLeft => _timeLeft;
  
  int _cockroachesSpawned = 0;
  int _cockroachesOnScreen = 0;
  
  final List<CockroachData> _activeCockroaches = [];
  List<CockroachData> get activeCockroaches => List.unmodifiable(_activeCockroaches);
  
  Function(int score, int combo, Offset position)? onScorePopup;
  Function(int combo)? onComboPopup;
  Function()? onLevelComplete;
  Function(String reason)? onGameOver;
  Function(int heart)? onHeartChange;
  
  int _currentScore = 0;
  int get currentScore => _currentScore;

  void startGame(int level) {
    _currentLevel = level.clamp(1, 10);
    stats.reset();
    _activeCockroaches.clear();
    _cockroachesSpawned = 0;
    _cockroachesOnScreen = 0;
    _currentScore = 0;
    _timeLeft = currentLevel.timeSeconds;
    _isPlaying = true;
    
    _startGameTimer();
    _scheduleSpawn();
    notifyListeners();
  }

  void _startGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPlaying) return;
      
      _timeLeft--;
      notifyListeners();
      
      if (_timeLeft <= 0) {
        _gameOver('時間到！');
      }
    });
  }

  void _scheduleSpawn() {
    if (!_isPlaying) return;
    if (_cockroachesSpawned >= currentLevel.cockroachCount) return;
    
    final delay = currentLevel.spawnIntervalMs;
    _spawnTimer = Timer(Duration(milliseconds: delay), () {
      if (_isPlaying && _cockroachesSpawned < currentLevel.cockroachCount) {
        _spawnCockroach();
        _scheduleSpawn();
      }
    });
  }

  void _spawnCockroach() {
    if (!_isPlaying) return;
    
    final config = CockroachConfig.getRandom();
    final cockroach = CockroachData(
      id: DateTime.now().millisecondsSinceEpoch,
      config: config,
      position: _getRandomPosition(config),
      velocity: _getRandomVelocity(config.speedMultiplier),
      isSlowed: _random.nextDouble() < currentLevel.slowChance,
      slowEndTime: _random.nextDouble() < currentLevel.slowChance 
          ? DateTime.now().add(Duration(milliseconds: (currentLevel.slowDurationSec * 1000).toInt()))
          : null,
    );
    
    _activeCockroaches.add(cockroach);
    _cockroachesSpawned++;
    _cockroachesOnScreen++;
    notifyListeners();
  }

  Offset _getRandomPosition(CockroachConfig config) {
    final size = config.type == CockroachType.giant ? 80.0 : 60.0;
    return Offset(
      _random.nextDouble() * (300 - size),
      _random.nextDouble() * (500 - size) + 100,
    );
  }

  Offset _getRandomVelocity(double speedMultiplier) {
    final speed = 2.0 * speedMultiplier * currentLevel.cockroachSpeed;
    return Offset(
      (_random.nextDouble() - 0.5) * speed * 2,
      (_random.nextDouble() - 0.5) * speed * 2,
    );
  }

  void updateCockroaches() {
    if (!_isPlaying) return;
    
    final now = DateTime.now();
    final toRemove = <int>[];
    
    for (final cockroach in _activeCockroaches) {
      // Check slow effect
      bool isSlowed = cockroach.isSlowed && 
          (cockroach.slowEndTime == null || cockroach.slowEndTime!.isAfter(now));
      
      double speedMult = isSlowed ? 0.3 : 1.0;
      
      // Update position
      double newX = cockroach.position.dx + cockroach.velocity.dx * speedMult;
      double newY = cockroach.position.dy + cockroach.velocity.dy * speedMult;
      
      // Bounce off walls
      double vx = cockroach.velocity.dx;
      double vy = cockroach.velocity.dy;
      
      if (newX < 10 || newX > 290) {
        vx *= -1;
        newX = newX.clamp(10, 290);
      }
      if (newY < 80 || newY > 520) {
        vy *= -1;
        newY = newY.clamp(80, 520);
      }
      
      // Random direction change
      if (_random.nextDouble() < 0.02) {
        vx += (_random.nextDouble() - 0.5) * 1.5;
        vy += (_random.nextDouble() - 0.5) * 1.5;
      }
      
      cockroach.position = Offset(newX, newY);
      cockroach.velocity = Offset(vx.clamp(-5, 5), vy.clamp(-5, 5));
      cockroach.facingRight = vx > 0;
    }
    
    notifyListeners();
  }

  void onCockroachTap(int id, Offset tapPosition) {
    if (!_isPlaying) return;
    
    final index = _activeCockroaches.indexWhere((c) => c.id == id);
    if (index == -1) return;
    
    final cockroach = _activeCockroaches[index];
    _activeCockroaches.removeAt(index);
    _cockroachesOnScreen--;
    stats.cockroachesKilled++;
    
    // Score calculation
    stats.combo++;
    if (stats.combo > stats.maxCombo) stats.maxCombo = stats.combo;
    
    int bonus = 0;
    if (stats.combo >= 10) bonus = 50;
    else if (stats.combo >= 5) bonus = 25;
    else if (stats.combo >= 3) bonus = 10;
    else if (stats.combo >= 2) bonus = 5;
    
    final totalScore = cockroach.config.score + bonus;
    _currentScore += totalScore;
    
    // Callbacks
    onScorePopup?.call(totalScore, stats.combo, tapPosition);
    if (stats.combo >= 2) {
      onComboPopup?.call(stats.combo);
    }
    
    notifyListeners();
    _checkWinCondition();
  }

  void onCockroachEscape(int id) {
    if (!_isPlaying) return;
    
    final index = _activeCockroaches.indexWhere((c) => c.id == id);
    if (index == -1) return;
    
    _activeCockroaches.removeAt(index);
    _cockroachesOnScreen--;
    stats.combo = 0;
    stats.hearts--;
    
    onHeartChange?.call(stats.hearts);
    notifyListeners();
    
    if (stats.hearts <= 0) {
      _gameOver('漏晒啲蟲！');
    } else {
      _checkWinCondition();
    }
  }

  void _checkWinCondition() {
    if (stats.cockroachesKilled >= currentLevel.cockroachCount && 
        _cockroachesSpawned >= currentLevel.cockroachCount) {
      _levelComplete();
    }
  }

  void _levelComplete() {
    _isPlaying = false;
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    
    stats.totalScore += _currentScore;
    stats.totalKillsAll += stats.cockroachesKilled;
    if (_currentScore > stats.highScore) stats.highScore = _currentScore;
    if (_currentLevel >= stats.unlockedLevel && _currentLevel < 10) {
      stats.unlockedLevel = _currentLevel + 1;
    }
    
    onLevelComplete?.call();
    notifyListeners();
  }

  void _gameOver(String reason) {
    _isPlaying = false;
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    
    stats.totalScore += _currentScore;
    stats.totalKillsAll += stats.cockroachesKilled;
    if (_currentScore > stats.highScore) stats.highScore = _currentScore;
    
    onGameOver?.call(reason);
    notifyListeners();
  }

  void pauseGame() {
    _isPlaying = false;
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    notifyListeners();
  }

  void resumeGame() {
    if (_timeLeft > 0) {
      _isPlaying = true;
      _startGameTimer();
      _scheduleSpawn();
      notifyListeners();
    }
  }

  void dispose() {
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }
}

class CockroachData {
  final int id;
  final CockroachConfig config;
  Offset position;
  Offset velocity;
  bool isSlowed;
  DateTime? slowEndTime;
  bool facingRight;

  CockroachData({
    required this.id,
    required this.config,
    required this.position,
    required this.velocity,
    this.isSlowed = false,
    this.slowEndTime,
    this.facingRight = true,
  });
}