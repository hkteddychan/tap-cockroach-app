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

// Phase 5: Floating text data class
class _FloatingText {
  String text;
  Offset position;
  Color color;
  double opacity;
  double velocityY;

  _FloatingText({
    required this.text,
    required this.position,
    required this.color,
    this.opacity = 1.0,
    this.velocityY = -2.0,
  });

  void update(double dt) {
    position = Offset(position.dx, position.dy + velocityY);
    opacity -= dt * 1.2;
    if (opacity < 0) opacity = 0;
  }
}

// Phase 10: Kill particle data class
class _KillParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double opacity;
  double life;

  _KillParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    this.opacity = 1.0,
    this.life = 1.0,
  });

  void update(double dt) {
    position = Offset(position.dx + velocity.dx * dt * 60, position.dy + velocity.dy * dt * 60);
    life -= dt * 2.0;
    opacity = life.clamp(0.0, 1.0);
    size *= 0.98;
    if (size < 0.5) size = 0.5;
  }
}

class TDGameScreen extends StatefulWidget {
  final int level;
  const TDGameScreen({super.key, required this.level});

  @override
  State<TDGameScreen> createState() => _TDGameScreenState();
}

class _TDGameScreenState extends State<TDGameScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
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
  bool _isPaused = false;
  double _gameSpeed = 1.0;
  bool _soundEnabled = true;

  // Phase 4: Tower range preview
  Offset? _towerPreviewPosition;

  // Phase 5: Floating text for gold popups
  final List<_FloatingText> _floatingTexts = [];

  // Phase 5: Animation controller for floating texts
  late AnimationController _floatTextController;

  // Phase 10: Kill particles for death effects
  final List<_KillParticle> _killParticles = [];

  // Phase 10: Screen flash on kill (white overlay)
  bool _showKillFlash = false;

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
    
    _floatTextController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..addListener(() {
        setState(() {
          // Update floating texts positions and opacity
          for (final ft in _floatingTexts) {
            ft.update(0.05);
          }
          _floatingTexts.removeWhere((ft) => ft.opacity <= 0);
        });
      });
    
    WidgetsBinding.instance.addObserver(this);
    _initGame();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _gameProvider.pauseGame();
      setState(() => _isPaused = true);
    } else if (state == AppLifecycleState.resumed) {
      _gameProvider.resumeGame();
      setState(() => _isPaused = false);
    }
  }

  Future<void> _initGame() async {
    await _audioService.init();
    if (_soundEnabled) _audioService.playSfx(SoundType.waveStart);
    _gameProvider.startWave();
    _gameProvider.onEnemyKilled = _onEnemyKilled;
    _gameProvider.onEnemyReachEnd = _onEnemyReachEnd;
    _gameProvider.onWaveComplete = _handleWaveComplete;
    _gameProvider.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    setState(() {
      _updateDisplayValues();
      // Phase 10: Animate kill particles
      for (final p in _killParticles) {
        p.update(0.05);
      }
      _killParticles.removeWhere((p) => p.life <= 0);
    });
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
    WidgetsBinding.instance.removeObserver(this);
    _rippleController.dispose();
    _shakeController.dispose();
    _waveAnimController.dispose();
    _floatTextController.dispose();
    _gameProvider.removeListener(_onGameStateChanged);
    _gameProvider.dispose();
    _audioService.dispose();
    super.dispose();
  }

  void _triggerRipple(Offset position) {
    setState(() => _rippleOrigin = position);
    _rippleController.forward(from: 0);
    if (_soundEnabled) _audioService.playSfx(SoundType.tap);
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
    if (_soundEnabled) _audioService.playSfx(SoundType.waveClear);
  }

  void _onEnemyReachEnd(TDEnemy enemy) {
    _gameProvider.loseLife();
    _triggerScreenShake();
    if (_soundEnabled) _audioService.playSfx(SoundType.lifeLost);
    if (_gameProvider.lives <= 0) {
      _handleGameOver();
    }
  }

  void _onEnemyKilled(TDEnemy enemy) {
    _gameProvider.addGold(enemy.goldReward);
    _gameProvider.addScore(enemy.points);
    _gameProvider.incrementCombo();
    if (_soundEnabled) _audioService.playSfx(SoundType.kill);
    
    // Phase 5: Show floating gold text
    _addFloatingText(
      '+${enemy.goldReward} 💰',
      enemy.position,
      Colors.amber,
    );
    
    // Phase 10: Spawn kill particles and screen flash
    _spawnKillParticles(enemy.position, _getEnemyColor(enemy.type));
    _triggerKillFlash();
    
    if (_gameProvider.comboCount >= 10) {
      if (_soundEnabled) _audioService.playSfx(SoundType.achievement);
    }
  }

  // Phase 10: Spawn kill particles at enemy death position
  void _spawnKillParticles(Offset position, Color color) {
    final random = Random();
    for (int i = 0; i < 12; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = 2.0 + random.nextDouble() * 4.0;
      _killParticles.add(_KillParticle(
        position: position,
        velocity: Offset(cos(angle) * speed, sin(angle) * speed),
        color: color,
        size: 6.0 + random.nextDouble() * 6.0,
      ));
    }
  }

  // Phase 10: Get enemy color by type (helper method)
  Color _getEnemyColor(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.normal: return Colors.brown;
      case TDEnemyType.fast: return Colors.yellow;
      case TDEnemyType.tank: return Colors.red;
      case TDEnemyType.boss: return Colors.deepPurple;
    }
  }

  // Phase 10: Trigger white screen flash for 50ms
  void _triggerKillFlash() {
    setState(() => _showKillFlash = true);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _showKillFlash = false);
    });
  }

  // Phase 5: Add floating text
  void _addFloatingText(String text, Offset position, Color color) {
    _floatingTexts.add(_FloatingText(
      text: text,
      position: position,
      color: color,
    ));
    if (!_floatTextController.isAnimating) {
      _floatTextController.forward(from: 0);
    }
  }

  void _onTowerPlaced(TDTower tower) {
    _gameProvider.placeTower(tower);
    if (_soundEnabled) _audioService.playSfx(SoundType.placeTower);
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
          
          // Phase 10: Kill flash overlay (white screen flash on enemy death)
          if (_showKillFlash)
            Container(color: Colors.white.withOpacity(0.3)),
          
          // Pause overlay
          if (_isPaused)
            _buildPauseOverlay(),
        ],
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.pause_circle_filled,
                color: Colors.white,
                size: 80,
              ),
              const SizedBox(height: 20),
              const Text(
                '⏸️ 遊戲暫停',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () {
                  _gameProvider.resumeGame();
                  setState(() => _isPaused = false);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        '繼續遊戲',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
              _buildSpeedControl(),
              _buildPauseButton(),
            ],
          ),
          const SizedBox(height: 8),
          // Wave info bar - Phase 8
          _buildWaveInfoBar(),
        ],
      ),
    );
  }

  // Phase 8: Wave info bar showing wave progress, enemies count, next wave preview
  Widget _buildWaveInfoBar() {
    final currentWave = _gameProvider.currentWave;
    final totalWaves = _gameProvider.totalWaves;
    final enemiesOnField = _gameProvider.enemies.length;
    final waveProgress = _gameProvider.waveProgress;
    final nextWavePreview = currentWave < totalWaves ? '第 ${currentWave + 1} 波' : '最終波';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Wave counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '🌊 $currentWave/$totalWaves',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Enemies on field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👾', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  '$enemiesOnField',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Mini progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: waveProgress,
                    backgroundColor: Colors.black38,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      enemiesOnField > 0 ? AppTheme.success : Colors.grey,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enemiesOnField > 0 ? '消滅敵人中...' : '等待下一波',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Next wave preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('➡️', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text(
                  nextWavePreview,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedControl() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _speedButton('1x', 1.0),
        _speedButton('2x', 2.0),
        _speedButton('5x', 5.0),
        _speedButton('10x', 10.0),
      ],
    );
  }

  Widget _speedButton(String label, double speed) {
    final isSelected = _gameSpeed == speed;
    return GestureDetector(
      onTap: () {
        setState(() => _gameSpeed = speed);
        _gameProvider.setGameSpeed(speed);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.7) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.white30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPauseButton() {
    return GestureDetector(
      onTap: () {
        if (_isPaused) {
          _gameProvider.resumeGame();
        } else {
          _gameProvider.pauseGame();
        }
        setState(() => _isPaused = !_isPaused);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _isPaused ? AppTheme.success.withOpacity(0.5) : Colors.black38,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _isPaused ? Icons.play_arrow : Icons.pause,
          color: Colors.white,
          size: 20,
        ),
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
          setState(() => _towerPreviewPosition = null);
        } else if (_gameProvider.selectedTowerType != null) {
          if (_gameProvider.gold >= _gameProvider.getTowerCost(_gameProvider.selectedTowerType!)) {
            final tower = _gameProvider.createTower(
              _gameProvider.selectedTowerType!,
              pos,
            );
            _onTowerPlaced(tower);
          }
          setState(() => _towerPreviewPosition = null);
        } else {
          _gameProvider.selectTower(null);
          setState(() => _towerPreviewPosition = null);
        }
      },
      // Phase 4: Pan tracking for tower range preview
      onPanUpdate: (details) {
        if (_gameProvider.selectedTowerType != null) {
          setState(() => _towerPreviewPosition = details.localPosition);
        }
      },
      onPanEnd: (_) {
        setState(() => _towerPreviewPosition = null);
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
            towerPreviewPosition: _towerPreviewPosition,
            towerPreviewType: _gameProvider.selectedTowerType,
            floatingTexts: _floatingTexts,
            killParticles: _killParticles,
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
          // Header with title and control buttons - Phase 9
          Row(
            children: [
              const Text(
                '🏗️ 建造塔防',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Sound toggle button - Phase 9
              GestureDetector(
                onTap: () {
                  setState(() => _soundEnabled = !_soundEnabled);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _soundEnabled ? AppTheme.success.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _soundEnabled ? AppTheme.success : Colors.grey,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _soundEnabled ? '🔊' : '🔇',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _soundEnabled ? '聲音' : '靜音',
                        style: TextStyle(
                          color: _soundEnabled ? AppTheme.success : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Divider
              Container(
                width: 1,
                height: 20,
                color: Colors.white24,
              ),
              const SizedBox(width: 8),
              // Pause button - Phase 9
              GestureDetector(
                onTap: () {
                  if (_isPaused) {
                    _gameProvider.resumeGame();
                  } else {
                    _gameProvider.pauseGame();
                  }
                  setState(() => _isPaused = !_isPaused);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _isPaused ? AppTheme.success.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isPaused ? AppTheme.success : Colors.grey,
                    ),
                  ),
                  child: Icon(
                    _isPaused ? Icons.play_arrow : Icons.pause,
                    color: _isPaused ? AppTheme.success : Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ],
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
    final upgradeCost = _gameProvider.getTowerUpgradeCost(tower);
    final sellValue = _gameProvider.getTowerSellValue(tower);
    final canUpgrade = tower.level < 3 && _gameProvider.gold >= upgradeCost;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _infoChip('⚔️', '${tower.damage}'),
              _infoChip('📍', '${tower.range.toInt()}'),
              _infoChip('⏱️', '${tower.fireRate}'),
              _infoChip('⬆️', 'Lv${tower.level}'),
              if (tower.type == TDTowerType.slow)
                _infoChip('❄️', '減速'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Upgrade button
              GestureDetector(
                onTap: canUpgrade
                    ? () {
                        _gameProvider.upgradeTower(tower);
                        HapticFeedback.mediumImpact();
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: canUpgrade ? AppTheme.success : Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tower.level < 3 ? '⬆️ 升級 💰$upgradeCost' : '已滿級',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              // Sell button - Phase 7: Prominent red
              GestureDetector(
                onTap: () {
                  _gameProvider.sellTower(tower);
                  HapticFeedback.mediumImpact();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade300, width: 2),
                    boxShadow: [
                      BoxShadow(color: AppTheme.error.withOpacity(0.5), blurRadius: 8, spreadRadius: 1),
                    ],
                  ),
                  child: Text(
                    '🏷️ 出售 +💰$sellValue',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
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
  // Phase 4: Tower preview
  final Offset? towerPreviewPosition;
  final TDTowerType? towerPreviewType;
  // Phase 5: Floating texts
  final List<_FloatingText> floatingTexts;
  // Phase 10: Kill particles
  final List<_KillParticle> killParticles;

  TDGamePainter({
    required this.towers,
    required this.enemies,
    required this.projectiles,
    this.selectedTower,
    required this.pathPoints,
    this.towerPreviewPosition,
    this.towerPreviewType,
    required this.floatingTexts,
    required this.killParticles,
  });

  // Phase 11: Animation time for pulsing effects
  double _animTime = 0.0;
  
  @override
  void paint(Canvas canvas, Size size) {
    _animTime += 0.05;
    _drawPath(canvas);
    _drawTowerRanges(canvas);
    _drawTowers(canvas);
    _drawEnemies(canvas);
    _drawProjectiles(canvas);
    // Phase 4: Draw tower preview circle
    _drawTowerPreview(canvas);
    // Phase 5: Draw floating texts
    _drawFloatingTexts(canvas);
    // Phase 10: Draw kill particles
    _drawKillParticles(canvas);
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
    
    // Phase 11: Pulsing glow effect on tower base
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3 + 0.15 * sin(_animTime * 3))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 24 + 2 * sin(_animTime * 3), glowPaint);
    
    // Tower base
    final basePaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 20, basePaint);
    
    // Phase 11: Tower barrel rotation and muzzle flash
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tower.targetAngle);
    
    // Tower body (rotated with barrel)
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    switch (tower.type) {
      case TDTowerType.basic:
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 30, height: 30),
          bodyPaint,
        );
        break;
      case TDTowerType.sniper:
        // Long barrel
        canvas.drawRect(
          Rect.fromCenter(center: const Offset(0, -10), width: 10, height: 30),
          bodyPaint,
        );
        break;
      case TDTowerType.splash:
        // Wide base
        canvas.drawCircle(const Offset(0, 0), 18, bodyPaint);
        break;
      case TDTowerType.slow:
        // Snowflake shape
        canvas.restore();
        _drawSnowflake(canvas, center, bodyPaint, 15);
        break;
    }
    
    // Muzzle flash effect when firing
    if (tower.muzzleFlashTime > 0) {
      final flashPaint = Paint()
        ..color = Colors.yellow.withOpacity(tower.muzzleFlashTime * 4)
        ..style = PaintingStyle.fill;
      if (tower.type != TDTowerType.slow) {
        canvas.drawCircle(const Offset(15, 0), 8 * tower.muzzleFlashTime, flashPaint);
        canvas.drawCircle(const Offset(15, 0), 5 * tower.muzzleFlashTime, flashPaint..color = Colors.white);
      }
    }
    
    if (tower.type != TDTowerType.slow) {
      canvas.restore();
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
    
    // Phase 11: Draw upgrade stars below tower
    _drawUpgradeStars(canvas, tower);
    
    // Range indicator when selected
    if (selectedTower?.id == tower.id) {
      final rangePaint = Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, tower.range, rangePaint);
    }
  }

  // Phase 11: Draw upgrade stars below tower
  void _drawUpgradeStars(Canvas canvas, TDTower tower) {
    if (tower.level <= 0) return;
    
    final starCenter = Offset(tower.position.dx, tower.position.dy + 30);
    
    for (int i = 0; i < tower.level; i++) {
      final xOffset = (i - (tower.level - 1) / 2) * 12;
      final starPos = Offset(starCenter.dx + xOffset, starCenter.dy);
      final starPaint = Paint()
        ..color = AppTheme.textGold
        ..style = PaintingStyle.fill;
      _drawStar(canvas, starPos, 5, starPaint);
    }
  }

  // Phase 11: Helper to draw a star shape
  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 144 - 90) * pi / 180;
      final x = center.dx + cos(angle) * size;
      final y = center.dy + sin(angle) * size;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
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
    final color = _getEnemyColor(enemy.type);
    
    // Phase 11: Pulsing glow on all enemies
    final glowPaint = Paint()
      ..color = color.withOpacity(0.4 + 0.2 * sin(_animTime * 4 + enemy.id))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 20 + 3 * sin(_animTime * 4 + enemy.id), glowPaint);
    
    // Phase 11: Motion trail for fast enemies
    if (enemy.type == TDEnemyType.fast && enemy.trailPositions.isNotEmpty) {
      for (int i = 0; i < enemy.trailPositions.length; i++) {
        final trailPos = enemy.trailPositions[i];
        final trailOpacity = (1 - i / enemy.trailPositions.length) * 0.4;
        final trailPaint = Paint()
          ..color = Colors.yellow.withOpacity(trailOpacity)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(trailPos, 8 - i * 1.5, trailPaint);
      }
    }
    
    // Phase 11: Enemy body with rotation toward movement direction
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(enemy.movementAngle + pi / 2); // + pi/2 to orient correctly
    
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Draw based on enemy type
    switch (enemy.type) {
      case TDEnemyType.normal:
        // Round body
        canvas.drawCircle(Offset.zero, 15, bodyPaint);
        break;
      case TDEnemyType.fast:
        // Small and pointy
        final path = Path();
        path.moveTo(0, -12);
        path.lineTo(10, 8);
        path.lineTo(-10, 8);
        path.close();
        canvas.drawPath(path, bodyPaint);
        break;
      case TDEnemyType.tank:
        // Large square with shield shimmer
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 30, height: 30),
          bodyPaint,
        );
        // Phase 11: Tank shield shimmer
        final shieldPaint = Paint()
          ..color = Colors.white.withOpacity(0.3 + 0.2 * sin(_animTime * 6))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 36, height: 36),
          shieldPaint,
        );
        break;
      case TDEnemyType.boss:
        // Big circle
        canvas.drawCircle(Offset.zero, 25, bodyPaint);
        break;
    }
    
    canvas.restore();
    
    // Phase 11: Boss crown with shimmer effect
    if (enemy.type == TDEnemyType.boss) {
      final crownShimmer = 0.7 + 0.3 * sin(_animTime * 8);
      final crownPaint = Paint()
        ..color = AppTheme.textGold.withOpacity(crownShimmer)
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
    }
    
    // Health bar background - Phase 6: size varies by enemy type
    final barWidth = _getHealthBarWidth(enemy.type);
    final barHeight = _getHealthBarHeight(enemy.type);
    final barYOffset = _getHealthBarYOffset(enemy.type);
    
    final healthBgPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(center: center.translate(0, barYOffset), width: barWidth, height: barHeight),
      healthBgPaint,
    );
    
    // Health bar
    final healthPaint = Paint()
      ..color = healthRatio > 0.5 ? AppTheme.success : (healthRatio > 0.25 ? Colors.orange : Colors.red)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - barWidth / 2,
        center.dy - barHeight / 2 + barYOffset,
        barWidth * healthRatio,
        barHeight,
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
    
    // Enemy icon (centered, doesn't rotate)
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

  // Phase 4: Draw tower range preview circle when finger moves
  void _drawTowerPreview(Canvas canvas) {
    if (towerPreviewPosition == null || towerPreviewType == null) return;
    
    final range = TDGameProvider.getTowerBaseRange(towerPreviewType!);
    final color = _getTowerColor(towerPreviewType!);
    
    // Semi-transparent fill
    final fillPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(towerPreviewPosition!, range, fillPaint);
    
    // Border
    final borderPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(towerPreviewPosition!, range, borderPaint);
    
    // Center dot
    final centerPaint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(towerPreviewPosition!, 15, centerPaint);
    
    // Tower icon preview
    final iconPainter = TextPainter(
      text: TextSpan(
        text: _getTowerEmoji(towerPreviewType!),
        style: const TextStyle(fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      towerPreviewPosition! - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );
  }

  // Phase 5: Draw floating gold texts
  void _drawFloatingTexts(Canvas canvas) {
    for (final ft in floatingTexts) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withOpacity(ft.opacity.clamp(0.0, 1.0)),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        ft.position - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  // Phase 10: Draw kill particles (death burst effect)
  void _drawKillParticles(Canvas canvas) {
    for (final p in killParticles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p.position, p.size, paint);
    }
  }

  // Phase 6: Health bar width by enemy type
  double _getHealthBarWidth(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.boss: return 50;
      case TDEnemyType.tank: return 40;
      case TDEnemyType.fast: return 24;
      default: return 30;
    }
  }

  // Phase 6: Health bar height by enemy type
  double _getHealthBarHeight(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.boss: return 8;
      case TDEnemyType.tank: return 6;
      case TDEnemyType.fast: return 3;
      default: return 4;
    }
  }

  // Phase 6: Health bar Y offset by enemy type
  double _getHealthBarYOffset(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.boss: return -35;
      case TDEnemyType.tank: return -28;
      case TDEnemyType.fast: return -20;
      default: return -25;
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
  int damage;
  double range;
  double fireRate;
  DateTime? lastFireTime;
  int level; // Phase 3: Tower level 1-3
  // Phase 11: Rotation angle toward target
  double targetAngle;
  // Phase 11: Muzzle flash timer
  double muzzleFlashTime;

  TDTower({
    required this.id,
    required this.type,
    required this.position,
    required this.damage,
    required this.range,
    required this.fireRate,
    this.lastFireTime,
    this.level = 1,
    this.targetAngle = 0.0,
    this.muzzleFlashTime = 0.0,
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
  // Phase 11: Movement direction angle for facing direction
  double movementAngle;
  // Phase 11: Motion trail positions for fast enemies
  List<Offset> trailPositions;

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
    this.movementAngle = 0.0,
    List<Offset>? trailPositions,
  }) : trailPositions = trailPositions ?? [];
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
  bool _isPaused = false;
  double _gameSpeed = 1.0;

  // Callbacks to State (set during initState)
  void Function(TDEnemy)? onEnemyKilled;
  void Function()? onWaveComplete;
  void Function(TDEnemy)? onEnemyReachEnd;
  
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
        // Phase 11: Track movement direction
        enemy.movementAngle = atan2(dy, dx);
        
        enemy.position = Offset(
          enemy.position.dx + (dx / dist) * speed * _gameSpeed,
          enemy.position.dy + (dy / dist) * speed * _gameSpeed,
        );
        
        // Phase 11: Update trail positions for fast enemies
        if (enemy.type == TDEnemyType.fast) {
          enemy.trailPositions.insert(0, enemy.position);
          if (enemy.trailPositions.length > 5) {
            enemy.trailPositions.removeLast();
          }
        }
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
      // Phase 11: Decay muzzle flash timer
      if (tower.muzzleFlashTime > 0) {
        tower.muzzleFlashTime -= 0.05;
        if (tower.muzzleFlashTime < 0) tower.muzzleFlashTime = 0;
      }
      
      final now = DateTime.now();
      // fireRate = shots per second (e.g. 0.5 = 1 shot every 2 seconds)
      final cooldownMs = (1000 / tower.fireRate).round();
      if (tower.lastFireTime != null &&
          now.difference(tower.lastFireTime!).inMilliseconds < cooldownMs) {
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

    // Phase 11: Set tower rotation angle toward target
    tower.targetAngle = atan2(dy, dx);
    tower.muzzleFlashTime = 0.15; // 150ms muzzle flash

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
        projectile.position.dx + projectile.direction.dx * projectile.speed * _gameSpeed,
        projectile.position.dy + projectile.direction.dy * projectile.speed * _gameSpeed,
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
      onEnemyKilled?.call(e); // play kill audio + add gold/score (callback to State)
      enemies.remove(e);
    }
  }

  void _removeDeadEnemies() {
    // Handle escaped enemies: fire callback to State (screen shake + audio), then lose life
    final escaped = enemies.where((e) => e.pathProgress >= _waypoints.length - 1).toList();
    for (final e in escaped) {
      onEnemyReachEnd?.call(e); // State: play lifeLost sound + screen shake
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
      // Fire wave-complete callback to State (shows banner + starts next wave or victory)
      onWaveComplete?.call();
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
  // Phase 3: Stats per level [base, level2, level3]
  static final _towerStats = {
    TDTowerType.basic:  (baseCost: 50,  damage: [10, 15, 22], range: [100.0, 120.0, 140.0], fireRate: [0.5, 0.6, 0.75]),
    TDTowerType.sniper: (baseCost: 100, damage: [50, 75, 110], range: [200.0, 220.0, 250.0], fireRate: [1.5, 1.8, 2.2]),
    TDTowerType.splash: (baseCost: 150, damage: [25, 40, 60], range: [80.0, 95.0, 110.0], fireRate: [0.8, 1.0, 1.3]),
    TDTowerType.slow:   (baseCost: 75,  damage: [5, 8, 12], range: [120.0, 140.0, 160.0], fireRate: [0.3, 0.4, 0.5]),
  };

  int getTowerCost(TDTowerType type) => _towerStats[type]!.baseCost;

  // Phase 4: Get base range for preview
  static double getTowerBaseRange(TDTowerType type) => _towerStats[type]!.range[0];

  // Phase 3: Get upgrade cost for a tower
  int getTowerUpgradeCost(TDTower tower) {
    if (tower.level >= 3) return -1;
    final baseCost = _towerStats[tower.type]!.baseCost;
    return (baseCost * 0.6 * tower.level).round();
  }

  // Phase 3: Get sell value for a tower
  int getTowerSellValue(TDTower tower) {
    // Refund 50% of total invested gold
    final baseCost = _towerStats[tower.type]!.baseCost;
    int totalInvested = baseCost;
    for (int l = 1; l < tower.level; l++) {
      totalInvested += (baseCost * 0.6 * l).round();
    }
    return (totalInvested * 0.5).round();
  }

  // Phase 3: Upgrade tower
  bool upgradeTower(TDTower tower) {
    if (tower.level >= 3) return false;
    final cost = getTowerUpgradeCost(tower);
    if (gold < cost) return false;
    
    gold -= cost;
    tower.level++;
    
    final stats = _towerStats[tower.type]!;
    tower.damage = stats.damage[tower.level - 1];
    tower.range = stats.range[tower.level - 1];
    tower.fireRate = stats.fireRate[tower.level - 1];
    
    notifyListeners();
    return true;
  }

  // Phase 3: Sell tower
  bool sellTower(TDTower tower) {
    final sellValue = getTowerSellValue(tower);
    gold += sellValue;
    towers.remove(tower);
    if (selectedTower?.id == tower.id) {
      selectedTower = null;
    }
    notifyListeners();
    return true;
  }

  TDTower createTower(TDTowerType type, Offset position) {
    final stats = _towerStats[type]!;
    return TDTower(
      id: DateTime.now().millisecondsSinceEpoch,
      type: type,
      position: position,
      damage: stats.damage[0],
      range: stats.range[0],
      fireRate: stats.fireRate[0],
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

  void pauseGame() {
    _isPaused = true;
    _gameLoopTimer?.cancel();
    _enemySpawnTimer?.cancel();
    notifyListeners();
  }

  void resumeGame() {
    _isPaused = false;
    if (isPlaying) {
      _startGameLoop();
    }
    notifyListeners();
  }

  void setGameSpeed(double speed) {
    _gameSpeed = speed;
    notifyListeners();
  }

  double get gameSpeed => _gameSpeed;
  bool get isPaused => _isPaused;

  @override
  void dispose() {
    _waveTimer?.cancel();
    _enemySpawnTimer?.cancel();
    _gameLoopTimer?.cancel();
    super.dispose();
  }
}