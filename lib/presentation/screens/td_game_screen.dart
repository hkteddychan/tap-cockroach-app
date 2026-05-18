import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../game/audio_service.dart';
import '../../game/game_provider.dart';
import '../../data/models/game_models.dart';

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
  final GameProvider gameProvider;
  const TDGameScreen({super.key, required this.level, required this.gameProvider});

  @override
  State<TDGameScreen> createState() => _TDGameScreenState();
}

class _TDGameScreenState extends State<TDGameScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late TDGameProvider _tdProvider; // local TD tower-defense game state
  late GameProvider _parentProvider; // parent's GameProvider — used only for onLevelComplete()
  late AudioService _audioService;
  late AnimationController _rippleController;
  late AnimationController _shakeController;
  late AnimationController _waveAnimController;

  // Wave number for display (animates when wave starts)
  int _displayWave = 1;
  
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

  // Achievement combo banner
  bool _showComboBanner = false;
  String _comboBannerText = '';
  late AnimationController _comboAnimController;

  // Combo timer (3 second timeout)
  DateTime? _lastKillTime;
  static const _comboTimeoutSeconds = 3.0;

  // Kill streak tracking
  int _killStreak = 0;
  bool _perfectWave = true; // true until an enemy reaches the end

  @override
  void initState() {
    super.initState();
    _tdProvider = TDGameProvider(); // create fresh local TD game provider
    _parentProvider = widget.gameProvider; // parent's provider for level completion
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

    _comboAnimController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _showComboBanner = false);
        }
      });

    // Phase 4: Initialize game provider callbacks
    _tdProvider.addListener(_onGameStateChanged);
    _initGame();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _tdProvider.pauseGame();
      setState(() => _isPaused = true);
    } else if (state == AppLifecycleState.resumed) {
      _tdProvider.resumeGame();
      setState(() => _isPaused = false);
    }
  }

  Future<void> _initGame() async {
    await _audioService.init();
    if (_soundEnabled) _audioService.playSfx(SoundType.waveStart);
    _showWaveStartBanner(1);
    _tdProvider.startWave(widget.level);
    _tdProvider.onEnemyKilled = _onEnemyKilled;
    _tdProvider.onEnemyReachEnd = _onEnemyReachEnd;
    _tdProvider.onWaveComplete = _handleWaveComplete;
    _tdProvider.addListener(_onGameStateChanged);
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
    _displayScore = _tdProvider.score;
    _displayGold = _tdProvider.gold;
    _displayCombo = _tdProvider.combo;
    
    // Check combo timer - reset if 3 seconds without kill
    if (_tdProvider.comboCount > 0 && _lastKillTime != null) {
      final elapsed = DateTime.now().difference(_lastKillTime!).inMilliseconds / 1000.0;
      if (elapsed >= _comboTimeoutSeconds) {
        _tdProvider.resetCombo();
      }
    }
  }

  void _showWaveStartBanner(int wave) {
    setState(() {
      _displayWave = wave;
    });
  }

  void _showWaveCompleteBanner(String text) {
    setState(() {
      _showWaveComplete = true;
      _waveCompleteText = text;
    });
    _waveAnimController.forward(from: 0);
  }

  void _addFloatingText(String text, Offset position, Color color) {
    _floatingTexts.add(_FloatingText(
      text: text,
      position: position,
      color: color,
    ));
  }

  void _spawnKillParticles(Offset position, Color color) {
    final random = Random();
    for (int i = 0; i < 8; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = 1.0 + random.nextDouble() * 2.0;
      _killParticles.add(_KillParticle(
        position: position,
        velocity: Offset(cos(angle) * speed, sin(angle) * speed),
        color: color,
        size: 4 + random.nextDouble() * 4,
      ));
    }
  }

  void _triggerKillFlash() {
    setState(() => _showKillFlash = true);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _showKillFlash = false);
    });
  }

  void _onTowerPlaced(TDTower tower) {
    _tdProvider.placeTower(tower);
    if (_soundEnabled) _audioService.playSfx(SoundType.placeTower);
    _triggerRipple(tower.position);
  }

  void _handleGameOver() {
    _tdProvider.isPlaying = false;
    _showWaveCompleteBanner('💀 遊戲結束');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _handleWaveComplete() {
    // This wave is done — mark the LEVEL complete (each level = 1 wave)
    final completedLevel = widget.level;
    final score = _tdProvider.score;

    // Mark level complete and unlock next level
    _parentProvider.gameState.onLevelComplete(
      completedLevel,
      score,
      0, // goldenCount (simplified)
      _perfectWave,
      0, // timeUsed (simplified)
    );
    _parentProvider.saveState();

    // Show victory banner
    _showWaveCompleteBanner('🏆 第 $completedLevel 關完成！');
    if (_soundEnabled) _audioService.playSfx(SoundType.gameWin);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rippleController.dispose();
    _shakeController.dispose();
    _waveAnimController.dispose();
    _floatTextController.dispose();
    _comboAnimController.dispose();
    _tdProvider.removeListener(_onGameStateChanged);
    _tdProvider.dispose();
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

  // Invalid placement feedback
  void _triggerInvalidPlacementFeedback() {
    if (_soundEnabled) _audioService.playSfx(SoundType.hit);
  }

  Color _getEnemyColor(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.normal: return Colors.brown;
      case TDEnemyType.fast: return Colors.orange;
      case TDEnemyType.tank: return Colors.red.shade800;
      case TDEnemyType.boss: return Colors.deepPurple;
      case TDEnemyType.poison: return Colors.green.shade700;
      case TDEnemyType.elite: return Colors.amber;
      case TDEnemyType.swarm: return Colors.lightBlue;
    }
  }

  void _onEnemyKilled(TDEnemy enemy) {
    _tdProvider.addGold(enemy.goldReward);
    _tdProvider.addScore(enemy.points);
    _lastKillTime = DateTime.now(); // Update last kill time for combo timer
    _tdProvider.incrementCombo();

    // Track kill streak
    _killStreak++;
    if (_killStreak > 0 && _killStreak % 5 == 0) {
      // Every 5 consecutive kills = +20 gold bonus
      _tdProvider.addGold(20);
      _addFloatingText('🔥 連續击杀!\n+20', Offset(enemy.position.dx, enemy.position.dy - 30), Colors.orange);
    }

    // Combo milestones
    final combo = _tdProvider.combo;
    if (combo >= 10) {
      _showComboBannerX10();
      _tdProvider.addGold(50);
      if (_soundEnabled) _audioService.playSfx(SoundType.achievement);
    } else if (combo >= 5) {
      _showComboBannerMessage('厲害! x5', Colors.orangeAccent);
      _tdProvider.addGold(10);
      if (_soundEnabled) _audioService.playSfx(SoundType.achievement);
    } else if (combo >= 3) {
      _showComboBannerMessage('良好! x3', Colors.yellowAccent);
    }

    // Floating damage/gold text
    _addFloatingText(
      '+${enemy.goldReward}',
      Offset(enemy.position.dx, enemy.position.dy - 20),
      AppTheme.textGold,
    );

    // Phase 10: Kill particles
    _spawnKillParticles(enemy.position, _getEnemyColor(enemy.type));
    _triggerKillFlash();
  }

  void _onEnemyReachEnd(TDEnemy enemy) {
    if (_soundEnabled) _audioService.playSfx(SoundType.lifeLost);
    _triggerScreenShake();
    _perfectWave = false; // Enemy reached end, not a perfect wave
    _killStreak = 0; // Reset kill streak
  }

  // Combo achievement banner: fires when comboCount >= 10
  void _showComboBannerX10() {
    setState(() {
      _showComboBanner = true;
      _comboBannerText = '🔥 COMBO x10! +50 bonus';
    });
    _comboAnimController.forward(from: 0);
  }

  // Generic combo banner message
  void _showComboBannerMessage(String msg, Color color) {
    setState(() {
      _showComboBanner = true;
      _comboBannerText = msg;
    });
    _comboAnimController.forward(from: 0);
  }

  // Combo timer progress (0.0 to 1.0, depletes over 3 seconds)
  double _getComboTimerProgress() {
    if (_lastKillTime == null || _tdProvider.comboCount == 0) return 0.0;
    final elapsed = DateTime.now().difference(_lastKillTime!).inMilliseconds / 1000.0;
    return (1.0 - (elapsed / _comboTimeoutSeconds)).clamp(0.0, 1.0);
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
          
          // Combo achievement banner
          if (_showComboBanner)
            _buildComboBanner(),
          
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
                  _tdProvider.resumeGame();
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
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  // Restart current level
                  _tdProvider.resetGame();
                  _tdProvider.startWave(widget.level);
                  setState(() => _isPaused = false);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        '重新開始',
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
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        '回主頁',
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
              _hudItem('❤️', '${_tdProvider.lives}', Colors.pinkAccent),
              _hudItem('💰', '$_displayGold', AppTheme.textGold),
              _hudItem('🏰', '第${widget.level}關/10', Colors.lightBlueAccent),
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
    final currentWave = _tdProvider.currentWave;
    final totalWaves = _tdProvider.totalWaves;
    final enemiesOnField = _tdProvider.enemies.length;
    final remaining = _tdProvider.enemiesRemaining;
    final total = _tdProvider.enemiesThisWave;
    final waveProgress = _tdProvider.waveProgress;
    final nextWavePreview = currentWave < totalWaves - 1 ? '第 ${currentWave + 2} 波' : '最終波';
    final statusText = enemiesOnField > 0
        ? '剩餘 $remaining/$total'
        : (remaining > 0 ? '等待中 $remaining/$total' : '✅ 消滅完成！');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '🌊 ${currentWave + 1}/$totalWaves',
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
                  statusText,
                  style: TextStyle(
                    color: enemiesOnField > 0 ? Colors.redAccent : (remaining > 0 ? Colors.amber : Colors.greenAccent),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
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
        _speedButton('3x', 3.0),
      ],
    );
  }

  Widget _speedButton(String label, double speed) {
    final isSelected = _gameSpeed == speed;
    return GestureDetector(
      onTap: () {
        setState(() => _gameSpeed = speed);
        _tdProvider.setGameSpeed(speed);
        if (_soundEnabled) _audioService.playSfx(SoundType.tap);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.white38,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white38,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPauseButton() {
    return GestureDetector(
      onTap: () {
        _tdProvider.pauseGame();
        setState(() => _isPaused = true);
        if (_soundEnabled) _audioService.playSfx(SoundType.tap);
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.pause,
          color: Colors.white70,
          size: 20,
        ),
      ),
    );
  }

  Widget _hudItem(String icon, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGameField() {
    return GestureDetector(
      onTapUp: (details) {
        final position = details.localPosition;
        
        // Check if tapping on existing tower (show range + upgrade panel)
        TDTower? tappedTower;
        for (final tower in _tdProvider.towers) {
          final dx = position.dx - tower.position.dx;
          final dy = position.dy - tower.position.dy;
          if (sqrt(dx * dx + dy * dy) < 25) {
            tappedTower = tower;
            break;
          }
        }
        
        if (tappedTower != null) {
          _showTowerInfo(tappedTower);
          return;
        }
        
        // Check if tower type is selected and valid placement
        if (_tdProvider.selectedTowerType != null) {
          // Check if position is on path
          if (_tdProvider.isPositionOnPath(position)) {
            _triggerInvalidPlacementFeedback();
            return;
          }
          
          // Check if position is occupied by another tower
          for (final tower in _tdProvider.towers) {
            final dx = position.dx - tower.position.dx;
            final dy = position.dy - tower.position.dy;
            if (sqrt(dx * dx + dy * dy) < 50) {
              _triggerInvalidPlacementFeedback();
              return;
            }
          }
          
          // Place the tower
          final tower = TDTower(
            type: _tdProvider.selectedTowerType!,
            position: position,
          );
          _onTowerPlaced(tower);
        }
        
        // Update tower preview position for range circle
        setState(() => _towerPreviewPosition = position);
      },
      onPanUpdate: (details) {
        if (_tdProvider.selectedTowerType != null) {
          setState(() => _towerPreviewPosition = details.localPosition);
        }
      },
      child: Stack(
        children: [
          // Enemy path and towers rendered via CustomPaint
          CustomPaint(
            painter: TDGamePainter(
              provider: _tdProvider,
              rippleOrigin: _rippleOrigin,
              rippleProgress: _rippleController.value,
              shakeOffset: _shakeController.isAnimating
                  ? Offset(sin(_shakeController.value * 20) * 5, 0)
                  : Offset.zero,
              towerPreviewPosition: _tdProvider.selectedTowerType != null
                  ? _towerPreviewPosition
                  : null,
              towerPreviewType: _tdProvider.selectedTowerType,
              floatTexts: _floatingTexts,
              killParticles: _killParticles,
              isPaused: _isPaused,
            ),
            size: Size.infinite,
          ),
        ],
      ),
    );
  }

  void _showTowerInfo(TDTower tower) {
    _tdProvider.selectedTower = tower;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTowerInfoPanel(tower),
    );
  }

  Widget _buildTowerInfoPanel(TDTower tower) {
    final upgradeCost = _tdProvider.getTowerUpgradeCost(tower);
    final sellValue = (_tdProvider.getTowerCost(tower.type) * 0.6).round();
    final canUpgrade = _tdProvider.gold >= upgradeCost && tower.level < 3;
    final towerName = _getTowerChineseName(tower.type);
    final levelStars = '⭐' * tower.level + '☆' * (3 - tower.level);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a2e),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Color(0xFF00D4FF), width: 2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.upgrade, color: Color(0xFF00D4FF), size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                '塔升級',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Tower name + level
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      towerName,
                      style: const TextStyle(
                        color: Color(0xFF00D4FF),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      levelStars,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 16,
                        shadows: [
                          Shadow(color: Colors.amber, blurRadius: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'DPS: ${_getTowerDPS(tower).toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Text(
                    '傷害: ${tower.damage}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              // Upgrade button
              Expanded(
                child: GestureDetector(
                  onTap: canUpgrade
                      ? () {
                          Navigator.pop(context);
                          _tdProvider.upgradeTower(tower);
                          if (_soundEnabled) _audioService.playSfx(SoundType.achievement);
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: canUpgrade ? AppTheme.primary : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: canUpgrade ? AppTheme.primary : Colors.grey,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.upgrade,
                          color: canUpgrade ? Colors.white : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '升級 +HK\$$upgradeCost',
                          style: TextStyle(
                            color: canUpgrade ? Colors.white : Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sell button
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _addFloatingText(
                    '已出售 +HK\$$sellValue',
                    tower.position,
                    AppTheme.textGold,
                  );
                  _tdProvider.sellTower(tower);
                  if (_soundEnabled) _audioService.playSfx(SoundType.tap);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade700),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sell, color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '出售 +\$$sellValue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _getTowerChineseName(TDTowerType type) {
    switch (type) {
      case TDTowerType.basic: return '標準步槍塔';
      case TDTowerType.sniper: return '狙擊穿透炮';
      case TDTowerType.splash: return '爆炸衝擊炮';
      case TDTowerType.slow: return '冰凍束縛炮';
      case TDTowerType.laser: return '等離子追蹤炮';
      case TDTowerType.global: return '全域脈衝塔';
      case TDTowerType.poison: return '毒疫擴散炮';
    }
  }

  int _getTowerDPS(TDTower tower) {
    return (tower.damage * tower.fireRate).round();
  }

  Widget _buildTowerPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tower selection row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: TDTowerType.values.map((type) {
                final isSelected = _tdProvider.selectedTowerType == type;
                final cost = _tdProvider.getTowerCost(type);
                final canAfford = _tdProvider.gold >= cost;
                
                return GestureDetector(
                  onTap: canAfford
                      ? () {
                          setState(() {
                            _tdProvider.selectedTowerType = isSelected ? null : type;
                          });
                          if (_soundEnabled) _audioService.playSfx(SoundType.tap);
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppTheme.primary.withOpacity(0.3)
                          : (canAfford ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? AppTheme.primary
                            : (canAfford ? Colors.white24 : Colors.grey.shade800),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getTowerEmoji(type),
                          style: TextStyle(
                            fontSize: 24,
                            color: canAfford ? null : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'HK\$$cost',
                          style: TextStyle(
                            color: canAfford ? AppTheme.textGold : Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Selected tower indicator
          if (_tdProvider.selectedTowerType != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getTowerEmoji(_tdProvider.selectedTowerType!),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getTowerChineseName(_tdProvider.selectedTowerType!),
                    style: const TextStyle(
                      color: Color(0xFF00D4FF),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '— 點擊地圖放置',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getTowerEmoji(TDTowerType type) {
    switch (type) {
      case TDTowerType.basic: return '🔫';
      case TDTowerType.sniper: return '🎯';
      case TDTowerType.splash: return '💥';
      case TDTowerType.slow: return '❄️';
      case TDTowerType.laser: return '⚡';
      case TDTowerType.global: return '🌐';
      case TDTowerType.poison: return '☠️';
    }
  }

  Widget _buildWaveCompleteBanner() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.35,
      left: 20,
      right: 20,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.5, end: 1.0).animate(
          CurvedAnimation(parent: _waveAnimController, curve: Curves.elasticOut),
        ),
        child: FadeTransition(
          opacity: _waveAnimController,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1a3a2a),
                  const Color(0xFF0d2018),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.success.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.success.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _waveCompleteText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(color: Color(0xFF00FF88), blurRadius: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComboBanner() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.25,
      left: 20,
      right: 20,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(parent: _comboAnimController, curve: Curves.elasticOut),
        ),
        child: FadeTransition(
          opacity: ReverseAnimation(_comboAnimController),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2a1a0a), Color(0xFF1a0d05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.6), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.4),
                  blurRadius: 25,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Text(
              _comboBannerText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(color: Colors.amber, blurRadius: 15),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRippleOverlay() {
    if (_rippleOrigin == null) return const SizedBox.shrink();
    
    return AnimatedBuilder(
      animation: _rippleController,
      builder: (context, child) {
        final progress = _rippleController.value;
        final maxRadius = 80.0;
        final currentRadius = maxRadius * progress;
        
        return Positioned(
          left: _rippleOrigin!.dx - currentRadius,
          top: _rippleOrigin!.dy - currentRadius,
          child: Container(
            width: currentRadius * 2,
            height: currentRadius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primary.withOpacity(1.0 - progress),
                width: 3,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShakeOverlay() {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final shake = sin(_shakeController.value * pi * 4) * 5;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );
      },
      child: const SizedBox.expand(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  TD GAME PAINTER - Renders path, towers, enemies, projectiles
// ═══════════════════════════════════════════════════════════

class TDGamePainter extends CustomPainter {
  final TDGameProvider provider;
  final Offset? rippleOrigin;
  final double rippleProgress;
  final Offset shakeOffset;
  final Offset? towerPreviewPosition;
  final TDTowerType? towerPreviewType;
  final List<_FloatingText> floatTexts;
  final List<_KillParticle> killParticles;
  final bool isPaused;

  TDGamePainter({
    required this.provider,
    this.rippleOrigin,
    this.rippleProgress = 0,
    this.shakeOffset = Offset.zero,
    this.towerPreviewPosition,
    this.towerPreviewType,
    this.floatTexts = const [],
    this.killParticles = const [],
    this.isPaused = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isPaused) {
      // Draw "PAUSED" text when paused
      final pausePaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Offset.zero & size, pausePaint);
    }

    canvas.save();
    canvas.translate(shakeOffset.dx, shakeOffset.dy);

    // Draw enemy path
    _drawPath(canvas);

    // Draw tower range circles (for selected/hovered towers)
    _drawTowerRanges(canvas);

    // Draw tower preview
    _drawTowerPreview(canvas);

    // Draw towers
    _drawTowers(canvas);

    // Draw enemies
    _drawEnemies(canvas);

    // Draw projectiles
    _drawProjectiles(canvas);

    // Draw kill particles
    _drawKillParticles(canvas);

    // Draw floating texts
    _drawFloatingTexts(canvas);

    canvas.restore();
  }

  void _drawPath(Canvas canvas) {
    final path = provider.enemyPath;
    if (path.isEmpty) return;

    // Draw path line
    final pathPaint = Paint()
      ..color = Colors.brown.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pathLine = Path();
    pathLine.moveTo(path.first.dx, path.first.dy);
    for (int i = 1; i < path.length; i++) {
      pathLine.lineTo(path[i].dx, path[i].dy);
    }
    canvas.drawPath(pathLine, pathPaint);

    // Draw path border
    final borderPaint = Paint()
      ..color = Colors.brown.shade300.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 34
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(pathLine, borderPaint);
  }

  void _drawTowerRanges(Canvas canvas) {
    // Draw range for all towers (subtle)
    for (final tower in provider.towers) {
      final rangePaint = Paint()
        ..color = _getTowerColor(tower.type).withOpacity(0.08)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tower.position, tower.range, rangePaint);

      final rangeBorderPaint = Paint()
        ..color = _getTowerColor(tower.type).withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(tower.position, tower.range, rangeBorderPaint);
    }
  }

  void _drawTowerPreview(Canvas canvas) {
    if (towerPreviewPosition == null || towerPreviewType == null) return;

    final isValid = !provider.isPositionOnPath(towerPreviewPosition!) &&
        !_isPositionOccupied(towerPreviewPosition!);

    // Draw range circle
    final range = TDGameProvider.getTowerBaseRange(towerPreviewType!);
    final rangePaint = Paint()
      ..color = (isValid ? Colors.green : Colors.red).withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(towerPreviewPosition!, range, rangePaint);

    final rangeBorderPaint = Paint()
      ..color = (isValid ? Colors.green : Colors.red).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(towerPreviewPosition!, range, rangeBorderPaint);

    // Draw tower icon
    final previewPaint = Paint()
      ..color = (isValid ? Colors.green : Colors.red).withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(towerPreviewPosition!, 15, previewPaint);

    // Tower type icon
    final textPainter = TextPainter(
      text: TextSpan(
        text: _getTowerEmoji(towerPreviewType!),
        style: const TextStyle(fontSize: 18),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        towerPreviewPosition!.dx - textPainter.width / 2,
        towerPreviewPosition!.dy - textPainter.height / 2,
      ),
    );
  }

  bool _isPositionOccupied(Offset position) {
    for (final tower in provider.towers) {
      final dx = position.dx - tower.position.dx;
      final dy = position.dy - tower.position.dy;
      if (sqrt(dx * dx + dy * dy) < 50) {
        return true;
      }
    }
    return false;
  }

  void _drawTowers(Canvas canvas) {
    for (final tower in provider.towers) {
      // Draw base
      final basePaint = Paint()
        ..color = _getTowerColor(tower.type).withOpacity(0.8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tower.position, 18, basePaint);

      // Draw glow for upgraded towers
      if (tower.level > 1) {
        final glowPaint = Paint()
          ..color = _getTowerColor(tower.type).withOpacity(0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(tower.position, 22 + tower.level * 3, glowPaint);
      }

      // Draw range indicator (smaller circle)
      final rangePaint = Paint()
        ..color = _getTowerColor(tower.type).withOpacity(0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tower.position, 8, rangePaint);

      // Draw tower icon
      final textPainter = TextPainter(
        text: TextSpan(
          text: _getTowerEmoji(tower.type),
          style: const TextStyle(fontSize: 20),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          tower.position.dx - textPainter.width / 2,
          tower.position.dy - textPainter.height / 2,
        ),
      );

      // Draw level indicator
      if (tower.level > 1) {
        final levelPaint = Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(tower.position.dx + 12, tower.position.dy - 12),
          6,
          levelPaint,
        );
        final levelText = TextPainter(
          text: TextSpan(
            text: '${tower.level}',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        levelText.layout();
        levelText.paint(
          canvas,
          Offset(
            tower.position.dx + 12 - levelText.width / 2,
            tower.position.dy - 12 - levelText.height / 2,
          ),
        );
      }
    }
  }

  void _drawEnemies(Canvas canvas) {
    for (final enemy in provider.enemies) {
      final color = _getEnemyColor(enemy.type);

      // Draw enemy body
      final bodyPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(enemy.position, _getEnemySize(enemy.type), bodyPaint);

      // Draw health bar
      final hpRatio = enemy.currentHealth / enemy.maxHealth;
      final barWidth = _getEnemySize(enemy.type) * 2.5;
      final barHeight = 5.0;
      final barX = enemy.position.dx - barWidth / 2;
      final barY = enemy.position.dy - _getEnemySize(enemy.type) - 10;

      // HP bar background
      final bgPaint = Paint()
        ..color = Colors.black.withOpacity(0.7)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barWidth, barHeight),
          const Radius.circular(3),
        ),
        bgPaint,
      );

      // HP bar fill with gradient
      Color hpColor;
      if (hpRatio > 0.5) {
        hpColor = Colors.green;
      } else if (hpRatio > 0.25) {
        hpColor = Colors.amber;
      } else {
        hpColor = Colors.red;
      }
      final hpPaint = Paint()
        ..color = hpColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barWidth * hpRatio, barHeight),
          const Radius.circular(3),
        ),
        hpPaint,
      );

      // Draw enemy icon
      final textPainter = TextPainter(
        text: TextSpan(
          text: _getEnemyEmoji(enemy.type),
          style: const TextStyle(fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          enemy.position.dx - textPainter.width / 2,
          enemy.position.dy - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawProjectiles(Canvas canvas) {
    for (final proj in provider.projectiles) {
      final color = _getProjectileColor(proj.type);
      final size = _getProjectileSize(proj.type);

      // Draw projectile trail
      final trailPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(
          proj.position.dx - proj.direction.dx * size * 2,
          proj.position.dy - proj.direction.dy * size * 2,
        ),
        size * 0.7,
        trailPaint,
      );

      // Draw projectile
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(proj.position, size, paint);

      // Glow effect for laser
      if (proj.type == TDProjectileType.laser) {
        final glowPaint = Paint()
          ..color = color.withOpacity(0.4)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(proj.position, size * 2, glowPaint);
      }
    }
  }

  void _drawKillParticles(Canvas canvas) {
    for (final p in killParticles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p.position, p.size, paint);
    }
  }

  void _drawFloatingTexts(Canvas canvas) {
    for (final ft in floatTexts) {
      if (ft.opacity <= 0) continue;
      final textPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withOpacity(ft.opacity),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: ft.color.withOpacity(ft.opacity * 0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          ft.position.dx - textPainter.width / 2,
          ft.position.dy - textPainter.height / 2,
        ),
      );
    }
  }

  Color _getTowerColor(TDTowerType type) {
    switch (type) {
      case TDTowerType.basic: return Colors.blueGrey;
      case TDTowerType.sniper: return Colors.green;
      case TDTowerType.splash: return Colors.orange;
      case TDTowerType.slow: return Colors.cyan;
      case TDTowerType.laser: return Colors.purple;
      case TDTowerType.global: return Colors.indigo;
      case TDTowerType.poison: return Colors.green.shade700;
    }
  }

  Color _getEnemyColor(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.normal: return Colors.brown;
      case TDEnemyType.fast: return Colors.orange;
      case TDEnemyType.tank: return Colors.red.shade800;
      case TDEnemyType.boss: return Colors.deepPurple;
      case TDEnemyType.poison: return Colors.green.shade700;
      case TDEnemyType.elite: return Colors.amber;
      case TDEnemyType.swarm: return Colors.lightBlue;
    }
  }

  Color _getProjectileColor(TDProjectileType type) {
    switch (type) {
      case TDProjectileType.bullet: return Colors.yellow;
      case TDProjectileType.sniper: return Colors.greenAccent;
      case TDProjectileType.explosive: return Colors.orange;
      case TDProjectileType.ice: return Colors.cyan;
      case TDProjectileType.laser: return Colors.purpleAccent;
      case TDProjectileType.poison: return Colors.green;
    }
  }

  double _getProjectileSize(TDProjectileType type) {
    switch (type) {
      case TDProjectileType.bullet: return 4;
      case TDProjectileType.sniper: return 3;
      case TDProjectileType.explosive: return 6;
      case TDProjectileType.ice: return 5;
      case TDProjectileType.laser: return 5;
      case TDProjectileType.poison: return 4;
    }
  }

  double _getEnemySize(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.normal: return 12;
      case TDEnemyType.fast: return 9;
      case TDEnemyType.tank: return 16;
      case TDEnemyType.boss: return 22;
      case TDEnemyType.poison: return 11;
      case TDEnemyType.elite: return 14;
      case TDEnemyType.swarm: return 8;
    }
  }

  String _getTowerEmoji(TDTowerType type) {
    switch (type) {
      case TDTowerType.basic: return '🔫';
      case TDTowerType.sniper: return '🎯';
      case TDTowerType.splash: return '💥';
      case TDTowerType.slow: return '❄️';
      case TDTowerType.laser: return '⚡';
      case TDTowerType.global: return '🌐';
      case TDTowerType.poison: return '☠️';
    }
  }

  String _getEnemyEmoji(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.normal: return '🐀';
      case TDEnemyType.fast: return '🦗';
      case TDEnemyType.tank: return '🪲';
      case TDEnemyType.boss: return '👾';
      case TDEnemyType.poison: return '🕷️';
      case TDEnemyType.elite: return '⭐';
      case TDEnemyType.swarm: return '🐜';
    }
  }

  @override
  bool shouldRepaint(covariant TDGamePainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════
//  TOWER DEFENSE GAME PROVIDER - Core game logic
// ═══════════════════════════════════════════════════════════

enum TDTowerType { basic, sniper, splash, slow, laser, global, poison }
enum TDEnemyType { normal, fast, tank, boss, poison, elite, swarm }
enum TDProjectileType { bullet, sniper, explosive, ice, laser, poison }

class TDTower {
  final TDTowerType type;
  Offset position;
  int level;
  double range;
  int damage;
  double fireRate;
  DateTime? lastFireTime;
  double targetAngle;
  double muzzleFlashTime;

  TDTower({
    required this.type,
    required this.position,
    this.level = 1,
    double? range,
    int? damage,
    double? fireRate,
  })  : range = range ?? TDGameProvider.getTowerBaseRange(type),
        damage = damage ?? (TDGameProvider.getTowerStats(type)['damage']![0] as int),
        fireRate = fireRate ?? (TDGameProvider.getTowerStats(type)['fireRate']![0] as double),
        targetAngle = 0,
        muzzleFlashTime = 0;

  void upgrade() {
    if (level >= 3) return;
    level++;
    final stats = TDGameProvider.getTowerStats(type);
    range = (stats['range']![level - 1] as double);
    damage = (stats['damage']![level - 1] as int);
    fireRate = (stats['fireRate']![level - 1] as double);
  }
}

class TDEnemy {
  final int id;
  final TDEnemyType type;
  Offset position;
  double speed;
  int maxHealth;
  int currentHealth;
  int goldReward;
  int points;
  int pathProgress;
  bool isSlowed;
  DateTime? slowEndTime;
  double movementAngle;
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
    this.pathProgress = 0,
    this.isSlowed = false,
    this.slowEndTime,
    this.movementAngle = 0,
    this.trailPositions = const [],
  });
}

class TDProjectile {
  Offset position;
  Offset direction;
  int damage;
  TDProjectileType type;
  double speed;
  int bounceCount;

  TDProjectile({
    required this.position,
    required this.direction,
    required this.damage,
    required this.type,
    required this.speed,
    this.bounceCount = 0,
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
  int totalWaves = 10; // 10 waves per level
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
  int _level = 1; // Store level (1-10) for difficulty scaling
  
  // Path waypoints (will be populated in init)
  final List<Offset> _waypoints = [];

  double get waveProgress {
    if (_enemiesPerWave == 0) return 0.0;
    final killed = _enemiesSpawnedThisWave - enemies.length;
    return (killed / _enemiesPerWave).clamp(0.0, 1.0);
  }

  // Remaining = not-yet-spawned + still-alive enemies
  int get enemiesRemaining => (_enemiesPerWave - _enemiesSpawnedThisWave) + enemies.length;

  // Total enemies for this wave
  int get enemiesThisWave => _enemiesPerWave;

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

  void startWave([int? level]) {
    isPlaying = true;
    // Reset wave counter; level param is used for difficulty scaling
    currentWave = 0;
    _level = level ?? 1;
    _enemiesSpawnedThisWave = 0;
    _enemiesPerWave = 10 + (_level * 2); // Scale by level (1-10)

    // Restart game loop (was cancelled by _checkWaveComplete on previous wave)
    _startGameLoop();

    // Spawn enemies periodically — interval scales with level (difficulty), not wave number
    final spawnInterval = 2000 - (_level * 100).clamp(0, 1500);
    _enemySpawnTimer?.cancel();
    _enemySpawnTimer = Timer.periodic(Duration(milliseconds: spawnInterval), (_) {
      if (_enemiesSpawnedThisWave < _enemiesPerWave && isPlaying) {
        _spawnEnemy();
        _enemiesSpawnedThisWave++;
      } else {
        _enemySpawnTimer?.cancel();
      }
    });
  }
  void _spawnEnemy() {
    TDEnemyType type;
    final roll = Random().nextDouble();
    
    if (currentWave >= 8 && roll < 0.1) {
      type = TDEnemyType.boss;
    } else if (currentWave >= 5 && roll < 0.3) {
      type = TDEnemyType.tank;
    } else if (currentWave >= 6 && roll < 0.15) {
      type = TDEnemyType.elite;
    } else if (currentWave >= 8 && roll < 0.25) {
      type = TDEnemyType.swarm;
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

  void _spawnToxicEnemy(TDEnemy original) {
    final toxic = TDEnemy(
      id: _enemyIdCounter++,
      type: TDEnemyType.poison,
      position: original.position,
      speed: original.speed * 0.7,
      maxHealth: (original.maxHealth * 0.5).round(),
      currentHealth: (original.maxHealth * 0.5).round(),
      goldReward: (original.goldReward * 0.5).round(),
      points: (original.points * 0.5).round(),
    );
    enemies.add(toxic);
  }

  double _getEnemySpeed(TDEnemyType type) {
    final baseSpeed = 0.5 + (currentWave * 0.05);
    switch (type) {
      case TDEnemyType.fast: return baseSpeed * 2.0;
      case TDEnemyType.tank: return baseSpeed * 0.5;
      case TDEnemyType.boss: return baseSpeed * 0.7;
      case TDEnemyType.poison: return baseSpeed * 1.2;
      case TDEnemyType.elite: return baseSpeed * 1.8;
      case TDEnemyType.swarm: return baseSpeed * 2.5;
      default: return baseSpeed;
    }
  }

  int _getEnemyHealth(TDEnemyType type) {
    final baseHealth = 50 + (currentWave * 20);
    switch (type) {
      case TDEnemyType.fast: return (baseHealth * 0.5).round();
      case TDEnemyType.tank: return (baseHealth * 3).round();
      case TDEnemyType.boss: return (baseHealth * 5).round();
      case TDEnemyType.poison: return (baseHealth * 0.7).round();
      case TDEnemyType.elite: return (baseHealth * 2).round();
      case TDEnemyType.swarm: return (baseHealth * 0.3).round();
      default: return baseHealth;
    }
  }

  int _getEnemyGoldReward(TDEnemyType type) {
    final waveMultiplier = 1.0 + (currentWave - 1) * 0.15;
    switch (type) {
      case TDEnemyType.fast: return (10 * waveMultiplier).round();
      case TDEnemyType.tank: return (20 * waveMultiplier).round();
      case TDEnemyType.boss: return (80 * waveMultiplier).round();
      case TDEnemyType.poison: return (15 * waveMultiplier).round();
      case TDEnemyType.elite: return (25 * waveMultiplier).round();
      case TDEnemyType.swarm: return (5 * waveMultiplier).round();
      case TDEnemyType.normal: return (10 * waveMultiplier).round();
    }
  }

  int _getEnemyPoints(TDEnemyType type) {
    final waveMultiplier = 1.0 + (currentWave - 1) * 0.15;
    switch (type) {
      case TDEnemyType.fast: return (15 * waveMultiplier).round();
      case TDEnemyType.tank: return (30 * waveMultiplier).round();
      case TDEnemyType.boss: return (150 * waveMultiplier).round();
      case TDEnemyType.poison: return (20 * waveMultiplier).round();
      case TDEnemyType.elite: return (40 * waveMultiplier).round();
      case TDEnemyType.swarm: return (5 * waveMultiplier).round();
      case TDEnemyType.normal: return (10 * waveMultiplier).round();
    }
  }

  void _startGameLoop() {
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _updateGame();
    });
  }

  void _updateGame() {
    if (!isPlaying || _isPaused) return;
    
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
        enemy.movementAngle = atan2(dy, dx);
        
        enemy.position = Offset(
          enemy.position.dx + (dx / dist) * speed * _gameSpeed * 20,
          enemy.position.dy + (dy / dist) * speed * _gameSpeed * 20,
        );
        
        // Update trail positions for fast enemies
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
      if (tower.muzzleFlashTime > 0) {
        tower.muzzleFlashTime -= 0.05;
        if (tower.muzzleFlashTime < 0) tower.muzzleFlashTime = 0;
      }
      
      final now = DateTime.now();
      final cooldownMs = (1000 / tower.fireRate).round();
      if (tower.lastFireTime != null &&
          now.difference(tower.lastFireTime!).inMilliseconds < cooldownMs) {
        continue;
      }

      TDEnemy? target;
      double closestDist = double.infinity;

      // Global tower: hits all enemies (no range check)
      if (tower.type == TDTowerType.global && enemies.isNotEmpty) {
        for (final enemy in enemies) {
          if (enemy.pathProgress.toDouble() >= closestDist) {
            closestDist = enemy.pathProgress.toDouble();
            target = enemy;
          }
        }
      } else {
        for (final enemy in enemies) {
          final dx = enemy.position.dx - tower.position.dx;
          final dy = enemy.position.dy - tower.position.dy;
          final dist = sqrt(dx * dx + dy * dy);

          if (dist <= tower.range && dist < closestDist) {
            closestDist = dist;
            target = enemy;
          }
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
    TDProjectileType.laser:     15.0,
    TDProjectileType.poison:    6.0,
  };

  TDProjectileType _getProjectileType(TDTowerType type) {
    switch (type) {
      case TDTowerType.basic: return TDProjectileType.bullet;
      case TDTowerType.sniper: return TDProjectileType.sniper;
      case TDTowerType.splash: return TDProjectileType.explosive;
      case TDTowerType.slow: return TDProjectileType.ice;
      case TDTowerType.laser: return TDProjectileType.laser;
      case TDTowerType.global: return TDProjectileType.bullet;
      case TDTowerType.poison: return TDProjectileType.poison;
    }
  }

  void _fireTower(TDTower tower, TDEnemy target) {
    final dx = target.position.dx - tower.position.dx;
    final dy = target.position.dy - tower.position.dy;
    final dist = sqrt(dx * dx + dy * dy);

    tower.targetAngle = atan2(dy, dx);
    tower.muzzleFlashTime = 0.15;

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
          
          if (projectile.type == TDProjectileType.ice) {
            enemy.isSlowed = true;
            enemy.slowEndTime = DateTime.now().add(const Duration(seconds: 2));
          }
          
          if (projectile.type == TDProjectileType.poison && enemy.currentHealth - projectile.damage <= 0) {
            _spawnToxicEnemy(enemy);
          }
          
          if (projectile.type == TDProjectileType.explosive) {
            for (final other in enemies) {
              if (other == enemy) continue;
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
          
          // Laser bouncing
          if (projectile.type == TDProjectileType.laser && projectile.bounceCount < 2) {
            TDEnemy? nextTarget;
            double nextDist = double.infinity;
            for (final other in enemies) {
              if (other == enemy || enemiesToRemove.contains(other)) continue;
              final odx = other.position.dx - projectile.position.dx;
              final ody = other.position.dy - projectile.position.dy;
              final d = sqrt(odx * odx + ody * ody);
              if (d < nextDist && d < 120) {
                nextDist = d;
                nextTarget = other;
              }
            }
            if (nextTarget != null) {
              final dx = nextTarget.position.dx - projectile.position.dx;
              final dy = nextTarget.position.dy - projectile.position.dy;
              final d = sqrt(dx * dx + dy * dy);
              projectile.direction = Offset(dx / d, dy / d);
              projectile.bounceCount++;
              continue;
            }
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
      onEnemyKilled?.call(e);
      enemies.remove(e);
    }
  }

  void _removeDeadEnemies() {
    final escaped = enemies.where((e) => e.pathProgress >= _waypoints.length - 1).toList();
    for (final e in escaped) {
      onEnemyReachEnd?.call(e);
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
      // Auto-progress through waves 1-10
      if (currentWave < totalWaves - 1) {
        currentWave++;
        _enemiesSpawnedThisWave = 0;
        _enemiesPerWave = 10 + (_level * 2);
        _startGameLoop();
        // Re-spawn enemies for next wave
        final spawnInterval = 2000 - (_level * 100).clamp(0, 1500);
        _enemySpawnTimer?.cancel();
        _enemySpawnTimer = Timer.periodic(Duration(milliseconds: spawnInterval), (_) {
          if (_enemiesSpawnedThisWave < _enemiesPerWave && isPlaying) {
            _spawnEnemy();
            _enemiesSpawnedThisWave++;
          } else {
            _enemySpawnTimer?.cancel();
          }
        });
      } else {
        // Wave 10 done — trigger level complete
        onWaveComplete?.call();
      }
    }
  }

  void placeTower(TDTower tower) {
    final cost = getTowerCost(tower.type);
    if (gold >= cost && !isPositionOnPath(tower.position)) {
      gold -= cost;
      towers.add(tower);
      notifyListeners();
    }
  }

  // ─── Tower factory (single source of truth) ───
  static final _towerStats = {
    TDTowerType.basic:  (baseCost: 50,  damage: [10, 15, 22], range: [100.0, 120.0, 140.0], fireRate: [0.5, 0.6, 0.75]),
    TDTowerType.sniper: (baseCost: 80,  damage: [50, 75, 110], range: [200.0, 220.0, 250.0], fireRate: [1.5, 1.8, 2.2]),
    TDTowerType.splash: (baseCost: 120, damage: [25, 40, 60], range: [80.0, 95.0, 110.0], fireRate: [0.8, 1.0, 1.3]),
    TDTowerType.slow:   (baseCost: 60,  damage: [5, 8, 12], range: [120.0, 140.0, 160.0], fireRate: [0.5, 0.6, 0.75]),
    TDTowerType.laser:  (baseCost: 100, damage: [15, 22, 32], range: [150.0, 170.0, 200.0], fireRate: [2.0, 2.5, 3.0]),
    TDTowerType.global: (baseCost: 150, damage: [8, 12, 18], range: [0.0, 0.0, 0.0], fireRate: [1.0, 1.2, 1.5]),
    TDTowerType.poison: (baseCost: 90,  damage: [3, 5, 8], range: [100.0, 120.0, 140.0], fireRate: [0.5, 0.6, 0.75]),
  };

  int getTowerCost(TDTowerType type) => _towerStats[type]!.baseCost;

  static double getTowerBaseRange(TDTowerType type) => _towerStats[type]!.range[0];

  int getTowerUpgradeCost(TDTower tower) {
    if (tower.level >= 3) return 999999;
    final baseCost = _towerStats[tower.type]!.baseCost;
    return (baseCost * 0.8 * tower.level).round();
  }

  int getTowerSellValue(TDTower tower) {
    return (getTowerCost(tower.type) * 0.6).round();
  }

  void upgradeTower(TDTower tower) {
    final cost = getTowerUpgradeCost(tower);
    if (gold >= cost && tower.level < 3) {
      gold -= cost;
      tower.upgrade();
      notifyListeners();
    }
  }

  void sellTower(TDTower tower) {
    final value = getTowerSellValue(tower);
    gold += value;
    towers.remove(tower);
    notifyListeners();
  }

  bool isPositionOnPath(Offset position) {
    for (int i = 0; i < _waypoints.length - 1; i++) {
      final p1 = _waypoints[i];
      final p2 = _waypoints[i + 1];
      
      final minX = [p1.dx, p2.dx].reduce((a, b) => a < b ? a : b) - 20;
      final maxX = [p1.dx, p2.dx].reduce((a, b) => a > b ? a : b) + 20;
      final minY = [p1.dy, p2.dy].reduce((a, b) => a < b ? a : b) - 20;
      final maxY = [p1.dy, p2.dy].reduce((a, b) => a > b ? a : b) + 20;
      
      if (position.dx >= minX && position.dx <= maxX &&
          position.dy >= minY && position.dy <= maxY) {
        return true;
      }
    }
    return false;
  }

  void addGold(int amount) {
    gold += amount;
    notifyListeners();
  }

  void addScore(int amount) {
    score += amount;
    notifyListeners();
  }

  void incrementCombo() {
    comboCount++;
    combo = 1.0 + (comboCount * 0.1);
    notifyListeners();
  }

  void resetCombo() {
    combo = 1.0;
    comboCount = 0;
    notifyListeners();
  }

  void resetComboCount() {
    comboCount = 0;
    notifyListeners();
  }

  void loseLife() {
    lives--;
    if (lives <= 0) {
      isPlaying = false;
      _gameLoopTimer?.cancel();
      _enemySpawnTimer?.cancel();
    }
    notifyListeners();
  }

  void pauseGame() {
    _isPaused = true;
    notifyListeners();
  }

  void resumeGame() {
    _isPaused = false;
    notifyListeners();
  }

  void setGameSpeed(double speed) {
    _gameSpeed = speed;
  }

  void resetGame() {
    lives = 10;
    gold = 100;
    score = 0;
    combo = 1.0;
    comboCount = 0;
    currentWave = 0;
    isPlaying = true;
    _isPaused = false;
    _gameSpeed = 1.0;
    towers.clear();
    enemies.clear();
    projectiles.clear();
    _enemyIdCounter = 0;
    _enemiesSpawnedThisWave = 0;
    _enemiesPerWave = 10;
    _waveTimer?.cancel();
    _enemySpawnTimer?.cancel();
    _gameLoopTimer?.cancel();
    notifyListeners();
  }

  static Map<String, List<num>> getTowerStats(TDTowerType type) {
    final stats = _towerStats[type]!;
    return {
      'damage': stats.damage,
      'range': stats.range,
      'fireRate': stats.fireRate,
    };
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    _enemySpawnTimer?.cancel();
    _gameLoopTimer?.cancel();
    super.dispose();
  }
}
