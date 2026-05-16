class LevelConfig {
  final int level;
  final int timeSeconds;
  final int cockroachCount;
  final int spawnIntervalMs;
  final double cockroachSpeed;
  final double slowDurationSec;
  final double slowChance;
  final int baseScore;

  const LevelConfig({
    required this.level,
    required this.timeSeconds,
    required this.cockroachCount,
    required this.spawnIntervalMs,
    required this.cockroachSpeed,
    required this.slowDurationSec,
    required this.slowChance,
    required this.baseScore,
  });

  static const List<LevelConfig> levels = [
    LevelConfig(level: 1, timeSeconds: 30, cockroachCount: 5, spawnIntervalMs: 2500, cockroachSpeed: 1.0, slowDurationSec: 3.0, slowChance: 0.8, baseScore: 10),
    LevelConfig(level: 2, timeSeconds: 30, cockroachCount: 7, spawnIntervalMs: 2200, cockroachSpeed: 1.1, slowDurationSec: 2.8, slowChance: 0.7, baseScore: 12),
    LevelConfig(level: 3, timeSeconds: 35, cockroachCount: 9, spawnIntervalMs: 2000, cockroachSpeed: 1.2, slowDurationSec: 2.5, slowChance: 0.6, baseScore: 14),
    LevelConfig(level: 4, timeSeconds: 35, cockroachCount: 11, spawnIntervalMs: 1800, cockroachSpeed: 1.3, slowDurationSec: 2.2, slowChance: 0.5, baseScore: 16),
    LevelConfig(level: 5, timeSeconds: 40, cockroachCount: 13, spawnIntervalMs: 1600, cockroachSpeed: 1.4, slowDurationSec: 2.0, slowChance: 0.4, baseScore: 18),
    LevelConfig(level: 6, timeSeconds: 40, cockroachCount: 15, spawnIntervalMs: 1400, cockroachSpeed: 1.5, slowDurationSec: 1.8, slowChance: 0.3, baseScore: 20),
    LevelConfig(level: 7, timeSeconds: 45, cockroachCount: 18, spawnIntervalMs: 1200, cockroachSpeed: 1.6, slowDurationSec: 1.5, slowChance: 0.2, baseScore: 22),
    LevelConfig(level: 8, timeSeconds: 45, cockroachCount: 20, spawnIntervalMs: 1000, cockroachSpeed: 1.7, slowDurationSec: 1.2, slowChance: 0.15, baseScore: 25),
    LevelConfig(level: 9, timeSeconds: 50, cockroachCount: 23, spawnIntervalMs: 850, cockroachSpeed: 1.8, slowDurationSec: 1.0, slowChance: 0.1, baseScore: 28),
    LevelConfig(level: 10, timeSeconds: 60, cockroachCount: 28, spawnIntervalMs: 700, cockroachSpeed: 2.0, slowDurationSec: 0.8, slowChance: 0.05, baseScore: 30),
  ];
}

enum CockroachType { normal, fast, giant, gold }

class CockroachConfig {
  final CockroachType type;
  final double speedMultiplier;
  final int score;
  final double weight;

  const CockroachConfig({
    required this.type,
    required this.speedMultiplier,
    required this.score,
    required this.weight,
  });

  static const List<CockroachConfig> types = [
    CockroachConfig(type: CockroachType.normal, speedMultiplier: 1.0, score: 10, weight: 70),
    CockroachConfig(type: CockroachType.fast, speedMultiplier: 1.5, score: 25, weight: 20),
    CockroachConfig(type: CockroachType.giant, speedMultiplier: 0.7, score: 50, weight: 8),
    CockroachConfig(type: CockroachType.gold, speedMultiplier: 2.0, score: 100, weight: 2),
  ];

  static CockroachConfig getRandom() {
    final total = types.fold(0.0, (sum, t) => sum + t.weight);
    double random = DateTime.now().millisecondsSinceEpoch % 1000 / 1000.0 * total;
    for (final config in types) {
      random -= config.weight;
      if (random <= 0) return config;
    }
    return types[0];
  }
}

class GameStats {
  int score;
  int combo;
  int maxCombo;
  int hearts;
  int cockroachesKilled;
  int totalScore;
  int highScore;
  int unlockedLevel;
  int totalKillsAll;

  GameStats({
    this.score = 0,
    this.combo = 0,
    this.maxCombo = 0,
    this.hearts = 3,
    this.cockroachesKilled = 0,
    this.totalScore = 0,
    this.highScore = 0,
    this.unlockedLevel = 1,
    this.totalKillsAll = 0,
  });

  void reset() {
    score = 0;
    combo = 0;
    maxCombo = 0;
    hearts = 3;
    cockroachesKilled = 0;
  }
}