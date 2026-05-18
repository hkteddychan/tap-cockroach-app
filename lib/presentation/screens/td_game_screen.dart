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

// Phase 5: Floating text data class (Redesigned with animations)
class _FloatingText {
  String text;
  Offset position;
  Color color;
  double opacity;
  double velocityY;
  double velocityX;
  double scale;
  String type; // 'gold', 'damage', 'combo', 'interest', 'streak'

  _FloatingText({
    required this.text,
    required this.position,
    required this.color,
    this.opacity = 1.0,
    this.velocityY = -2.0,
    this.velocityX = 0.0,
    this.scale = 1.0,
    this.type = 'gold',
  });

  void update(double dt) {
    position = Offset(position.dx + velocityX, position.dy + velocityY);
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

  // Wave number for display (animates when wave starts)
  int _displayWave = 1;
  
  Offset? _rippleOrigin;
  bool _showWaveComplete = false;
  bool _showWaveStart = false;
  String _waveCompleteText = '';
  String _waveStartText = '';
  int _waveStartWaveNum = 1;
  int _displayScore = 0;
  int _displayGold = 0;
  double _displayCombo = 1.0;
  bool _isPaused = false;
  bool _isGameOver = false;
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

  // Invalid placement red HUD flash
  bool _showRedFlash = false;

  // Achievement combo banner
  bool _showComboBanner = false;
  String _comboBannerText = '';
  late AnimationController _comboAnimController;

  // Combo timer: reset combo after 3 seconds without kill
  DateTime? _lastKillTime;
  static const _comboTimeoutSeconds = 3.0;
  
  // Kill streak tracking for bonus gold
  int _killStreak = 0;
  bool _perfectWave = true;

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

    _comboAnimController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _showComboBanner = false);
        }
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
    _showWaveStartBanner(1);
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
      // Animate gold: fast catch-up on gain (catch up 30% per tick, min +5)
      final delta = _gameProvider.gold - _displayGold;
      _displayGold = (_displayGold + max(5, (delta * 0.3).ceil())).clamp(0, _gameProvider.gold).toInt();
    } else if (_displayGold > _gameProvider.gold) {
      // Instant sync when gold decreases (tower placed / upgrade / sell)
      _displayGold = _gameProvider.gold;
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
    _comboAnimController.dispose();
    _heartPulseController.dispose();
    _coinShineController.dispose();
    _comboTimerController.dispose();
    _slideDownController.dispose();
    _slideUpController.dispose();
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

  // Invalid placement: brief red HUD flash + error buzz
  void _triggerInvalidPlacementFeedback() {
    setState(() => _showRedFlash = true);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _showRedFlash = false);
    });
  }

  void _showWaveCompleteBanner(String text) {
    setState(() {
      _showWaveComplete = true;
      _waveCompleteText = text;
    });
    _waveAnimController.forward(from: 0);
    if (_soundEnabled) _audioService.playSfx(SoundType.waveClear);
  }

  // NEW: Wave start announcement banner with slide down animation
  void _showWaveStartBanner(int waveNum) {
    final isBoss = waveNum == _gameProvider.totalWaves;
    setState(() {
      _showWaveStart = true;
      _waveStartWaveNum = waveNum;
      _waveStartText = isBoss ? '👑 最終波' : '🌊 除菌風暴';
    });
    _slideDownController.forward(from: 0);
    if (_soundEnabled) _audioService.playSfx(SoundType.waveStart);
    
    // Auto-dismiss after 2s then slide up
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _slideUpController.forward(from: 0).then((_) {
          if (mounted) setState(() => _showWaveStart = false);
        });
      }
    });
  }
  
  void _onEnemyReachEnd(TDEnemy enemy) {
    // Perfect wave tracking: enemy reached end, so not perfect
    _perfectWave = false;
    _killStreak = 0; // Reset kill streak when enemy reaches end
    
    // Play warning sound before life is lost
    if (_soundEnabled) _audioService.playSfx(SoundType.bossAlert);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_soundEnabled) _audioService.playSfx(SoundType.lifeLost);
    });
    _gameProvider.loseLife();
    _triggerScreenShake();
    if (_gameProvider.lives <= 0) {
      _handleGameOver();
    }
  }

  void _onEnemyKilled(TDEnemy enemy) {
    _lastKillTime = DateTime.now(); // Reset combo timer on kill
    _gameProvider.addGold(enemy.goldReward);
    _gameProvider.addScore(enemy.points);
    _gameProvider.incrementCombo();
    if (_soundEnabled) _audioService.playSfx(SoundType.kill);
    
    // Kill streak tracking
    _killStreak++;
    if (_killStreak > 0 && _killStreak % 5 == 0) {
      // Every 5 consecutive kills = +20 gold bonus
      _gameProvider.addGold(20);
      _addFloatingText('🔥 +20 連殺!', enemy.position, Colors.orange, type: 'streak', scale: 1.3);
    }
    
    // Check combo milestones
    final combo = _gameProvider.combo;
    if (combo >= 10) {
      _showComboBannerMessage('COMBO x10!', Colors.purple);
      _gameProvider.addGold(50);
      if (_soundEnabled) _audioService.playSfx(SoundType.achievement);
    } else if (combo >= 5) {
      _showComboBannerMessage('厲害!', Colors.amber);
      _gameProvider.addGold(10);
      if (_soundEnabled) _audioService.playSfx(SoundType.achievement);
    } else if (combo >= 3) {
      _showComboBannerMessage('良好!', Colors.green);
      if (_soundEnabled) _audioService.playSfx(SoundType.achievement);
    }
    
    // Phase 5: Show floating gold text with HK$ icon
    _addFloatingText(
      'HK\$${enemy.goldReward}',
      enemy.position,
      Colors.amber,
      type: 'gold',
      scale: 1.2,
    );
    
    // Phase 10: Spawn kill particles and screen flash
    _spawnKillParticles(enemy.position, _getEnemyColor(enemy.type));
    _triggerKillFlash();
    
    if (_gameProvider.comboCount >= 10) {
      _showComboBannerX10();
      if (_soundEnabled) _audioService.playSfx(SoundType.achievement);
    }
  }

  // Show combo milestone banner
  void _showComboBannerMessage(String text, Color color) {
    setState(() {
      _showComboBanner = true;
      _comboBannerText = text;
    });
    _comboAnimController.forward(from: 0);
  }
  
  // Combo timer bar calculation (0.0 = full, 1.0 = empty)
  double _getComboTimerProgress() {
    if (_lastKillTime == null) return 1.0;
    final elapsed = DateTime.now().difference(_lastKillTime!).inMilliseconds;
    final progress = elapsed / (_comboTimeoutSeconds * 1000);
    return progress.clamp(0.0, 1.0);
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
      case TDEnemyType.poison: return Colors.green;
      case TDEnemyType.elite: return Colors.amber;
      case TDEnemyType.swarm: return Colors.lightBlue;
    }
  }

  // Phase 10: Trigger white screen flash for 50ms
  void _triggerKillFlash() {
    setState(() => _showKillFlash = true);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _showKillFlash = false);
    });
  }

  // Combo achievement banner: fires when comboCount >= 10
  void _showComboBannerX10() {
    setState(() {
      _showComboBanner = true;
      _comboBannerText = '🔥 COMBO x10! +50 bonus';
    });
    _comboAnimController.forward(from: 0);
  }

  // Phase 5: Add floating text (Redesigned with type, random drift)
  void _addFloatingText(String text, Offset position, Color color, {String type = 'gold', double scale = 1.0}) {
    final random = Random();
    final driftX = (random.nextDouble() - 0.5) * 2.0; // Random horizontal drift -1 to 1
    _floatingTexts.add(_FloatingText(
      text: text,
      position: position,
      color: color,
      type: type,
      scale: scale,
      velocityX: driftX,
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
    setState(() => _isGameOver = true);
    if (_soundEnabled) _audioService.playSfx(SoundType.gameLose);
  }

  void _handleWaveComplete() {
    final completedWave = _gameProvider.currentWave;
    final nextWave = completedWave + 1;

    // Interest on unspent gold: 5% per completed wave (only if not victory)
    if (nextWave <= _gameProvider.totalWaves) {
      final interestRate = 0.05;
      final interestEarned = (_gameProvider.gold * interestRate).round();
      if (interestEarned > 0) {
        _gameProvider.addGold(interestEarned);
        _addFloatingText(
          '🏦 利息: +\$$interestEarned',
          const Offset(300, 100),
          Colors.green,
          type: 'interest',
          scale: 1.2,
        );
      }
    }

    // Perfect wave bonus: no enemy reached end during wave = +50 gold
    if (_perfectWave) {
      _gameProvider.addGold(50);
      _addFloatingText(
        '⭐ 完美通關! +\$50',
        const Offset(300, 150),
        Colors.amber,
        type: 'perfect',
        scale: 1.3,
      );
    }
    
    // Reset for next wave
    _perfectWave = true;
    _killStreak = 0;
    
    // Reset comboCount when wave completes
    _gameProvider.resetComboCount();

    if (nextWave > _gameProvider.totalWaves || widget.level == 10) {
      _showWaveCompleteBanner('🏆 勝利！');
      if (_soundEnabled) _audioService.playSfx(SoundType.gameWin);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      _showWaveCompleteBanner('✅ 第 $completedWave 波完成');
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _showWaveStartBanner(nextWave);
          _gameProvider.startWave();
        }
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
          
          // Wave start banner (new redesign)
          if (_showWaveStart)
            _buildWaveStartBanner(),
          
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
          
          // Game Over screen
          if (_isGameOver)
            _buildGameOverScreen(),
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

  // ═══════════════════════════════════════════════════════════
  //  GAME OVER SCREEN - 陳蒨妤 biohazard theme
  // ═══════════════════════════════════════════════════════════
  
  Widget _buildGameOverScreen() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Stack(
          children: [
            // Biohazard pattern background
            CustomPaint(
              painter: _BiohazardPatternPainter(),
              size: Size.infinite,
            ),
            // Content
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Title: 香港除菌風暴 — 陳蒨妤
                  Text(
                    '香港除菌風暴 — 陳蒨妤',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: const Color(0xFF00D4FF).withOpacity(0.5), blurRadius: 10),
                        const Shadow(color: Colors.black87, blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Rotating biohazard icon
                  RotationTransition(
                    turns: AlwaysStoppedAnimation(_animTime / 4),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D4FF).withOpacity(0.6),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '☣️',
                          style: TextStyle(fontSize: 70),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Stats panel
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        _buildGameOverStatRow('💰', '最終得分', '${_displayScore}'),
                        const Divider(color: Colors.white24, height: 20),
                        _buildGameOverStatRow('🌊', '存活波數', '${_displayWave}'),
                        const Divider(color: Colors.white24, height: 20),
                        _buildGameOverStatRow('💀', '消滅敵人', '${_gameProvider.totalEnemiesKilled}'),
                        const Divider(color: Colors.white24, height: 20),
                        _buildGameOverStatRow('💵', '賺取金幣', 'HK\$${_displayGold}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 蒨妤 watermark
                  Text(
                    '蒨妤',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: const Color(0xFF00D4FF).withOpacity(0.4), blurRadius: 15),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Buttons row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 重新開始 button
                        GestureDetector(
                          onTap: () {
                            // Restart game
                            setState(() {
                              _isGameOver = false;
                              _gameProvider.reset();
                              _displayWave = 1;
                              _displayScore = 0;
                              _displayGold = 0;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            decoration: BoxDecoration(
                              color: const Color(0xFF27AE60),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF27AE60).withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh, color: Colors.white, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  '重新開始',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 返回關卡選擇 button
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF39C12),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF39C12).withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.map, color: Colors.white, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  '返回關卡選擇',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverStatRow(String icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ENHANCED HUD - Redesigned with animations
  // ═══════════════════════════════════════════════════════════

  late AnimationController _heartPulseController;
  late AnimationController _coinShineController;
  late AnimationController _comboTimerController;
  late AnimationController _slideDownController;
  late AnimationController _slideUpController;

  // Track gold changes for bounce animation
  int _prevGold = 0;
  bool _goldBounceTrigger = false;

  @override
  void initState() {
    super.initState();
    // ... existing initState code ...

    _heartPulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..addListener(() => setState(() {}));

    _coinShineController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..addListener(() => setState(() {}));

    _comboTimerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _slideDownController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideUpController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    // controllers are disposed in the main dispose() above
    super.dispose();
  }

  // Trigger gold bounce animation
  void _triggerGoldBounce() {
    if (_gameProvider.gold > _prevGold) {
      _goldBounceTrigger = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _goldBounceTrigger = false);
      });
    }
    _prevGold = _gameProvider.gold;
  }

  Widget _buildHUD() {
    // Trigger gold bounce when gold increases
    if (_gameProvider.gold > _prevGold) {
      _triggerGoldBounce();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.8), Colors.black.withOpacity(0.6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Lives with pulse animation
              _buildAnimatedLives(),
              // Gold with shine and bounce
              _buildAnimatedGold(),
              // Level with biohazard emoji
              _buildLevelDisplay(),
              // Score with roll effect
              _buildAnimatedScore(),
              // Combo with fire and timer bar
              _buildComboDisplay(),
              // Speed pill buttons
              _buildSpeedControl(),
              // Sound toggle
              _buildSoundButton(),
              // Pause button
              _buildPauseButton(),
            ],
          ),
          const SizedBox(height: 6),
          // Wave info bar
          _buildWaveInfoBar(),
        ],
      ),
    );
  }

  Widget _buildAnimatedLives() {
    final lives = _gameProvider.lives;
    final isCritical = lives <= 1;
    final isLow = lives < 3 && lives > 1;

    // Pulse animation when low lives
    if (isLow && !_heartPulseController.isAnimating) {
      _heartPulseController.repeat(reverse: true);
    } else if (!isLow && _heartPulseController.isAnimating) {
      _heartPulseController.stop();
      _heartPulseController.value = 0;
    }

    final pulseScale = isLow ? 1.0 + 0.15 * _heartPulseController.value : 1.0;
    final glowOpacity = isCritical ? 0.6 + 0.4 * _heartPulseController.value : (isLow ? 0.3 * _heartPulseController.value : 0.0);
    final heartColor = isCritical ? Colors.red : Colors.pinkAccent;

    return Transform.scale(
      scale: pulseScale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isCritical || isLow
              ? [BoxShadow(color: Colors.red.withOpacity(glowOpacity), blurRadius: 12, spreadRadius: 2)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('❤️', style: TextStyle(fontSize: 16 + (isLow ? 2 * _heartPulseController.value : 0))),
            const SizedBox(width: 4),
            Text(
              '$lives',
              style: TextStyle(
                color: heartColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: isCritical ? [const Shadow(color: Colors.red, blurRadius: 8)] : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedGold() {
    final shineProgress = _coinShineController.value;
    final bounceOffset = _goldBounceTrigger ? sin(_coinShineController.value * pi * 4) * 8 : 0.0;

    // Trigger shine when gold changes
    if (_gameProvider.gold != _prevGold && !_coinShineController.isAnimating) {
      _coinShineController.forward(from: 0);
    }

    return Transform.translate(
      offset: Offset(0, bounceOffset),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Coin with shine effect
            Stack(
              alignment: Alignment.center,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 16)),
                if (shineProgress > 0.7)
                  Positioned(
                    left: 4 * shineProgress,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(1 - shineProgress),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            Text(
              '$_displayGold',
              style: const TextStyle(
                color: AppTheme.textGold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🦠', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '第${widget.level}關/10',
            style: const TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedScore() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💯', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$_displayScore',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComboDisplay() {
    final combo = _gameProvider.combo;
    // Only show combo when comboCount > 1 (not a real combo at 1.0)
    if (_gameProvider.comboCount <= 1) {
      return const SizedBox.shrink();
    }

    // Use time-based progress instead of animation controller
    final comboProgress = 1.0 - _getComboTimerProgress();

    // Pulse scale for fire emoji based on combo level
    final fireScale = combo >= 10 ? 1.3 : (combo >= 5 ? 1.2 : 1.0);

    return Transform.scale(
      scale: fireScale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 2),
          Text(
            'x${combo.toStringAsFixed(1)}',
            style: TextStyle(
              color: combo > 1 ? Colors.orangeAccent : Colors.white60,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          // Depleting timer bar (time-based)
          Container(
            width: 40,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: comboProgress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.red],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedControl() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _speedPillButton('1x', 1.0),
          _speedPillButton('2x', 2.0),
          _speedPillButton('3x', 3.0),
        ],
      ),
    );
  }

  Widget _speedPillButton(String label, double speed) {
    final isSelected = _gameSpeed == speed;
    return GestureDetector(
      onTap: () {
        setState(() => _gameSpeed = speed);
        _gameProvider.setGameSpeed(speed);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSoundButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _soundEnabled = !_soundEnabled);
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _soundEnabled ? Icons.volume_up : Icons.volume_off,
          color: _soundEnabled ? Colors.white : Colors.white38,
          size: 18,
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

  // Phase 8: Wave info bar showing wave progress, enemies count, next wave preview
  Widget _buildWaveInfoBar() {
    final currentWave = _gameProvider.currentWave;
    final totalWaves = _gameProvider.totalWaves;
    final enemiesOnField = _gameProvider.enemies.length;
    final remaining = _gameProvider.enemiesRemaining;   // NEW: enemies yet to spawn + alive on field
    final total = _gameProvider.enemiesThisWave;          // NEW: total for this wave
    final waveProgress = _gameProvider.waveProgress;
    final nextWavePreview = currentWave < totalWaves ? '第 ${currentWave + 1} 波' : '最終波';
    final statusText = enemiesOnField > 0
        ? '剩余 $remaining/$total'
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
          final cost = _gameProvider.getTowerCost(_gameProvider.selectedTowerType!);
          if (_gameProvider.gold >= cost) {
            final tower = _gameProvider.createTower(
              _gameProvider.selectedTowerType!,
              pos,
            );
            _onTowerPlaced(tower);
          } else {
            // Invalid placement: not enough gold - flash red HUD + error buzz
            _triggerInvalidPlacementFeedback();
            if (_soundEnabled) _audioService.playSfx(SoundType.hit);
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

  // Chinese tower names for 陳蒨妤 biohazard theme
  String _getTowerChineseName(TDTowerType type) {
    switch (type) {
      case TDTowerType.laser: return '等離子追蹤炮';
      case TDTowerType.global: return '全域脈衝塔';
      case TDTowerType.poison: return '毒疫擴散炮';
      case TDTowerType.slow: return '冰凍束縛炮';
      case TDTowerType.sniper: return '狙擊穿透炮';
      case TDTowerType.splash: return '爆炸衝擊炮';
      case TDTowerType.basic: return '標準步槍塔';
    }
  }

  Widget _buildTowerPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.88),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
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
              _towerButton(TDTowerType.basic,  _getTowerChineseName(TDTowerType.basic),  '🔫', _gameProvider.getTowerCost(TDTowerType.basic)),
              _towerButton(TDTowerType.sniper, _getTowerChineseName(TDTowerType.sniper), '🎯', _gameProvider.getTowerCost(TDTowerType.sniper)),
              _towerButton(TDTowerType.splash, _getTowerChineseName(TDTowerType.splash), '💥', _gameProvider.getTowerCost(TDTowerType.splash)),
              _towerButton(TDTowerType.slow,   _getTowerChineseName(TDTowerType.slow),   '❄️', _gameProvider.getTowerCost(TDTowerType.slow)),
              _towerButton(TDTowerType.laser,  _getTowerChineseName(TDTowerType.laser),  '⚡', _gameProvider.getTowerCost(TDTowerType.laser)),
              _towerButton(TDTowerType.global, _getTowerChineseName(TDTowerType.global), '🌐', _gameProvider.getTowerCost(TDTowerType.global)),
              _towerButton(TDTowerType.poison, _getTowerChineseName(TDTowerType.poison), '☠️', _gameProvider.getTowerCost(TDTowerType.poison)),
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
    final towerName = _getTowerChineseName(tower.type);
    
    // Build upgrade stars with glow effect
    String starsStr = '';
    for (int i = 0; i < 3; i++) {
      if (i < tower.level) {
        starsStr += '⭐';
      } else {
        starsStr += '☆';
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Tower name + stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.military_tech, color: Color(0xFF00D4FF), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '塔升級',
                      style: TextStyle(
                        color: const Color(0xFF00D4FF),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: const Color(0xFF00D4FF).withOpacity(0.5), blurRadius: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tower name
          Text(
            towerName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // Level stars with glow
          Text(
            starsStr,
            style: TextStyle(
              fontSize: 18,
              shadows: [
                Shadow(color: Colors.amber.withOpacity(0.8), blurRadius: tower.level > 0 ? 12 : 0),
                Shadow(color: Colors.amber.withOpacity(0.5), blurRadius: tower.level > 0 ? 20 : 0),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Upgrade button with red tint when can't afford
              GestureDetector(
                onTap: canUpgrade
                    ? () {
                        _gameProvider.upgradeTower(tower);
                        HapticFeedback.mediumImpact();
                        if (_soundEnabled) _audioService.playSfx(SoundType.achievement);
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: canUpgrade 
                        ? AppTheme.success 
                        : AppTheme.error.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: canUpgrade ? AppTheme.success : Colors.red.shade400,
                      width: 1.5,
                    ),
                    boxShadow: canUpgrade ? [
                      BoxShadow(color: AppTheme.success.withOpacity(0.4), blurRadius: 8),
                    ] : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tower.level < 3 ? '⬆️ 升級 💰$upgradeCost' : '已滿級',
                        style: TextStyle(
                          color: canUpgrade ? Colors.white : Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Sell button - HK$ format
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
                    '出售 +HK\$$sellValue',
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

  // ═══════════════════════════════════════════════════════════
  //  WAVE START BANNER - Redesigned with slide animation
  // ═══════════════════════════════════════════════════════════
  
  Widget _buildWaveStartBanner() {
    return AnimatedBuilder(
      animation: _slideDownController,
      builder: (context, child) {
        // Slide down animation (0.0 to 0.5) then slide up (0.5 to 1.0)
        final slideProgress = _slideDownController.value;
        final slideUpProgress = _slideUpController.value;
        
        double slideOffset;
        if (slideProgress <= 0.5) {
          // Sliding down
          slideOffset = -1.0 + (slideProgress * 2); // -1 to 0
        } else {
          // Sliding up (after 2s delay)
          slideOffset = 0.0 - (slideUpProgress * 1.0); // 0 to -1
        }
        
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Transform.translate(
            offset: Offset(0, slideOffset * 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.95),
                    AppTheme.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(color: AppTheme.primary.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Large level number with glow
                  Text(
                    '第 $_waveStartWaveNum 關',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: AppTheme.primary.withOpacity(0.8), blurRadius: 20),
                        Shadow(color: Colors.white.withOpacity(0.5), blurRadius: 10),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Subtitle with scanline animation
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.white, Colors.white70, Colors.white],
                      stops: const [0.0, 0.5, 1.0],
                    ).createShader(bounds),
                    child: Text(
                      _waveStartText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Enemy type icons preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildEnemyIcon('🐀', '普通'),
                      const SizedBox(width: 12),
                      _buildEnemyIcon('🦗', '快速'),
                      const SizedBox(width: 12),
                      _buildEnemyIcon('🪲', '坦克'),
                      if (_waveStartWaveNum == _gameProvider.totalWaves) ...[
                        const SizedBox(width: 12),
                        _buildEnemyIcon('👾', 'BOSS'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Watermark
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '陳蒨妤',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildEnemyIcon(String emoji, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  WAVE COMPLETE BANNER - Redesigned with slide up animation
  // ═══════════════════════════════════════════════════════════
  
  Widget _buildWaveCompleteBanner() {
    // Parse wave info from _waveCompleteText
    final isVictory = _waveCompleteText.contains('勝利');
    final isGameOver = _waveCompleteText.contains('遊戲結束');
    final isPerfect = _waveCompleteText.contains('完美');
    
    // Extract wave number if present
    int? waveNum;
    final waveMatch = RegExp(r'第 (\d+) 波').firstMatch(_waveCompleteText);
    if (waveMatch != null) {
      waveNum = int.tryParse(waveMatch.group(1)!);
    }
    
    return AnimatedBuilder(
      animation: _waveAnimController,
      builder: (context, child) {
        final progress = _waveAnimController.value;
        // Slide up from bottom (0.0 = off screen, 0.5 = center, 1.0 = top)
        final slideOffset = progress < 0.3 ? (0.7 - progress * 2.0/0.3) : 0.0;
        final scale = progress < 0.3 ? 0.5 + (progress * 2.0/0.3 * 0.5) : 1.0;
        final opacity = progress < 0.7 ? 1.0 : (1.0 - ((progress - 0.7) / 0.3));
        
        return Positioned(
          bottom: 0,
          left: 20,
          right: 20,
          child: Transform.translate(
            offset: Offset(0, slideOffset * 400),
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: isVictory 
                        ? LinearGradient(colors: [Colors.amber.shade700, Colors.amber.shade500], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                        : isGameOver 
                            ? LinearGradient(colors: [Colors.red.shade700, Colors.red.shade500], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                            : AppTheme.orangeGradient,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: AppTheme.glowShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Wave number
                      if (waveNum != null) ...[
                        Text(
                          '第 $waveNum 波完成',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Main text
                      Text(
                        _waveCompleteText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // Perfect wave badge
                      if (isPerfect) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('⭐', style: TextStyle(fontSize: 20)),
                              SizedBox(width: 8),
                              Text(
                                '完美通關!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Interest notification
                      if (_waveCompleteText.contains('利息')) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🏦', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(
                                '利息: +${_waveCompleteText.split('+').last.replaceAll(RegExp(r'[^0-9]'), '')}',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Next wave countdown
                      if (!isVictory && !isGameOver && waveNum != null) ...[
                        const SizedBox(height: 16),
                        _buildNextWaveCountdown(waveNum + 1),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildNextWaveCountdown(int nextWave) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 0.0),
      duration: const Duration(seconds: 3),
      builder: (context, value, child) {
        final seconds = (3 * value).ceil();
        return Column(
          children: [
            Text(
              '下一波來襲',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$seconds...',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
      case TDTowerType.laser:
        // Double barrel
        canvas.drawRect(Rect.fromCenter(center: const Offset(-5, -8), width: 8, height: 24), bodyPaint);
        canvas.drawRect(Rect.fromCenter(center: const Offset(5, -8), width: 8, height: 24), bodyPaint);
        break;
      case TDTowerType.global:
        // Globe shape with ring
        canvas.drawCircle(const Offset(0, 0), 16, bodyPaint);
        final ringPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(const Offset(0, 0), 22, ringPaint);
        break;
      case TDTowerType.poison:
        // Bio-hazard look
        canvas.drawCircle(const Offset(0, 0), 16, bodyPaint);
        final bioPaint = Paint()
          ..color = Colors.greenAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(const Offset(0, 0), 12, bioPaint);
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
    
    // Health bar - Redesigned with tapered pill shape, gradient, critical effects
    final isBoss = enemy.type == TDEnemyType.boss;
    final isCritical = healthRatio < 0.25;
    final barWidth = _getHealthBarWidth(enemy.type);
    final barHeight = _getHealthBarHeight(enemy.type);
    final barYOffset = _getHealthBarYOffset(enemy.type);
    
    // Boss bars are 3x larger and always visible, purple accent
    final actualWidth = isBoss ? barWidth * 3 : barWidth;
    final actualHeight = isBoss ? barHeight * 3 : barHeight;
    final barCenter = center.translate(0, barYOffset);
    
    // Critical shake effect
    double shakeX = 0;
    if (isCritical && !isBoss) {
      shakeX = 2 * sin(_animTime * 30);
    }
    
    // Background: dark Color(0xAA000000) with rounded pill shape
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: barCenter.translate(shakeX, 0), width: actualWidth, height: actualHeight),
      Radius.circular(actualHeight / 2),
    );
    final healthBgPaint = Paint()
      ..color = const Color(0xAA000000)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bgRect, healthBgPaint);
    
    // Health fill with gradient Green->Amber->Red based on HP %
    final healthWidth = actualWidth * healthRatio;
    Color healthColor;
    if (healthRatio > 0.5) {
      healthColor = Color.lerp(Colors.green, Colors.amber, (healthRatio - 0.5) * 2)!;
    } else if (healthRatio > 0.25) {
      healthColor = Color.lerp(Colors.orange, Colors.red, (0.5 - healthRatio) * 4)!;
    } else {
      healthColor = Colors.red;
    }
    
    if (healthWidth > 0) {
      final healthRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          barCenter.dx - actualWidth / 2 + shakeX,
          barCenter.dy - actualHeight / 2,
          healthWidth,
          actualHeight,
        ),
        Radius.circular(actualHeight / 2),
      );
      
      // Critical pulsing glow for low HP
      if (isCritical) {
        final glowIntensity = 0.5 + 0.5 * sin(_animTime * 10);
        final glowPaint = Paint()
          ..color = Colors.red.withOpacity(glowIntensity * 0.6)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
        canvas.drawRRect(healthRect, glowPaint);
      }
      
      final healthPaint = Paint()
        ..color = healthColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(healthRect, healthPaint);
    }
    
    // Boss crown icon and always-visible health bar
    if (isBoss) {
      // Crown icon next to health bar
      final crownPainter = TextPainter(
        text: const TextSpan(
          text: '👑',
          style: TextStyle(fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      );
      crownPainter.layout();
      crownPainter.paint(
        canvas,
        barCenter - Offset(actualWidth / 2 + 12, crownPainter.height / 2),
      );
      
      // Purple accent glow for boss
      final bossGlowPaint = Paint()
        ..color = const Color(0xFF9B59B6).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
      canvas.drawRRect(bgRect, bossGlowPaint);
    }
    
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
      case TDTowerType.laser: return Colors.red;
      case TDTowerType.global: return Colors.teal;
      case TDTowerType.poison: return Colors.greenAccent;
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

  Color _getEnemyColor(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.normal: return Colors.brown;
      case TDEnemyType.fast: return Colors.yellow;
      case TDEnemyType.tank: return Colors.red;
      case TDEnemyType.boss: return Colors.deepPurple;
      case TDEnemyType.poison: return Colors.green;
      case TDEnemyType.elite: return Colors.amber;
      case TDEnemyType.swarm: return Colors.lightBlue;
    }
  }

  String _getEnemyEmoji(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.normal: return '🪳';
      case TDEnemyType.fast: return '🏃';
      case TDEnemyType.tank: return '🛡️';
      case TDEnemyType.boss: return '👑';
      case TDEnemyType.poison: return '☠️';
      case TDEnemyType.elite: return '⭐';
      case TDEnemyType.swarm: return '🐜';
    }
  }

  Color _getProjectileColor(TDProjectileType type) {
    switch (type) {
      case TDProjectileType.bullet: return Colors.yellow;
      case TDProjectileType.sniper: return Colors.purple;
      case TDProjectileType.explosive: return Colors.orange;
      case TDProjectileType.ice: return Colors.lightBlueAccent;
      case TDProjectileType.laser: return Colors.red;
      case TDProjectileType.poison: return Colors.greenAccent;
    }
  }

  // Phase 4: Enhanced tower range preview with silhouette, blue glow, pulsing, green/red tint
  void _drawTowerPreview(Canvas canvas) {
    if (towerPreviewPosition == null || towerPreviewType == null) return;
    
    final range = TDGameProvider.getTowerBaseRange(towerPreviewType!);
    final type = towerPreviewType!;
    final pos = towerPreviewPosition!;
    
    // Pulsing animation: scale 0.95 -> 1.05, 500ms loop
    final pulseScale = 1.0 + 0.05 * sin(_animTime * 12.566); // 2*pi * 2 (2 cycles per second)
    final scaledRange = range * pulseScale;
    
    // Determine placement validity (for green/red tint)
    final isValidPlacement = _gameProvider.canPlaceTower(pos);
    final tintColor = isValidPlacement 
        ? const Color(0x8800FF00)  // Green tint for valid
        : const Color(0x88FF0000); // Red tint for invalid
    
    // Blue glow outline color
    const glowColor = Color(0xFF00D4FF);
    
    // Draw tower silhouette shape (hexagonal for tech feel)
    final silhouetteSize = 30.0 * pulseScale;
    final silhouettePath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * pi / 180;
      final x = pos.dx + silhouetteSize * cos(angle);
      final y = pos.dy + silhouetteSize * sin(angle);
      if (i == 0) {
        silhouettePath.moveTo(x, y);
      } else {
        silhouettePath.lineTo(x, y);
      }
    }
    silhouettePath.close();
    
    // Silhouette fill with tint
    final silhouetteFillPaint = Paint()
      ..color = tintColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(silhouettePath, silhouetteFillPaint);
    
    // Silhouette stroke with blue glow
    final silhouetteStrokePaint = Paint()
      ..color = glowColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
    canvas.drawPath(silhouettePath, silhouetteStrokePaint);
    
    // Second stroke for stronger glow
    final silhouetteStrokePaint2 = Paint()
      ..color = glowColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(silhouettePath, silhouetteStrokePaint2);
    
    // Range circle fill
    final fillPaint = Paint()
      ..color = glowColor.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, scaledRange, fillPaint);
    
    // Range circle border with blue glow
    final borderPaint = Paint()
      ..color = glowColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
    canvas.drawCircle(pos, scaledRange, borderPaint);
    
    // Inner range ring
    final innerBorderPaint = Paint()
      ..color = glowColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(pos, scaledRange * 0.7, innerBorderPaint);
    
    // Tower name label floating above ghost
    final towerName = _getTowerChineseName(type);
    final labelPainter = TextPainter(
      text: TextSpan(
        text: towerName,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: glowColor.withOpacity(0.8), blurRadius: 6),
            const Shadow(color: Colors.black87, blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      pos - Offset(labelPainter.width / 2, silhouetteSize + 18),
    );
    
    // Tower icon in center
    final iconPainter = TextPainter(
      text: TextSpan(
        text: _getTowerEmoji(type),
        style: const TextStyle(fontSize: 18),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      pos - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );
  }

  // Phase 5: Draw floating texts (Redesigned with type-based styling)
  void _drawFloatingTexts(Canvas canvas) {
    for (final ft in floatingTexts) {
      // Determine font size based on type and scale
      double fontSize = 16;
      Color textColor = ft.color;
      List<Shadow> shadows = const [Shadow(color: Colors.black54, blurRadius: 4)];
      
      switch (ft.type) {
        case 'gold':
          fontSize = 18 * ft.scale;
          textColor = Colors.amber;
          shadows = [
            Shadow(color: Colors.black87, blurRadius: 4),
            Shadow(color: Colors.amber.withOpacity(0.5), blurRadius: 8),
          ];
          break;
        case 'damage':
          fontSize = 20 * ft.scale;
          // Critical damage is red, normal is yellow
          textColor = ft.color; // Passed in as yellow or red
          shadows = [
            Shadow(color: Colors.black87, blurRadius: 4),
            Shadow(color: textColor.withOpacity(0.6), blurRadius: 10),
          ];
          break;
        case 'combo':
          fontSize = 24 * ft.scale;
          textColor = Colors.orangeAccent;
          shadows = [
            Shadow(color: Colors.black87, blurRadius: 4),
            Shadow(color: Colors.orange.withOpacity(0.8), blurRadius: 15),
          ];
          break;
        case 'interest':
          fontSize = 18 * ft.scale;
          textColor = Colors.greenAccent;
          shadows = [
            Shadow(color: Colors.black87, blurRadius: 4),
            Shadow(color: Colors.green.withOpacity(0.6), blurRadius: 8),
          ];
          break;
        case 'streak':
          fontSize = 22 * ft.scale;
          textColor = Colors.orange;
          shadows = [
            Shadow(color: Colors.black87, blurRadius: 4),
            Shadow(color: Colors.deepOrange.withOpacity(0.7), blurRadius: 12),
          ];
          break;
      }
      
      // Apply scale animation (bounce effect for gold)
      final scale = ft.type == 'gold' && ft.opacity > 0.5 
          ? ft.scale * (1.0 + 0.1 * sin(ft.opacity * pi * 2))
          : ft.scale;
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: textColor.withOpacity(ft.opacity.clamp(0.0, 1.0)),
            fontSize: fontSize * scale,
            fontWeight: FontWeight.bold,
            shadows: shadows,
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

  // Phase 6: Health bar width by enemy type (3x for boss)
  double _getHealthBarWidth(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.boss: return 60;
      case TDEnemyType.tank: return 40;
      case TDEnemyType.fast: return 28;
      default: return 32;
    }
  }

  // Phase 6: Health bar height by enemy type (minimum 4px for small enemies)
  double _getHealthBarHeight(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.boss: return 10;
      case TDEnemyType.tank: return 7;
      case TDEnemyType.fast: return 4;
      default: return 5;
    }
  }

  // Phase 6: Health bar Y offset by enemy type
  double _getHealthBarYOffset(TDEnemyType type) {
    switch (type) {
      case TDEnemyType.boss: return -40;
      case TDEnemyType.tank: return -30;
      case TDEnemyType.fast: return -22;
      default: return -26;
    }
  }

  @override
  bool shouldRepaint(covariant TDGamePainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════
//  BIOHAZARD PATTERN PAINTER - for Game Over screen
// ═══════════════════════════════════════════════════════════

class _BiohazardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D4FF).withOpacity(0.05)
      ..style = PaintingStyle.fill;
    
    const spacing = 80.0;
    const biohazard = '☣️';
    
    final textPainter = TextPainter(
      text: const TextSpan(
        text: biohazard,
        style: TextStyle(fontSize: 40),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // Draw repeating biohazard symbols
    for (double y = 0; y < size.height + spacing; y += spacing) {
      for (double x = 0; x < size.width + spacing; x += spacing) {
        // Offset every other row
        final offsetX = ((y / spacing) % 2 == 0) ? 0.0 : spacing / 2;
        textPainter.paint(canvas, Offset(x + offsetX - 20, y - 20));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

enum TDTowerType { basic, sniper, splash, slow, laser, global, poison }
enum TDEnemyType { normal, fast, tank, boss, poison, elite, swarm }
enum TDProjectileType { bullet, sniper, explosive, ice, laser, poison }

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
  int totalWaves = 5;
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

  // Remaining = not-yet-spawned + still-alive enemies
  int get enemiesRemaining => (_enemiesPerWave - _enemiesSpawnedThisWave) + enemies.length;

  // NEW: Total enemies for this wave
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

  void startWave() {
    isPlaying = true; // <-- BUG FIX: must be true for _updateGame() to run!
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
    
    // Boss at level 10 final wave (using totalWaves which is 5, so currentWave >= 5 is final)
    if (currentWave >= 5 && roll < 0.08) {
      type = TDEnemyType.boss;
    } else if (currentWave >= 8 && roll < 0.2) {
      // Swarm: level 8+, very fast, low HP, spawns in groups of 3
      type = TDEnemyType.swarm;
    } else if (currentWave >= 6 && roll < 0.35) {
      // Elite: level 6+, gold shimmer, fast+tank hybrid
      type = TDEnemyType.elite;
    } else if (currentWave >= 5 && roll < 0.4) {
      type = TDEnemyType.tank;
    } else if (roll < 0.5) {
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
    
    // Swarm spawns in groups of 3 from same spawn point
    if (type == TDEnemyType.swarm) {
      for (int i = 0; i < 2; i++) {
        enemies.add(TDEnemy(
          id: _enemyIdCounter++,
          type: TDEnemyType.swarm,
          position: _waypoints.first + Offset(i * 10.0, 0),
          speed: _getEnemySpeed(TDEnemyType.swarm),
          maxHealth: _getEnemyHealth(TDEnemyType.swarm),
          currentHealth: _getEnemyHealth(TDEnemyType.swarm),
          goldReward: _getEnemyGoldReward(TDEnemyType.swarm),
          points: _getEnemyPoints(TDEnemyType.swarm),
        ));
      }
      _enemiesSpawnedThisWave += 2; // 2 extra spawned
    }
  }

  void _spawnToxicEnemy(TDEnemy original) {
    // Spawn a toxic version of the enemy at the original's position
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
      case TDEnemyType.elite: return baseSpeed * 1.8; // Fast + tank hybrid
      case TDEnemyType.swarm: return baseSpeed * 2.5; // Very fast
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
      case TDEnemyType.elite: return (baseHealth * 2).round(); // Tankier than normal
      case TDEnemyType.swarm: return (baseHealth * 0.3).round(); // Low HP
      default: return baseHealth;
    }
  }

  // Gold reward scales with wave number to keep economy balanced
  int _getEnemyGoldReward(TDEnemyType type) {
    final waveMultiplier = 1.0 + (currentWave - 1) * 0.15; // +15% per wave
    switch (type) {
      case TDEnemyType.fast: return (10 * waveMultiplier).round();
      case TDEnemyType.tank: return (20 * waveMultiplier).round();
      case TDEnemyType.boss: return (80 * waveMultiplier).round();
      case TDEnemyType.poison: return (15 * waveMultiplier).round();
      case TDEnemyType.elite: return (30 * waveMultiplier).round(); // High reward
      case TDEnemyType.swarm: return (5 * waveMultiplier).round(); // Low reward
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
      case TDEnemyType.swarm: return (8 * waveMultiplier).round();
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
    if (!isPlaying) return;
    
    // Combo timer: reset combo after 3 seconds without kill
    if (_lastKillTime != null) {
      final elapsed = DateTime.now().difference(_lastKillTime!).inSeconds;
      if (elapsed >= _comboTimeoutSeconds && combo > 1.0) {
        combo = 1.0;
        comboCount = 0;
      }
    }
    
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

      // Global tower: hits all enemies (no range check)
      if (tower.type == TDTowerType.global && enemies.isNotEmpty) {
        // Target the enemy furthest along the path
        for (final enemy in enemies) {
          if (enemy.pathProgress >= closestDist) {
            closestDist = enemy.pathProgress;
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
          
          // Apply poison effect - spawn toxic enemy on kill
          if (projectile.type == TDProjectileType.poison && enemy.currentHealth - projectile.damage <= 0) {
            _spawnToxicEnemy(enemy);
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
          
          // Laser bouncing: find next nearest enemy and redirect projectile
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
              continue; // don't remove this projectile
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
    if (gold >= cost && !isPositionOnPath(tower.position)) {
      gold -= cost;
      towers.add(tower);
      notifyListeners();
    }
  }

  // ─── Tower factory (single source of truth) ───
  // Phase 3: Stats per level [base, level2, level3]
  // fireRate = shots per second (e.g. 0.5 = 1 shot every 2 seconds)
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

  // Phase 4: Get base range for preview
  static double getTowerBaseRange(TDTowerType type) => _towerStats[type]!.range[0];

  // Phase 3: Get upgrade cost for a tower
  int getTowerUpgradeCost(TDTower tower) {
    if (tower.level >= 3) return -1;
    final baseCost = _towerStats[tower.type]!.baseCost;
    // Fixed: upgrade cost is always 60% of base cost (not multiplied by level)
    return (baseCost * 0.6).round();
  }

  // Phase 3: Get sell value for a tower (50% of total invested, using fixed upgrade cost)
  int getTowerSellValue(TDTower tower) {
    final baseCost = _towerStats[tower.type]!.baseCost;
    final upgradeCost = (baseCost * 0.6).round(); // fixed upgrade cost
    // Total = base + (level-1) × upgradeCost
    final totalInvested = baseCost + (tower.level - 1) * upgradeCost;
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

  bool isPositionOnPath(Offset position, {double threshold = 35}) {
    for (int i = 0; i < _waypoints.length - 1; i++) {
      final p1 = _waypoints[i];
      final p2 = _waypoints[i + 1];
      final dist = _distToSegment(position, p1, p2);
      if (dist < threshold) return true;
    }
    return false;
  }

  double _distToSegment(Offset p, Offset v, Offset w) {
    final l2 = (v - w).distanceSquared;
    if (l2 == 0) return (p - v).distance;
    final t = ((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2;
    final tClamped = t.clamp(0.0, 1.0);
    final proj = Offset(v.dx + tClamped * (w.dx - v.dx), v.dy + tClamped * (w.dy - v.dy));
    return (p - proj).distance;
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

  void resetComboCount() {
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