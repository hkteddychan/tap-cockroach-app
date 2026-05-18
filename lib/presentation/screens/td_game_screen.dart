import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../game/audio_service.dart';

// TDProvider, TDTower, TDEnemy, etc. are defined in this file below

// ═══════════════════════════════════════════════════════════
//  TD GAME SCREEN - 塔防遊戲主畫面
//  Character: 陳蒨妤
// ═══════════════════════════════════════════════════════════

class TDGameScreen extends StatefulWidget {
  final int level;
  const TDGameScreen({super.key, required this.level});

  @override
  State<TDGameScreen> createState() => _TDGameScreenState();
}

class _TDGameScreenState extends State<TDGameScreen> with TickerProviderStateMixin {
  late TDGameProvider _gameProvider;
  late AudioService _audioService;
  late AnimationController _rippleController;
  late AnimationController _shakeController;
  late AnimationController _waveAnimController;
  
  Offset? _rippleOrigin;
  bool _showWaveComplete = false;
  String _waveCompleteText = '';
  int _displayScore = 0;
  int _displayGold = 0;
  double _displayCombo = 1.0;

  @override
  void initState() {
    super.initState();
    _gameProvider = TDGameProvider();
    _audioService = AudioService();
    
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..addListener(() => setState(() {}));
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..addListener(() {
        if (_shakeController.isAnimating) {
          setState(() {});
        }
      });
    
    _waveAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _showWaveComplete = false);
        }
      });
    
    _initGame();
  }

  Future<void> _initGame() async {
    await _audioService.init();
    _audioService.playSfx(SoundType.waveStart);
    _gameProvider.startWave();
    _gameProvider.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    setState(() {});
    _updateDisplayValues();
  }

  void _updateDisplayValues() {
    // Animate score counting up
    if (_displayScore < _gameProvider.score) {
      _displayScore = (_displayScore + ((_gameProvider.score - _displayScore) * 0.2).ceil().clamp(1, 100)).clamp(0, _gameProvider.score);
    }
    if (_displayGold < _gameProvider.gold) {
      _displayGold = (_displayGold + 1).clamp(0, _gameProvider.gold);
    }
    _displayCombo = _gameProvider.combo;
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _shakeController.dispose();
    _waveAnimController.dispose();
    _gameProvider.removeListener(_onGameStateChanged);
    _gameProvider.dispose();
    _audioService.dispose();
    super.dispose();
  }

  void _triggerRipple(Offset position) {
    setState(() => _rippleOrigin = position);
    _rippleController.forward(from: 0);
    _audioService.playSfx(SoundType.tap);
  }

  void _triggerScreenShake() {
    _shakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _showWaveCompleteBanner(String text) {
    setState(() {
      _showWaveComplete = true;
      _waveCompleteText = text;
    });
    _waveAnimController.forward(from: 0);
    _audioService.playSfx(SoundType.waveClear);
  }

  void _onEnemyReachEnd(TDEnemy enemy) {
    _gameProvider.loseLife();
    _triggerScreenShake();
    _audioService.playSfx(SoundType.lifeLost);
    if (_gameProvider.lives <= 0) {
      _handleGameOver();
    }
  }

  void _onEnemyKilled(TDEnemy enemy) {
    _gameProvider.addGold(enemy.goldReward);
    _gameProvider.addScore(enemy.points);
    _gameProvider.incrementCombo();
    _audioService.playSfx(SoundType.kill);
    if (_gameProvider.combo >= 10) {
      _audioService.playSfx(SoundType.achievement);
    }
  }

  void _onTowerPlaced(TDTower tower) {
    _gameProvider.placeTower(tower);
    _audioService.playSfx(SoundType.placeTower);
    _triggerRipple(tower.position);
  }

  void _handleGameOver() {
    _gameProvider.isPlaying = false;
    _showWaveCompleteBanner('💀 遊戲結束');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _handleWaveComplete() {
    final completedWave = _gameProvider.currentWave;
    final nextWave = completedWave + 1;
    if (nextWave > _gameProvider.totalWaves) {
      _showWaveCompleteBanner('🏆 勝利！');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      _showWaveCompleteBanner('✅ 第 $completedWave 波完成');
      Future.delayed(const Duration(milliseconds: 1500), () {
        _gameProvider.startWave();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          // Game field with CustomPainter
          SafeArea(
            child: Column(
              children: [
                _buildHUD(),
                Expanded(
                  child: _buildGameField(),
                ),
                _buildTowerPanel(),
              ],
            ),
          ),
          
          // Wave complete banner
          if (_showWaveComplete)
            _buildWaveCompleteBanner(),
          
          // Ripple effect overlay
          if (_rippleOrigin != null && _rippleController.isAnimating)
            _buildRippleOverlay(),
          
          // Screen shake wrapper
          if (_shakeController.isAnimating)
            _buildShakeOverlay(),
        ],
      ),
    );
  }

  Widget _buildHUD() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _hudItem('❤️', '${_gameProvider.lives}', Colors.pinkAccent),
              _hudItem('💰', '$_displayGold', AppTheme.textGold),
              _hudItem('🌊', '${_gameProvider.currentWave}/${_gameProvider.totalWaves}', Colors.lightBlueAccent),
              _hudItem('💯', '$_displayScore', Colors.white),
              _hudItem('🔥', 'x${_displayCombo.toStringAsFixed(1)}', Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _gameProvider.waveProgress,
              backgroundColor: AppTheme.surface,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.success),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudItem(String emoji, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameField() {
    return GestureDetector(
      onTapDown: (details) {
        final pos = details.localPosition;
        final tappedTower = _gameProvider.towers.where((t) {
          final dx = t.position.dx - pos.dx;
          final dy = t.position.dy - pos.dy;
          return sqrt(dx * dx + dy * dy) < 30;
        }).firstOrNull;

        if (tappedTower != null) {
          _gameProvider.selectTower(tappedTower);
        } else if (_gameProvider.selectedTowerType != null) {
          if (_gameProvider.gold >= _gameProvider.getTowerCost(_gameProvider.selectedTowerType!)) {
            final tower = _gameProvider.createTower(
              _gameProvider.selectedTowerType!,
              pos,
            );
            _onTowerPlaced(tower);
          }
        } else {
          _gameProvider.selectTower(null);
        }
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        child: CustomPaint(
          painter: TDGamePainter(
            towers: _gameProvider.towers,
            enemies: _gameProvider.enemies,
            projectiles: _gameProvider.projectiles,
            selectedTower: _gameProvider.selectedTower,
            pathPoints: _gameProvider.enemyPath,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _buildTowerPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🏗️ 建造塔防',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _towerButton(TDTowerType.basic,  'Basic',  '🔫', _gameProvider.getTowerCost(TDTowerType.basic)),
              _towerButton(TDTowerType.sniper, 'Sniper', '🎯', _gameProvider.getTowerCost(TDTowerType.sniper)),
              _towerButton(TDTowerType.splash, 'Splash', '💥', _gameProvider.getTowerCost(TDTowerType.splash)),
              _towerButton(TDTowerType.slow,   'Slow',   '❄️', _gameProvider.getTowerCost(TDTowerType.slow)),
            ],
          ),
          if (_gameProvider.selectedTower != null) ...[
            const SizedBox(height: 8),
            _buildTowerInfo(_gameProvider.selectedTower!),
          ],
        ],
      ),
    );
  }

  Widget _towerButton(TDTowerType type, String name, String emoji, int cost) {
    final isSelected = _gameProvider.selectedTowerType == type;
    final canAfford = _gameProvider.gold >= cost;
    
    return GestureDetector(
      onTap: () {
        if (canAfford) {
          _gameProvider.selectTowerType(isSelected ? null : type);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
            ? AppTheme.primary.withOpacity(0.5)
            : (canAfford ? AppTheme.surface : Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '💰$cost',
              style: TextStyle(
                color: canAfford ? AppTheme.textGold : Colors.red,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTowerInfo(TDTower tower) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _infoChip('⚔️', '${tower.damage}'),
          _infoChip('📍', '${tower.range.toInt()}'),
          _infoChip('⏱️', '${tower.fireRate}'),
          if (tower.type == TDTowerType.slow)
            _infoChip('❄️', '減速'),
        ],
      ),
    );
  }

  Widget _infoChip(String emoji, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildWaveCompleteBanner() {
    return AnimatedBuilder(
      animation: _waveAnimController,
      builder: (context, child) {
        final progress = _waveAnimController.value;
        final scale = 0.5 + (progress * 0.5);
        final opacity = progress < 0.7 ? 1.0 : (1.0 - ((progress - 0.7) / 0.3));
        
        return Positioned.fill(
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.orangeGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.glowShadow,
                  ),
                  child: Text(
                    _waveCompleteText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRippleOverlay() {
    final progress = _rippleController.value;
    final radius = 100 * progress;
    final opacity = 1.0 - progress;
    
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: RipplePainter(
            center: _rippleOrigin!,
            radius: radius,
            color: AppTheme.primary.withOpacity(opacity * 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildShakeOverlay() {
    final progress = _shakeController.value;
    final dx = sin(progress * pi * 8) * 10 * (1 - progress);
    final dy = cos(progress * pi * 6) * 8 * (1 - progress);
    
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  // Tower stats helpers
}

// ═══════════════════════════════════════════════════════════
//  CUSTOM PAINTER - 遊戲渲染器
// ═══════════════════════════════════════════════════════════

class TDGamePainter extends CustomPainter {
  final List<TDTower> towers;
  final List<TDEnemy> enemies;
  final List<TDProjectile> projectiles;
  final TDTower? selectedTower;
  final List<Offset> pathPoints;

  TDGamePainter({
    required this.towers,
    required this.enemies,
    required this.projectiles,
    this.selectedTower,
    required this.pathPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawPath(canvas);
    _drawTowerRanges(canvas);
    _drawTowers(canvas);
    _drawEnemies(canvas);
    _drawProjectiles(canvas);
  }

  void _drawPath(Canvas canvas) {
    if (pathPoints.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    path.moveTo(pathPoints.first.dx, pathPoints.first.dy);
    for (int i = 1; i < pathPoints.length; i++) {
      path.lineTo(pathPoints[i].dx, pathPoints[i].dy);
    }
    canvas.drawPath(path, paint);
    
    // Draw path dots
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    for (final point in pathPoints) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  void _drawTowerRanges(Canvas canvas) {
    for (final tower in towers) {
      final paint = Paint()
        ..color = _getTowerColor(tower.type).withOpacity(0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tower.position, tower.range, paint);
    }
    
    if (selectedTower != null) {
      final paint = Paint()
        ..color = AppTheme.primary.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(selectedTower!.position, selectedTower!.range, paint);
    }
  }

  void _drawTowers(Canvas canvas) {
    for (final tower in towers) {
      _drawTower(canvas, tower);
    }
  }

  void _drawTower(Canvas canvas, TDTower tower) {
    final center = tower.position;
    final color = _getTowerColor(tower.type);
    
    // Tower base
    final basePaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 20, basePaint);
    
    // Tower body
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    switch (tower.type) {
      case TDTowerType.basic:
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 30, height: 30),
          bodyPaint,
        );
        break;
      case TDTowerType.sniper:
        // Long barrel
        canvas.drawRect(
          Rect.fromCenter(center: center.translate(0, -10), width: 10, height: 30),
          bodyPaint,
        );
        break;
      case TDTowerType.splash:
        // Wide base
        canvas.drawCircle(center, 18, bodyPaint);
        break;
      case TDTowerType.slow:
        // Snowflake shape
        _drawSnowflake(canvas, center, bodyPaint, 15);
        break;
    }
    
    // Tower icon
    final iconPainter = TextPainter(
      text: TextSpan(
        text: _getTowerEmoji(tower.type),
        style: const TextStyle(fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      center - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );
    
    // Range indicator when selected
    if (selectedTower?.id == tower.id) {
      final rangePaint = Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, tower.range, rangePaint);
    }
  }

  void _drawSnowflake(Canvas canvas, Offset center, Paint paint, double size) {
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * pi / 180;
      final endX = center.dx + cos(angle) * size;
      final endY = center.dy + sin(angle) * size;
      canvas.drawLine(center, Offset(endX, endY), paint);
    }
    canvas.drawCircle(center, size * 0.4, paint);
  }

  void _drawEnemies(Canvas canvas) {
    for (final enemy in enemies) {
      _drawEnemy(canvas, enemy);
    }
  }

  void _drawEnemy(Canvas canvas, TDEnemy enemy) {
    final center = enemy.position;
    final healthRatio = enemy.currentHealth / enemy.maxHealth;
    
    // Enemy body
    final color = _getEnemyColor(enemy.type);
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Draw based on enemy type
    switch (enemy.type) {
      case TDEnemyType.normal:
        // Round body
        canvas.drawCircle(center, 15, bodyPaint);
        break;
      case TDEnemyType.fast:
        // Small and pointy
        final path = Path();
        path.moveTo(center.dx, center.dy - 12);
        path.lineTo(center.dx + 10, center.dy + 8);
        path.lineTo(center.dx - 10, center.dy + 8);
        path.close();
        canvas.drawPath(path, bodyPaint);
        break;
      case TDEnemyType.tank:
        // Large square
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 30, height: 30),
          bodyPaint,
        );
        break;
      case TDEnemyType.boss:
        // Big with crown
        canvas.drawCircle(center, 25, bodyPaint);
        // Crown
        final crownPaint = Paint()
          ..color = AppTheme.textGold
          ..style = PaintingStyle.fill;
        final crownPath = Path();
        crownPath.moveTo(center.dx - 20, center.dy - 20);
        crownPath.lineTo(center.dx - 15, center.dy - 35);
        crownPath.lineTo(center.dx - 5, center.dy - 25);
        crownPath.lineTo(center.dx + 5, center.dy - 35);
        crownPath.lineTo(center.dx + 15, center.dy - 25);
        crownPath.lineTo(center.dx + 20, center.dy - 20);
        crownPath.close();
        canvas.drawPath(crownPath, crownPaint);
        break;
    }
    
    // Health bar background
    final healthBgPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(center: center.translate(0, -25), width: 30, height: 4),
      healthBgPaint,
    );
    
    // Health bar
    final healthPaint = Paint()
      ..color = healthRatio > 0.5 ? AppTheme.success : (healthRatio > 0.25 ? Colors.orange : Colors.red)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - 15,
        center.dy - 27,
        30 * healthRatio,
        4,
      ),
      healthPaint,
    );
    
    // Slow effect indicator
    if (enemy.isSlowed) {
      final slowPaint = Paint()
        ..color = Colors.lightBlueAccent.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, 18, slowPaint);
    }
    
    // Enemy icon
    final iconPainter = TextPainter(
      text: TextSpan(
        text: _getEnemyEmoji(enemy.type),
        style: const TextStyle(fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      center - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );
  }

  void _drawProjectiles(Canvas canvas) {
    for (final projectile in projectiles) {
      final paint = Paint()
        ..color = _getProjectileColor(projectile.type)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(projectile.position, 5, paint);
      
      // Trail
      final trailPaint = Paint()
        ..color = _getProjectileColor(projectile.type).withOpacity(0.5)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(
        projectile.position,
        projectile.position - projectile.direction * 10,
        trailPaint,
      );
    }
  }

  Color _getTowerColor(TDTowerType type) {
    switch (type) {
      case TDTowerType.basic: return Colors.green;
      case TDTowerType.sniper: return Colors.purple;
      case TDTowerType.splash: return Colors.orange;
      case TDTowerType.slow: return Colors.lightBlue;
    }
  }

  String _getTowerEmoji(TDTowerType type) {
    switch (type) {
      case TDTowerType.basic: return '🔫';
      case TDTowerType.sniper: return '🎯';
      case TDTowerType.splash: return '💥';
      case TDTowerType.slow: return '❄️';
    }
  }

  Color _getEnemyColor(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.normal: return Colors.brown;
      case TDEnemyType.fast: return Colors.yellow;
      case TDEnemyType.tank: return Colors.red;
      case TDEnemyType.boss: return Colors.deepPurple;
    }
  }

  String _getEnemyEmoji(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.normal: return '🪳';
      case TDEnemyType.fast: return '🏃';
      case TDEnemyType.tank: return '🛡️';
      case TDEnemyType.boss: return '👑';
    }
  }

  Color _getProjectileColor(TDProjectileType type) {
    switch (type) {
      case TDProjectileType.bullet: return Colors.yellow;
      case TDProjectileType.sniper: return Colors.purple;
      case TDProjectileType.explosive: return Colors.orange;
      case TDProjectileType.ice: return Colors.lightBlueAccent;
    }
  }

  @override
  bool shouldRepaint(covariant TDGamePainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════
//  RIPPLE PAINTER - 漣漪效果
// ═══════════════════════════════════════════════════════════

class RipplePainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color color;

  RipplePainter({
    required this.center,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawCircle(center, radius, paint);
    
    // Inner ring
    final innerPaint = Paint()
      ..color = color.withOpacity(color.opacity * 0.5)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius * 0.8, innerPaint);
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) {
    return radius != oldDelegate.radius || center != oldDelegate.center;
  }
}

// ═══════════════════════════════════════════════════════════
//  TD PROVIDER - 塔防遊戲狀態管理
// ═══════════════════════════════════════════════════════════

enum TDTowerType { basic, sniper, splash, slow }
enum TDEnemyType { normal, fast, tank, boss }
enum TDProjectileType { bullet, sniper, explosive, ice }

class TDTower {
  final int id;
  final TDTowerType type;
  final Offset position;
  final int damage;
  final double range;
  final double fireRate;
  DateTime? lastFireTime;

  TDTower({
    required this.id,
    required this.type,
    required this.position,
    required this.damage,
    required this.range,
    required this.fireRate,
    this.lastFireTime,
  });
}

class TDEnemy {
  final int id;
  final TDEnemyType type;
  Offset position;
  final double speed;
  final int maxHealth;
  int currentHealth;
  final int goldReward;
  final int points;
  bool isSlowed;
  DateTime? slowEndTime;
  double pathProgress;

  TDEnemy({
    required this.id,
    required this.type,
    required this.position,
    required this.speed,
    required this.maxHealth,
    required this.currentHealth,
    required this.goldReward,
    required this.points,
    this.isSlowed = false,
    this.pathProgress = 0,
  });
}

class TDProjectile {
  Offset position;
  final Offset direction;
  final int damage;
  final TDProjectileType type;
  final double speed;

  TDProjectile({
    required this.position,
    required this.direction,
    required this.damage,
    required this.type,
    required this.speed,
  });
}

class TDGameProvider extends ChangeNotifier {
  // Game state
  int lives = 10;
  int gold = 100;
  int score = 0;
  double combo = 1.0;
  int comboCount = 0;
  int currentWave = 0;
  int totalWaves = 10;
  bool isPlaying = true;
  
  // Objects
  List<TDTower> towers = [];
  List<TDEnemy> enemies = [];
  List<TDProjectile> projectiles = [];
  List<Offset> enemyPath = [];
  
  // Selection state
  TDTowerType? selectedTowerType;
  TDTower? selectedTower;
  
  // Wave management
  Timer? _waveTimer;
  Timer? _enemySpawnTimer;
  Timer? _gameLoopTimer;
  int _enemyIdCounter = 0;
  int _enemiesSpawnedThisWave = 0;
  int _enemiesPerWave = 10;
  
  // Path waypoints (will be populated in init)
  final List<Offset> _waypoints = [];

  double get waveProgress {
    if (_enemiesPerWave == 0) return 0.0;
    final killed = _enemiesSpawnedThisWave - enemies.length;
    return (killed / _enemiesPerWave).clamp(0.0, 1.0);
  }

  TDGameProvider() {
    _initPath();
  }

  void _initPath() {
    // Create a winding path for enemies
    _waypoints.addAll([
      const Offset(50, 100),
      const Offset(150, 100),
      const Offset(150, 250),
      const Offset(300, 250),
      const Offset(300, 150),
      const Offset(400, 150),
      const Offset(400, 350),
      const Offset(200, 350),
      const Offset(200, 450),
      const Offset(350, 450),
      const Offset(350, 550),
      const Offset(50, 550),
    ]);
    enemyPath = List.from(_waypoints);
  }

  void startWave() {
    currentWave++;
    _enemiesSpawnedThisWave = 0;
    _enemiesPerWave = 10 + (currentWave * 2);
    
    // Spawn enemies periodically
    final spawnInterval = 2000 - (currentWave * 100).clamp(0, 1500);
    _enemySpawnTimer?.cancel();
    _enemySpawnTimer = Timer.periodic(Duration(milliseconds: spawnInterval), (_) {
      if (_enemiesSpawnedThisWave < _enemiesPerWave && isPlaying) {
        _spawnEnemy();
        _enemiesSpawnedThisWave++;
      } else {
        _enemySpawnTimer?.cancel();
      }
    });
    
    // Start game loop for tower targeting
    _startGameLoop();
  }

  void _spawnEnemy() {
    TDEnemyType type;
    final roll = Random().nextDouble();
    
    if (currentWave >= 8 && roll < 0.1) {
      type = TDEnemyType.boss;
    } else if (currentWave >= 5 && roll < 0.3) {
      type = TDEnemyType.tank;
    } else if (roll < 0.4) {
      type = TDEnemyType.fast;
    } else {
      type = TDEnemyType.normal;
    }
    
    final enemy = TDEnemy(
      id: _enemyIdCounter++,
      type: type,
      position: _waypoints.first,
      speed: _getEnemySpeed(type),
      maxHealth: _getEnemyHealth(type),
      currentHealth: _getEnemyHealth(type),
      goldReward: _getEnemyGoldReward(type),
      points: _getEnemyPoints(type),
    );
    
    enemies.add(enemy);
  }

  double _getEnemySpeed(TDEnemyType type) {
    final baseSpeed = 0.5 + (currentWave * 0.05);
    switch (type) {
      case TDEnemyType.fast: return baseSpeed * 2.0;
      case TDEnemyType.tank: return baseSpeed * 0.5;
      case TDEnemyType.boss: return baseSpeed * 0.7;
      default: return baseSpeed;
    }
  }

  int _getEnemyHealth(TDEnemyType type) {
    final baseHealth = 50 + (currentWave * 20);
    switch (type) {
      case TDEnemyType.fast: return (baseHealth * 0.5).round();
      case TDEnemyType.tank: return (baseHealth * 3).round();
      case TDEnemyType.boss: return (baseHealth * 5).round();
      default: return baseHealth;
    }
  }

  int _getEnemyGoldReward(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.fast: return 5;
      case TDEnemyType.tank: return 20;
      case TDEnemyType.boss: return 50;
      default: return 10;
    }
  }

  int _getEnemyPoints(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.fast: return 15;
      case TDEnemyType.tank: return 30;
      case TDEnemyType.boss: return 100;
      default: return 10;
    }
  }

  void _startGameLoop() {
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _updateGame();
    });
  }

  void _updateGame() {
    if (!isPlaying) return;
    
    _moveEnemies();
    _updateTowers();
    _moveProjectiles();
    _checkProjectileCollisions();
    _removeDeadEnemies();
    _checkWaveComplete();
    
    notifyListeners();
  }

  void _moveEnemies() {
    for (final enemy in enemies) {
      if (enemy.pathProgress >= _waypoints.length - 1) continue;
      
      final currentPoint = _waypoints[enemy.pathProgress.floor()];
      final nextPoint = _waypoints[(enemy.pathProgress.floor() + 1).clamp(0, _waypoints.length - 1)];
      
      final targetPos = nextPoint;
      final dx = targetPos.dx - enemy.position.dx;
      final dy = targetPos.dy - enemy.position.dy;
      final dist = sqrt(dx * dx + dy * dy);
      
      if (dist < 5) {
        enemy.pathProgress += 1;
      } else {
        final speed = enemy.isSlowed ? enemy.speed * 0.5 : enemy.speed;
        enemy.position = Offset(
          enemy.position.dx + (dx / dist) * speed,
          enemy.position.dy + (dy / dist) * speed,
        );
      }
      
      // Check slow effect
      if (enemy.isSlowed && enemy.slowEndTime != null) {
        if (DateTime.now().isAfter(enemy.slowEndTime!)) {
          enemy.isSlowed = false;
        }
      }
      
      // Check if enemy reached the end
      if (enemy.pathProgress >= _waypoints.length - 1) {
        // Enemy reached end - will be handled by loseLife
      }
    }
  }

  void _updateTowers() {
    for (final tower in towers) {
      final now = DateTime.now();
      if (tower.lastFireTime != null &&
          now.difference(tower.lastFireTime!).inMilliseconds < (1000 / tower.fireRate).round()) {
        continue;
      }

      TDEnemy? target;
      double closestDist = double.infinity;

      for (final enemy in enemies) {
        final dx = enemy.position.dx - tower.position.dx;
        final dy = enemy.position.dy - tower.position.dy;
        final dist = sqrt(dx * dx + dy * dy);

        if (dist <= tower.range && dist < closestDist) {
          closestDist = dist;
          target = enemy;
        }
      }

      if (target != null) {
        _fireTower(tower, target);
        tower.lastFireTime = now;
      }
    }
  }

  static final _projectileSpeeds = {
    TDProjectileType.bullet:    10.0,
    TDProjectileType.sniper:    20.0,
    TDProjectileType.explosive:  8.0,
    TDProjectileType.ice:        7.0,
  };

  TDProjectileType _getProjectileType(TDTowerType type) {
    switch (type) {
      case TDTowerType.basic: return TDProjectileType.bullet;
      case TDTowerType.sniper: return TDProjectileType.sniper;
      case TDTowerType.splash: return TDProjectileType.explosive;
      case TDTowerType.slow: return TDProjectileType.ice;
    }
  }

  void _fireTower(TDTower tower, TDEnemy target) {
    final dx = target.position.dx - tower.position.dx;
    final dy = target.position.dy - tower.position.dy;
    final dist = sqrt(dx * dx + dy * dy);

    final projectileType = _getProjectileType(tower.type);
    final projectile = TDProjectile(
      position: tower.position,
      direction: Offset(dx / dist, dy / dist),
      damage: tower.damage,
      type: projectileType,
      speed: _projectileSpeeds[projectileType]!,
    );

    projectiles.add(projectile);
  }

  void _moveProjectiles() {
    for (final projectile in projectiles) {
      projectile.position = Offset(
        projectile.position.dx + projectile.direction.dx * projectile.speed,
        projectile.position.dy + projectile.direction.dy * projectile.speed,
      );
    }

    // Remove off-screen projectiles
    projectiles.removeWhere((p) =>
      p.position.dx < -50 ||
      p.position.dx > 600 ||
      p.position.dy < -50 ||
      p.position.dy > 800);
  }

  void _checkProjectileCollisions() {
    final toRemove = <TDProjectile>[];
    final enemiesToRemove = <TDEnemy>[];
    
    for (final projectile in projectiles) {
      for (final enemy in enemies) {
        final dx = projectile.position.dx - enemy.position.dx;
        final dy = projectile.position.dy - enemy.position.dy;
        final dist = sqrt(dx * dx + dy * dy);
        
        if (dist < 20) {
          enemy.currentHealth -= projectile.damage;
          
          // Apply slow effect for ice projectiles
          if (projectile.type == TDProjectileType.ice) {
            enemy.isSlowed = true;
            enemy.slowEndTime = DateTime.now().add(const Duration(seconds: 2));
          }
          
          // Apply splash damage for explosive projectiles
          // Splash only affects enemies in 25-50px ring (not the direct-hit target)
          if (projectile.type == TDProjectileType.explosive) {
            for (final other in enemies) {
              if (other == enemy) continue; // skip direct-hit target
              final odx = other.position.dx - projectile.position.dx;
              final ody = other.position.dy - projectile.position.dy;
              if (sqrt(odx * odx + ody * ody) < 50) {
                other.currentHealth -= (projectile.damage * 0.5).round();
              }
            }
          }
          
          if (enemy.currentHealth <= 0) {
            enemiesToRemove.add(enemy);
          }
          
          toRemove.add(projectile);
          break;
        }
      }
    }
    
    for (final p in toRemove) {
      projectiles.remove(p);
    }
    for (final e in enemiesToRemove) {
      _onEnemyKilled(e); // play kill/achievement audio + add gold/score
      enemies.remove(e);
    }
  }

  void _removeDeadEnemies() {
    final escaped = enemies.where((e) => e.pathProgress >= _waypoints.length - 1).toList();
    for (final e in escaped) {
      loseLife();
    }
    enemies.removeWhere((e) =>
      e.currentHealth <= 0 ||
      e.pathProgress >= _waypoints.length - 1);
  }

  void _checkWaveComplete() {
    if (_enemiesSpawnedThisWave >= _enemiesPerWave && 
        enemies.isEmpty && 
        _enemySpawnTimer?.isActive != true) {
      _gameLoopTimer?.cancel();
      // Wave complete - handled by screen
    }
  }

  void placeTower(TDTower tower) {
    final cost = getTowerCost(tower.type);
    if (gold >= cost) {
      gold -= cost;
      towers.add(tower);
      notifyListeners();
    }
  }

  // ─── Tower factory (single source of truth) ───
  static final _towerStats = {
    TDTowerType.basic:  (cost: 50,  damage: 10, range: 100.0, fireRate: 0.5),
    TDTowerType.sniper: (cost: 100, damage: 50, range: 200.0, fireRate: 1.5),
    TDTowerType.splash: (cost: 150, damage: 25, range: 80.0,  fireRate: 0.8),
    TDTowerType.slow:   (cost: 75,  damage: 5,  range: 120.0, fireRate: 0.3),
  };

  int getTowerCost(TDTowerType type) => _towerStats[type]!.cost;

  TDTower createTower(TDTowerType type, Offset position) {
    final stats = _towerStats[type]!;
    return TDTower(
      id: DateTime.now().millisecondsSinceEpoch,
      type: type,
      position: position,
      damage: stats.damage,
      range: stats.range,
      fireRate: stats.fireRate,
    );
  }

  void selectTowerType(TDTowerType? type) {
    selectedTowerType = type;
    selectedTower = null;
    notifyListeners();
  }

  void selectTower(TDTower? tower) {
    selectedTower = tower;
    selectedTowerType = null;
    notifyListeners();
  }

  void addGold(int amount) {
    gold += amount;
    notifyListeners();
  }

  void addScore(int amount) {
    score += (amount * combo).round();
    notifyListeners();
  }

  void incrementCombo() {
    comboCount++;
    if (comboCount >= 10) {
      combo = 2.5;
    } else if (comboCount >= 5) {
      combo = 1.5;
    } else if (comboCount >= 3) {
      combo = 1.2;
    }
    notifyListeners();
  }

  void loseLife() {
    lives--;
    comboCount = 0;
    combo = 1.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    _enemySpawnTimer?.cancel();
    _gameLoopTimer?.cancel();
    super.dispose();
  }
}