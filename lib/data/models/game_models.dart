import 'package:flutter/material.dart';

// ─── 角色陳蒨妤 ───
class GameCharacter {
  final String name;
  final String title;
  final String emoji;
  final String description;

  const GameCharacter({
    required this.name,
    required this.title,
    required this.emoji,
    required this.description,
  });
}

const GameCharacter protagonist = GameCharacter(
  name: '陳蒨妤',
  title: '冰室傳人',
  emoji: '👧',
  description: '十七歲高中生，意外繼承祖母掌心觸碰驅蟲之術',
);

const GameCharacter grandma = GameCharacter(
  name: '陳婆婆',
  title: '隱世除蟲專家',
  emoji: '👵',
  description: '七十八歲隱世高手，金記冰室創辦人',
);

const List<GameCharacter> characters = [protagonist, grandma];

// ─── 10 關卡配置（5位專家共識）───
class LevelConfig {
  final int level;
  final String name;
  final String theme;
  final int timeLimit;
  final int targetScore;
  final int lives;
  final double spawnRate;
  final double cockroachSpeed;
  final int pointsPerCockroach;
  final int goldenChance;
  final int giantChance;
  final int fastChance;
  final Color bgColorTop;
  final Color bgColorBottom;
  final String bgEmoji;

  const LevelConfig({
    required this.level,
    required this.name,
    required this.theme,
    required this.timeLimit,
    required this.targetScore,
    required this.lives,
    required this.spawnRate,
    required this.cockroachSpeed,
    required this.pointsPerCockroach,
    required this.goldenChance,
    required this.giantChance,
    required this.fastChance,
    required this.bgColorTop,
    required this.bgColorBottom,
    required this.bgEmoji,
  });

  static const List<LevelConfig> levels = [
    LevelConfig(
      level: 1, name: '蟲族覺醒', theme: '廚房',
      timeLimit: 60, targetScore: 100, lives: 3,
      spawnRate: 1.0, cockroachSpeed: 1.0,
      pointsPerCockroach: 10, goldenChance: 5, giantChance: 10, fastChance: 20,
      bgColorTop: Color(0xFF2D1B00), bgColorBottom: Color(0xFF4A3000), bgEmoji: '🍳',
    ),
    LevelConfig(
      level: 2, name: '冰室保衛戰', theme: '廚房老手',
      timeLimit: 60, targetScore: 220, lives: 3,
      spawnRate: 1.2, cockroachSpeed: 1.1,
      pointsPerCockroach: 10, goldenChance: 5, giantChance: 12, fastChance: 25,
      bgColorTop: Color(0xFF2D1B00), bgColorBottom: Color(0xFF4A3000), bgEmoji: '🧊',
    ),
    LevelConfig(
      level: 3, name: '浴室驚魂', theme: '浴室',
      timeLimit: 55, targetScore: 350, lives: 3,
      spawnRate: 1.4, cockroachSpeed: 1.2,
      pointsPerCockroach: 12, goldenChance: 5, giantChance: 15, fastChance: 30,
      bgColorTop: Color(0xFF001A2D), bgColorBottom: Color(0xFF003A4A), bgEmoji: '🚿',
    ),
    LevelConfig(
      level: 4, name: '浴室領主', theme: '浴室老手',
      timeLimit: 55, targetScore: 500, lives: 3,
      spawnRate: 1.6, cockroachSpeed: 1.3,
      pointsPerCockroach: 12, goldenChance: 6, giantChance: 18, fastChance: 35,
      bgColorTop: Color(0xFF001A2D), bgColorBottom: Color(0xFF003A4A), bgEmoji: '🛁',
    ),
    LevelConfig(
      level: 5, name: '臥室噩夢', theme: '臥室',
      timeLimit: 50, targetScore: 650, lives: 2,
      spawnRate: 1.8, cockroachSpeed: 1.4,
      pointsPerCockroach: 14, goldenChance: 6, giantChance: 20, fastChance: 40,
      bgColorTop: Color(0xFF1A002D), bgColorBottom: Color(0xFF3A004A), bgEmoji: '🛏️',
    ),
    LevelConfig(
      level: 6, name: '黑影霸主', theme: '臥室老手',
      timeLimit: 50, targetScore: 850, lives: 2,
      spawnRate: 2.0, cockroachSpeed: 1.5,
      pointsPerCockroach: 14, goldenChance: 7, giantChance: 22, fastChance: 45,
      bgColorTop: Color(0xFF1A002D), bgColorBottom: Color(0xFF3A004A), bgEmoji: '🌙',
    ),
    LevelConfig(
      level: 7, name: '車庫危機', theme: '車庫',
      timeLimit: 45, targetScore: 1100, lives: 2,
      spawnRate: 2.2, cockroachSpeed: 1.6,
      pointsPerCockroach: 16, goldenChance: 7, giantChance: 25, fastChance: 50,
      bgColorTop: Color(0xFF1D1D1D), bgColorBottom: Color(0xFF3A3A3A), bgEmoji: '🚗',
    ),
    LevelConfig(
      level: 8, name: '油膩怪客', theme: '車庫老手',
      timeLimit: 45, targetScore: 1400, lives: 2,
      spawnRate: 2.5, cockroachSpeed: 1.7,
      pointsPerCockroach: 16, goldenChance: 8, giantChance: 28, fastChance: 55,
      bgColorTop: Color(0xFF1D1D1D), bgColorBottom: Color(0xFF3A3A3A), bgEmoji: '🔧',
    ),
    LevelConfig(
      level: 9, name: '害蟲總動員', theme: '混合',
      timeLimit: 40, targetScore: 1800, lives: 1,
      spawnRate: 2.8, cockroachSpeed: 1.8,
      pointsPerCockroach: 18, goldenChance: 8, giantChance: 30, fastChance: 60,
      bgColorTop: Color(0xFF1A0D00), bgColorBottom: Color(0xFF3A1A00), bgEmoji: '💀',
    ),
    LevelConfig(
      level: 10, name: '最終決戰', theme: '皇室',
      timeLimit: 35, targetScore: 2500, lives: 1,
      spawnRate: 3.0, cockroachSpeed: 2.0,
      pointsPerCockroach: 20, goldenChance: 10, giantChance: 35, fastChance: 65,
      bgColorTop: Color(0xFF2D004A), bgColorBottom: Color(0xFF4A0060), bgEmoji: '👑',
    ),
  ];
}

// ─── 蟑螂類型 ───
enum CockroachType { normal, fast, giant, golden }

// ─── 蟑螂數據 ───
class CockroachData {
  final int id;
  final CockroachType type;
  final Offset position;
  final double speed;
  final int points;
  final DateTime createdAt;

  CockroachData({
    required this.id,
    required this.type,
    required this.position,
    required this.speed,
    required this.points,
    required this.createdAt,
  });
}

// ─── 技能樹（6技能）───
enum SkillType {
  precise,   // 精準打擊
  lucky,     // 幸運星
  sturdy,    // 穩如泰山
  timeExt,   // 時間延長
  combo,     // 連環拖鞋
  speed,     // 急速手速
}

class Skill {
  final SkillType type;
  final String name;
  final String emoji;
  final String description;
  final List<int> essenceCosts; // [Lv1, Lv2, Lv3]
  final List<String> effects;   // [Lv1效果, Lv2效果, Lv3效果]

  const Skill({
    required this.type,
    required this.name,
    required this.emoji,
    required this.description,
    required this.essenceCosts,
    required this.effects,
  });

  int get maxLevel => 3;
}

const List<Skill> skills = [
  Skill(
    type: SkillType.precise,
    name: '精準打擊',
    emoji: '🎯',
    description: '點擊範圍擴大',
    essenceCosts: [15, 40, 80],
    effects: ['範圍 +20%', '範圍 +40%', '範圍 +60%'],
  ),
  Skill(
    type: SkillType.lucky,
    name: '幸運星',
    emoji: '⭐',
    description: '金色蟑螂機率提升',
    essenceCosts: [20, 50, 100],
    effects: ['金蟑螂 +3%', '金蟑螂 +6%', '金蟑螂 +10%'],
  ),
  Skill(
    type: SkillType.sturdy,
    name: '穩如泰山',
    emoji: '🛡️',
    description: '額外生命',
    essenceCosts: [15, 40, 80],
    effects: ['+1 生命', '+2 生命', '+3 生命'],
  ),
  Skill(
    type: SkillType.timeExt,
    name: '時間延長',
    emoji: '⏰',
    description: '關卡時間增加',
    essenceCosts: [20, 50, 100],
    effects: ['+5秒', '+10秒', '+15秒'],
  ),
  Skill(
    type: SkillType.combo,
    name: '連環拖鞋',
    emoji: '🩴',
    description: 'Combo衰減減慢',
    essenceCosts: [25, 60, 120],
    effects: ['衰減 -20%', '衰減 -40%', '衰減 -60%'],
  ),
  Skill(
    type: SkillType.speed,
    name: '急速手速',
    emoji: '⚡',
    description: '蟑螂出現速度減慢',
    essenceCosts: [30, 70, 150],
    effects: ['速度 -10%', '速度 -20%', '速度 -30%'],
  ),
];

// ─── 寵物系統（3寵物）───
class Pet {
  final String id;
  final String name;
  final String emoji;
  final String rarity;
  final int unlockLevel;
  final String bonus;
  final bool unlocked;

  const Pet({
    required this.id,
    required this.name,
    required this.emoji,
    required this.rarity,
    required this.unlockLevel,
    required this.bonus,
    this.unlocked = false,
  });

  Pet copyWith({bool? unlocked}) => Pet(
    id: id,
    name: name,
    emoji: emoji,
    rarity: rarity,
    unlockLevel: unlockLevel,
    bonus: bonus,
    unlocked: unlocked ?? this.unlocked,
  );
}

List<Pet> defaultPets = [
  const Pet(
    id: 'gecko',
    name: '阿壁',
    emoji: '🦎',
    rarity: '普通',
    unlockLevel: 2,
    bonus: '+1 額外生命',
  ),
  const Pet(
    id: 'frog',
    name: '呱呱',
    emoji: '🐸',
    rarity: '稀有',
    unlockLevel: 5,
    bonus: '蟑螂減速 20%',
  ),
  const Pet(
    id: 'spider',
    name: '小黑',
    emoji: '🕷️',
    rarity: '史詩',
    unlockLevel: 8,
    bonus: 'Combo +0.5x',
  ),
];

// ─── 成就系統（10成就）───
class Achievement {
  final String id;
  final String name;
  final String emoji;
  final String condition;
  final int essenceReward;
  final int coinReward;
  final bool Function(GameState) checkUnlock;

  const Achievement({
    required this.id,
    required this.name,
    required this.emoji,
    required this.condition,
    required this.essenceReward,
    required this.coinReward,
    required this.checkUnlock,
  });
}

List<Achievement> allAchievements = [
  Achievement(
    id: 'first_blood',
    name: '初出茅廬',
    emoji: '🌱',
    condition: '完成關卡1',
    essenceReward: 15,
    coinReward: 0,
    checkUnlock: (s) => s.completedLevels.contains(1),
  ),
  Achievement(
    id: 'high_scorer',
    name: '滅蟲新星',
    emoji: '⭐',
    condition: '單關 500分',
    essenceReward: 20,
    coinReward: 0,
    checkUnlock: (s) => s.highestSingleScore >= 500,
  ),
  Achievement(
    id: 'three_star',
    name: '三星廚師',
    emoji: '🌟',
    condition: '任意 3★ 通關',
    essenceReward: 0,
    coinReward: 50,
    checkUnlock: (s) => s.threeStarCount >= 1,
  ),
  Achievement(
    id: 'combo_master',
    name: '連環達人',
    emoji: '🔥',
    condition: '10 Combo',
    essenceReward: 25,
    coinReward: 0,
    checkUnlock: (s) => s.maxCombo >= 10,
  ),
  Achievement(
    id: 'perfect_run',
    name: '完璧之身',
    emoji: '💎',
    condition: '零失血通關',
    essenceReward: 75,
    coinReward: 0,
    checkUnlock: (s) => s.perfectClearCount >= 1,
  ),
  Achievement(
    id: 'pet_collector',
    name: '收集達人',
    emoji: '🐾',
    condition: '收集所有寵物',
    essenceReward: 100,
    coinReward: 0,
    checkUnlock: (s) => s.unlockedPetIds.length >= 3,
  ),
  Achievement(
    id: 'final_boss',
    name: '滅蟲王者',
    emoji: '🏆',
    condition: '完成關卡10',
    essenceReward: 200,
    coinReward: 0,
    checkUnlock: (s) => s.completedLevels.contains(10),
  ),
  Achievement(
    id: 'lucky_hand',
    name: '幸運之手',
    emoji: '🍀',
    condition: '單關 3 隻黃金蟑螂',
    essenceReward: 0,
    coinReward: 50,
    checkUnlock: (s) => s.goldenPerRun >= 3,
  ),
  Achievement(
    id: 'speed_king',
    name: '速度之王',
    emoji: '⚡',
    condition: '30秒內清關',
    essenceReward: 30,
    coinReward: 0,
    checkUnlock: (s) => s.speedClearCount >= 1,
  ),
  Achievement(
    id: 'max_skills',
    name: '全滿級',
    emoji: '👑',
    condition: '所有技能滿等',
    essenceReward: 500,
    coinReward: 0,
    checkUnlock: (s) => s.skillLevels.values.every((lv) => lv >= 3),
  ),
];

// ─── 遊戲狀態（持久化）───
class GameState {
  int coins;
  int essence;
  int playerLevel;
  int totalXp;
  Map<int, int> skillLevels; // skill index → level (0-3)
  List<int> completedLevels;
  List<String> unlockedPetIds;
  Set<String> unlockedAchievementIds;
  int highestSingleScore;
  int maxCombo;
  int perfectClearCount;
  int threeStarCount;
  int goldenPerRun;
  int speedClearCount;
  Map<int, int> levelStars; // level → stars (0-3)

  GameState({
    this.coins = 0,
    this.essence = 0,
    this.playerLevel = 1,
    this.totalXp = 0,
    Map<int, int>? skillLevels,
    List<int>? completedLevels,
    List<String>? unlockedPetIds,
    Set<String>? unlockedAchievementIds,
    this.highestSingleScore = 0,
    this.maxCombo = 0,
    this.perfectClearCount = 0,
    this.threeStarCount = 0,
    this.goldenPerRun = 0,
    this.speedClearCount = 0,
    Map<int, int>? levelStars,
  })  : skillLevels = skillLevels ?? {for (var s in skills) skills.indexOf(s): 0},
        completedLevels = completedLevels ?? [],
        unlockedPetIds = unlockedPetIds ?? [],
        unlockedAchievementIds = unlockedAchievementIds ?? {},
        levelStars = levelStars ?? {};

  // 計算星級 (0-3)
  int calcStars(int level, int score) {
    final cfg = LevelConfig.levels[level - 1];
    final ratio = score / cfg.targetScore;
    if (ratio >= 2.0) return 3;
    if (ratio >= 1.5) return 2;
    if (ratio >= 1.0) return 1;
    return 0;
  }

  // 技能升級費用
  int skillUpgradeCost(int skillIndex) {
    final current = skillLevels[skillIndex] ?? 0;
    if (current >= 3) return -1;
    return skills[skillIndex].essenceCosts[current];
  }

  // 玩家升級所需XP
  int xpForLevel(int level) => level * 400;

  // 結算後更新狀態
  void onLevelComplete(int level, int score, int goldenCount, bool wasPerfect, int timeUsed) {
    final cfg = LevelConfig.levels[level - 1];
    final stars = calcStars(level, score);

    // 首次通關
    if (!completedLevels.contains(level)) {
      completedLevels.add(level);
    }

    // 更新星級（取最高）
    final prevStars = levelStars[level] ?? 0;
    if (stars > prevStars) levelStars[level] = stars;

    // 結算獎勵
    final baseEssence = cfg.targetScore ~/ 10;
    essence += baseEssence + (stars * 10);
    coins += score ~/ 5 + (stars * 20);

    // XP
    totalXp += score;
    while (totalXp >= xpForLevel(playerLevel) && playerLevel < 10) {
      totalXp -= xpForLevel(playerLevel);
      playerLevel++;
    }

    // 單關記錄
    if (score > highestSingleScore) highestSingleScore = score;
    if (wasPerfect) perfectClearCount++;
    if (goldenCount > goldenPerRun) goldenPerRun = goldenCount;
    if (timeUsed <= 30) speedClearCount++;
    if (stars >= 3) threeStarCount++;

    // 寵物解鎖
    for (var pet in defaultPets) {
      if (level >= pet.unlockLevel && !unlockedPetIds.contains(pet.id)) {
        unlockedPetIds.add(pet.id);
      }
    }
  }

  // 檢查新成就
  Set<String> checkNewAchievements() {
    final newlyUnlocked = <String>{};
    for (var ach in allAchievements) {
      if (!unlockedAchievementIds.contains(ach.id) && ach.checkUnlock(this)) {
        unlockedAchievementIds.add(ach.id);
        essence += ach.essenceReward;
        coins += ach.coinReward;
        newlyUnlocked.add(ach.id);
      }
    }
    return newlyUnlocked;
  }

  // 購買技能
  bool upgradeSkill(int skillIndex) {
    final cost = skillUpgradeCost(skillIndex);
    if (cost < 0 || essence < cost) return false;
    essence -= cost;
    skillLevels[skillIndex] = (skillLevels[skillIndex] ?? 0) + 1;
    return true;
  }

  // 寵物加成
  int get extraLives {
    int bonus = 0;
    if (unlockedPetIds.contains('gecko')) bonus += 1;
    return bonus;
  }

  double get cockroachSpeedMultiplier {
    double m = 1.0;
    if (unlockedPetIds.contains('frog')) m *= 0.8;
    return m;
  }

  double get comboBonus {
    double bonus = 0.0;
    if (unlockedPetIds.contains('spider')) bonus += 0.5;
    return bonus;
  }
}