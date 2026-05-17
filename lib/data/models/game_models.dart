import 'package:flutter/material.dart';

class LevelConfig {
  final int level;
  final int timeLimit;
  final int targetScore;
  final int lives;
  final double spawnRate;
  final double cockroachSpeed;
  final int pointsPerCockroach;
  final int goldenChance;
  final int giantChance;
  final int fastChance;

  const LevelConfig({
    required this.level,
    required this.timeLimit,
    required this.targetScore,
    required this.lives,
    required this.spawnRate,
    required this.cockroachSpeed,
    required this.pointsPerCockroach,
    required this.goldenChance,
    required this.giantChance,
    required this.fastChance,
  });

  static const List<LevelConfig> levels = [
    LevelConfig(level: 1, timeLimit: 60, targetScore: 100, lives: 5, spawnRate: 1.0, cockroachSpeed: 1.0, pointsPerCockroach: 10, goldenChance: 5, giantChance: 10, fastChance: 20),
    LevelConfig(level: 2, timeLimit: 60, targetScore: 200, lives: 5, spawnRate: 1.2, cockroachSpeed: 1.1, pointsPerCockroach: 10, goldenChance: 5, giantChance: 12, fastChance: 25),
    LevelConfig(level: 3, timeLimit: 55, targetScore: 300, lives: 4, spawnRate: 1.4, cockroachSpeed: 1.2, pointsPerCockroach: 12, goldenChance: 5, giantChance: 15, fastChance: 30),
    LevelConfig(level: 4, timeLimit: 55, targetScore: 400, lives: 4, spawnRate: 1.6, cockroachSpeed: 1.3, pointsPerCockroach: 12, goldenChance: 6, giantChance: 18, fastChance: 35),
    LevelConfig(level: 5, timeLimit: 50, targetScore: 500, lives: 4, spawnRate: 1.8, cockroachSpeed: 1.4, pointsPerCockroach: 14, goldenChance: 6, giantChance: 20, fastChance: 40),
    LevelConfig(level: 6, timeLimit: 50, targetScore: 650, lives: 3, spawnRate: 2.0, cockroachSpeed: 1.5, pointsPerCockroach: 14, goldenChance: 7, giantChance: 22, fastChance: 45),
    LevelConfig(level: 7, timeLimit: 45, targetScore: 800, lives: 3, spawnRate: 2.2, cockroachSpeed: 1.6, pointsPerCockroach: 16, goldenChance: 7, giantChance: 25, fastChance: 50),
    LevelConfig(level: 8, timeLimit: 45, targetScore: 1000, lives: 3, spawnRate: 2.5, cockroachSpeed: 1.7, pointsPerCockroach: 16, goldenChance: 8, giantChance: 28, fastChance: 55),
    LevelConfig(level: 9, timeLimit: 40, targetScore: 1200, lives: 2, spawnRate: 2.8, cockroachSpeed: 1.8, pointsPerCockroach: 18, goldenChance: 8, giantChance: 30, fastChance: 60),
    LevelConfig(level: 10, timeLimit: 40, targetScore: 1500, lives: 2, spawnRate: 3.0, cockroachSpeed: 2.0, pointsPerCockroach: 20, goldenChance: 10, giantChance: 35, fastChance: 65),
  ];
}

enum CockroachType { normal, fast, giant, golden }

class CockroachData {
  final int id;
  final CockroachType type;
  final Offset position;
  final double speed;
  final int points;
  final DateTime createdAt;

  CockroachData({required this.id, required this.type, required this.position, required this.speed, required this.points, required this.createdAt});
}