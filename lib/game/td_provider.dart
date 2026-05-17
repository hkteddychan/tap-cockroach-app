import 'package:flutter/foundation.dart';
import 'dart:math';

/// Tower Defense game logic provider
/// Handles tower placement, enemy waves, combo system, and skill bonuses
class TDProvider extends ChangeNotifier {
  // Game state
  bool _isPlaying = false;
  int _currentWave = 0;
  int _gold = 150;
  int _lives = 20;
  double _comboMultiplier = 1.0;
  int _comboCount = 0;
  int _score = 0;
  
  // Tower management
  final List<Tower> _placedTowers = [];
  final Map<String, Tower> _towerBlueprints = {};
  Tower? _selectedTower;
  
  // Enemy management
  final List<Enemy> _activeEnemies = [];
  final List<Wave> _waves = [];
  
  // Projectile management
  final List<Projectile> _activeProjectiles = [];
  
  // Skill bonuses
  final Map<String, double> _skillBonuses = {
    'damage': 1.0,
    'attackSpeed': 1.0,
    'range': 1.0,
    'goldBonus': 1.0,
    'slowEffect': 1.0,
    'criticalChance': 0.1,
  };
  
  // Wave spawn timing
  double _waveSpawnTimer = 0.0;
  int _enemiesSpawnedInWave = 0;
  bool _waveInProgress = false;
  
  // Getters
  bool get isPlaying => _isPlaying;
  int get currentWave => _currentWave;
  int get gold => _gold;
  int get lives => _lives;
  double get comboMultiplier => _comboMultiplier;
  int get comboCount => _comboCount;
  int get score => _score;
  List<Tower> get placedTowers => List.unmodifiable(_placedTowers);
  List<Enemy> get activeEnemies => List.unmodifiable(_activeEnemies);
  List<Projectile> get activeProjectiles => List.unmodifiable(_activeProjectiles);
  Map<String, double> get skillBonuses => Map.unmodifiable(_skillBonuses);
  Tower? get selectedTower => _selectedTower;
  
  TDProvider() {
    _initializeTowerBlueprints();
    _initializeWaves();
  }
  
  /// Initialize tower blueprints with base stats
  void _initializeTowerBlueprints() {
    _towerBlueprints['arrow'] = Tower(
      id: 'arrow',
      name: 'Arrow Tower',
      type: TowerType.arrow,
      cost: 50,
      damage: 15,
      attackSpeed: 1.0,
      range: 150,
      color: 0xFF8B4513,
    );
    
    _towerBlueprints['magic'] = Tower(
      id: 'magic',
      name: 'Magic Tower',
      type: TowerType.magic,
      cost: 100,
      damage: 25,
      attackSpeed: 0.7,
      range: 180,
      color: 0xFF6A0DAD,
    );
    
    _towerBlueprints['cannon'] = Tower(
      id: 'cannon',
      name: 'Cannon Tower',
      type: TowerType.cannon,
      cost: 150,
      damage: 50,
      attackSpeed: 0.4,
      range: 120,
      color: 0xFF4A4A4A,
    );
    
    _towerBlueprints['ice'] = Tower(
      id: 'ice',
      name: 'Ice Tower',
      type: TowerType.ice,
      cost: 75,
      damage: 10,
      attackSpeed: 1.2,
      range: 140,
      color: 0xFF00CED1,
    );
    
    _towerBlueprints['poison'] = Tower(
      id: 'poison',
      name: 'Poison Tower',
      type: TowerType.poison,
      cost: 125,
      damage: 8,
      attackSpeed: 0.9,
      range: 130,
      color: 0xFF32CD32,
    );
  }
  
  /// Initialize wave configurations
  void _initializeWaves() {
    for (int i = 0; i < 20; i++) {
      _waves.add(Wave(
        waveNumber: i + 1,
        enemyCount: 5 + (i * 2),
        enemyType: _getWaveEnemyType(i),
        enemyHealth: 30 + (i * 15),
        enemySpeed: 1.0 + (i * 0.1).clamp(0.0, 3.0),
        spawnInterval: max(0.8, 2.0 - (i * 0.1)),
        rewardGold: 10 + (i * 2),
      ));
    }
  }
  
  EnemyType _getWaveEnemyType(int wave) {
    if (wave < 5) return EnemyType.basic;
    if (wave < 10) return wave % 2 == 0 ? EnemyType.fast : EnemyType.basic;
    if (wave < 15) return wave % 3 == 0 ? EnemyType.tank : EnemyType.fast;
    return EnemyType.boss;
  }
  
  /// Start the Tower Defense game
  void startGame() {
    _isPlaying = true;
    _currentWave = 0;
    _gold = 150;
    _lives = 20;
    _comboMultiplier = 1.0;
    _comboCount = 0;
    _score = 0;
    _placedTowers.clear();
    _activeEnemies.clear();
    _activeProjectiles.clear();
    _waveSpawnTimer = 0.0;
    _enemiesSpawnedInWave = 0;
    _waveInProgress = false;
    
    _resetSkillBonuses();
    notifyListeners();
  }
  
  /// Reset skill bonuses to default values
  void _resetSkillBonuses() {
    _skillBonuses = {
      'damage': 1.0,
      'attackSpeed': 1.0,
      'range': 1.0,
      'goldBonus': 1.0,
      'slowEffect': 1.0,
      'criticalChance': 0.1,
    };
  }
  
  /// Select a tower type for placement
  void selectTower(String towerId) {
    if (_towerBlueprints.containsKey(towerId)) {
      _selectedTower = _towerBlueprints[towerId];
      notifyListeners();
    }
  }
  
  /// Clear tower selection
  void clearSelection() {
    _selectedTower = null;
    notifyListeners();
  }
  
  /// Place a tower at the specified position
  bool placeTower(double x, double y) {
    if (_selectedTower == null) return false;
    
    final cost = _selectedTower!.cost;
    if (_gold < cost) return false;
    
    // Check if position is valid (not overlapping with existing towers)
    for (final tower in _placedTowers) {
      final distance = sqrt(pow(tower.x - x, 2) + pow(tower.y - y, 2));
      if (distance < 60) return false; // Minimum distance between towers
    }
    
    final tower = Tower(
      id: '${_selectedTower!.id}_${DateTime.now().millisecondsSinceEpoch}',
      name: _selectedTower!.name,
      type: _selectedTower!.type,
      cost: _selectedTower!.cost,
      damage: _selectedTower!.damage * _skillBonuses['damage']!,
      attackSpeed: _selectedTower!.attackSpeed * _skillBonuses['attackSpeed']!,
      range: _selectedTower!.range * _skillBonuses['range']!,
      color: _selectedTower!.color,
      x: x,
      y: y,
    );
    
    _placedTowers.add(tower);
    _gold -= cost;
    _selectedTower = null;
    notifyListeners();
    return true;
  }
  
  /// Upgrade a tower at the specified position
  bool upgradeTower(String towerId) {
    final index = _placedTowers.indexWhere((t) => t.id == towerId);
    if (index == -1) return false;
    
    final tower = _placedTowers[index];
    final upgradeCost = (tower.cost * 0.8).round();
    
    if (_gold < upgradeCost) return false;
    
    _gold -= upgradeCost;
    _placedTowers[index] = tower.copyWith(
      damage: tower.damage * 1.3,
      attackSpeed: tower.attackSpeed * 1.15,
      range: tower.range * 1.1,
      level: tower.level + 1,
    );
    
    notifyListeners();
    return true;
  }
  
  /// Remove a tower and refund some gold
  bool removeTower(String towerId) {
    final index = _placedTowers.indexWhere((t) => t.id == towerId);
    if (index == -1) return false;
    
    final tower = _placedTowers[index];
    final refund = (tower.cost * 0.5).round();
    
    _gold += refund;
    _placedTowers.removeAt(index);
    notifyListeners();
    return true;
  }
  
  /// Start the next wave
  void startNextWave() {
    if (_waveInProgress) return;
    if (_currentWave >= _waves.length) return;
    
    _currentWave++;
    _waveInProgress = true;
    _enemiesSpawnedInWave = 0;
    _waveSpawnTimer = 0.0;
    notifyListeners();
  }
  
  /// Update game state each frame
  void update(double deltaTime) {
    if (!_isPlaying) return;
    
    // Update wave spawning
    if (_waveInProgress && _currentWave > 0 && _currentWave <= _waves.length) {
      _updateWaveSpawning(deltaTime);
    }
    
    // Update towers attacking
    _updateTowerAttacks(deltaTime);
    
    // Update projectiles
    _updateProjectiles(deltaTime);
    
    // Update enemies
    _updateEnemies(deltaTime);
    
    // Check wave completion
    _checkWaveCompletion();
    
    // Update combo decay
    _updateComboDecay(deltaTime);
    
    notifyListeners();
  }
  
  /// Update wave enemy spawning
  void _updateWaveSpawning(double deltaTime) {
    if (_currentWave < 1 || _currentWave > _waves.length) return;
    
    final wave = _waves[_currentWave - 1];
    if (_enemiesSpawnedInWave >= wave.enemyCount) return;
    
    _waveSpawnTimer += deltaTime;
    if (_waveSpawnTimer >= wave.spawnInterval) {
      _waveSpawnTimer = 0.0;
      _spawnEnemy(wave);
      _enemiesSpawnedInWave++;
    }
  }
  
  /// Spawn an enemy based on wave configuration
  void _spawnEnemy(Wave wave) {
    final random = Random();
    final enemy = Enemy(
      id: 'enemy_${DateTime.now().millisecondsSinceEpoch}_$random',
      type: wave.enemyType,
      health: wave.enemyHealth.toDouble(),
      maxHealth: wave.enemyHealth.toDouble(),
      speed: wave.enemySpeed,
      rewardGold: (wave.rewardGold * _skillBonuses['goldBonus']!).round(),
      x: random.nextDouble() * 50, // Spawn from left side
      y: 200 + random.nextDouble() * 400, // Random y within path
    );
    _activeEnemies.add(enemy);
  }
  
  /// Update tower attacks
  void _updateTowerAttacks(double deltaTime) {
    for (final tower in _placedTowers) {
      tower.attackCooldown -= deltaTime;
      
      if (tower.attackCooldown <= 0) {
        // Find target in range
        Enemy? target = _findTarget(tower);
        
        if (target != null) {
          // Fire projectile
          _fireProjectile(tower, target);
          tower.attackCooldown = 1.0 / tower.attackSpeed;
        }
      }
    }
  }
  
  /// Find the nearest enemy in range
  Enemy? _findTarget(Tower tower) {
    Enemy? nearest;
    double minDistance = double.infinity;
    
    for (final enemy in _activeEnemies) {
      final distance = sqrt(pow(enemy.x - tower.x, 2) + pow(enemy.y - tower.y, 2));
      if (distance <= tower.range && distance < minDistance) {
        minDistance = distance;
        nearest = enemy;
      }
    }
    
    return nearest;
  }
  
  /// Fire a projectile from tower to target
  void _fireProjectile(Tower tower, Enemy target) {
    final projectile = Projectile(
      id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
      x: tower.x,
      y: tower.y,
      targetId: target.id,
      damage: tower.damage,
      speed: 300,
      color: tower.color,
      type: tower.type,
    );
    
    _activeProjectiles.add(projectile);
  }
  
  /// Update projectiles movement and collision
  void _updateProjectiles(double deltaTime) {
    for (int i = _activeProjectiles.length - 1; i >= 0; i--) {
      final projectile = _activeProjectiles[i];
      
      // Find target
      final targetIndex = _activeEnemies.indexWhere((e) => e.id == projectile.targetId);
      
      if (targetIndex == -1) {
        // Target died, remove projectile
        _activeProjectiles.removeAt(i);
        continue;
      }
      
      final target = _activeEnemies[targetIndex];
      
      // Move projectile towards target
      final dx = target.x - projectile.x;
      final dy = target.y - projectile.y;
      final distance = sqrt(dx * dx + dy * dy);
      
      if (distance < 10) {
        // Hit target
        _handleProjectileHit(projectile, target, targetIndex);
        _activeProjectiles.removeAt(i);
      } else {
        // Update position
        final moveDistance = projectile.speed * deltaTime;
        projectile.x += (dx / distance) * moveDistance;
        projectile.y += (dy / distance) * moveDistance;
      }
    }
  }
  
  /// Handle projectile hit on enemy
  void _handleProjectileHit(Projectile projectile, Enemy enemy, int enemyIndex) {
    // Calculate critical hit
    final isCritical = Random().nextDouble() < _skillBonuses['criticalChance']!;
    final damage = isCritical ? projectile.damage * 2.0 : projectile.damage;
    
    enemy.takeDamage(damage);
    
    // Apply special effects based on tower type
    switch (projectile.type) {
      case TowerType.ice:
        enemy.applySlow(0.5 * _skillBonuses['slowEffect']!);
        break;
      case TowerType.poison:
        enemy.applyPoison(damage * 0.2, 3.0);
        break;
      case TowerType.cannon:
        // Area damage
        _applyAreaDamage(projectile.x, projectile.y, projectile.damage * 0.5);
        break;
      default:
        break;
    }
    
    // Check if enemy died
    if (enemy.isDead) {
      _handleEnemyDeath(enemy, enemyIndex);
    }
  }
  
  /// Apply area damage to nearby enemies
  void _applyAreaDamage(double x, double y, double damage) {
    for (final enemy in _activeEnemies) {
      final distance = sqrt(pow(enemy.x - x, 2) + pow(enemy.y - y, 2));
      if (distance < 80) {
        enemy.takeDamage(damage);
        if (enemy.isDead && !enemy.rewarded) {
          _handleEnemyDeath(enemy, _activeEnemies.indexOf(enemy));
        }
      }
    }
  }
  
  /// Handle enemy death and rewards
  void _handleEnemyDeath(Enemy enemy, int index) {
    if (enemy.rewarded) return;
    
    enemy.rewarded = true;
    _gold += enemy.rewardGold;
    _score += (enemy.rewardGold * _comboMultiplier).round();
    
    // Update combo
    _comboCount++;
    _updateComboMultiplier();
    
    // Remove enemy
    _activeEnemies.removeAt(index);
  }
  
  /// Update combo multiplier based on combo count
  void _updateComboMultiplier() {
    if (_comboCount < 5) {
      _comboMultiplier = 1.0;
    } else if (_comboCount < 10) {
      _comboMultiplier = 1.5;
    } else if (_comboCount < 20) {
      _comboMultiplier = 2.0;
    } else if (_comboCount < 50) {
      _comboMultiplier = 3.0;
    } else {
      _comboMultiplier = 5.0;
    }
  }
  
  /// Update enemies movement and status
  void _updateEnemies(double deltaTime) {
    for (int i = _activeEnemies.length - 1; i >= 0; i--) {
      final enemy = _activeEnemies[i];
      
      // Update status effects
      enemy.update(deltaTime);
      
      // Move towards goal (right side of screen)
      if (!enemy.isSlowed) {
        enemy.x += enemy.speed * 60 * deltaTime;
      } else {
        enemy.x += enemy.speed * 60 * deltaTime * enemy.slowMultiplier;
      }
      
      // Check if enemy reached the end
      if (enemy.x > 800) {
        _lives--;
        _activeEnemies.removeAt(i);
        
        // Reset combo on enemy reaching end
        _comboCount = 0;
        _comboMultiplier = 1.0;
        
        if (_lives <= 0) {
          _gameOver();
        }
      }
    }
  }
  
  /// Update combo decay over time
  void _updateComboDecay(double deltaTime) {
    // Combo decays when not killing enemies
    // This is handled by tracking last kill time
  }
  
  /// Check if wave is complete
  void _checkWaveCompletion() {
    if (!_waveInProgress) return;
    
    final wave = _waves[_currentWave - 1];
    if (_enemiesSpawnedInWave >= wave.enemyCount && _activeEnemies.isEmpty) {
      _waveInProgress = false;
      
      // Bonus gold for completing wave quickly
      _gold += 25 + (_currentWave * 5);
      _score += (100 * _currentWave).round();
    }
  }
  
  /// Apply skill bonus
  void applySkillBonus(String skillId, double value) {
    if (_skillBonuses.containsKey(skillId)) {
      _skillBonuses[skillId] = _skillBonuses[skillId]! * value;
    } else {
      _skillBonuses[skillId] = value;
    }
    notifyListeners();
  }
  
  /// Handle game over
  void _gameOver() {
    _isPlaying = false;
    notifyListeners();
  }
  
  /// Pause the game
  void pauseGame() {
    _isPlaying = false;
    notifyListeners();
  }
  
  /// Resume the game
  void resumeGame() {
    if (_lives > 0 && _currentWave > 0) {
      _isPlaying = true;
      notifyListeners();
    }
  }
  
  /// Sell tower for gold
  int sellTower(String towerId) {
    final index = _placedTowers.indexWhere((t) => t.id == towerId);
    if (index == -1) return 0;
    
    final tower = _placedTowers[index];
    final refund = (tower.cost * 0.6).round();
    
    _gold += refund;
    _placedTowers.removeAt(index);
    notifyListeners();
    return refund;
  }
  
  /// Get available towers for purchase
  List<Tower> getAvailableTowers() {
    return _towerBlueprints.values.where((t) => t.cost <= _gold).toList();
  }
  
  /// Get current wave info
  Wave? getCurrentWaveInfo() {
    if (_currentWave < 1 || _currentWave > _waves.length) return null;
    return _waves[_currentWave - 1];
  }
  
  /// Calculate tower stats with bonuses
  Map<String, double> getTowerStats(Tower tower) {
    return {
      'damage': tower.damage * _skillBonuses['damage']!,
      'attackSpeed': tower.attackSpeed * _skillBonuses['attackSpeed']!,
      'range': tower.range * _skillBonuses['range']!,
    };
  }
  
  /// Reset combo (called periodically or on damage taken)
  void resetCombo() {
    _comboCount = 0;
    _comboMultiplier = 1.0;
    notifyListeners();
  }
  
  /// Get combo status info
  Map<String, dynamic> getComboInfo() {
    return {
      'count': _comboCount,
      'multiplier': _comboMultiplier,
      'nextMultiplierAt': _getNextMultiplierThreshold(),
    };
  }
  
  int _getNextMultiplierThreshold() {
    if (_comboCount < 5) return 5;
    if (_comboCount < 10) return 10;
    if (_comboCount < 20) return 20;
    if (_comboCount < 50) return 50;
    return -1; // Max multiplier reached
  }
  
  /// Get game statistics
  Map<String, dynamic> getGameStats() {
    return {
      'score': _score,
      'wave': _currentWave,
      'lives': _lives,
      'gold': _gold,
      'towersPlaced': _placedTowers.length,
      'enemiesKilled': _score ~/ 10,
    };
  }
}