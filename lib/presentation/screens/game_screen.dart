import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/game_models.dart';
import '../../game/game_provider.dart';
import '../../game/components/cockroach_widget.dart';

class GameScreen extends StatefulWidget {
  final int level;
  const GameScreen({super.key, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameProvider _gameProvider;
  Timer? _spawnTimer;
  Timer? _gameTimer;
  Timer? _escapeTimer; // 蟑螂逃脫計時器
  Set<String> _newAchievements = {};

  @override
  void initState() {
    super.initState();
    _gameProvider = GameProvider();
    _gameProvider.loadState().then((_) {
      _gameProvider.onGameOver = () => _handleGameOver();
      _gameProvider.startGame(widget.level);
      _startTimers();
    });
  }

  void _startTimers() {
    _stopTimers();

    final cfg = _gameProvider.levelConfig;
    // 基礎生成間隔（受技能速度影響）
    final speedSkill = _gameProvider.gameState.skillLevels[SkillType.speed.index] ?? 0;
    final speedReduction = 1.0 - [0, 0.1, 0.2, 0.3][speedSkill];
    final spawnMs = (1000 / (cfg.spawnRate * speedReduction)).round();

    _spawnTimer = Timer.periodic(Duration(milliseconds: spawnMs), (_) {
      if (_gameProvider.isPlaying && !_gameProvider.isPaused) {
        _gameProvider.spawnCockroach();
      }
    });

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_gameProvider.isPlaying) return;
      if (!_gameProvider.isPaused) {
        _gameProvider.timeLeft--;
        if (_gameProvider.timeLeft <= 0) {
          _gameProvider.onTimeUp();
          _stopTimers();
        } else if (_gameProvider.checkWin()) {
          _gameProvider.onWin();
          _stopTimers();
        }
      }
    });

    // 蟑螂逃脫計時器（每2-4秒自動逃脫一隻）
    _escapeTimer = Timer.periodic(Duration(seconds: 2 + (cfg.level % 3)), (_) {
      if (_gameProvider.isPlaying && !_gameProvider.isPaused) {
        final active = _gameProvider.activeCockroaches;
        if (active.isNotEmpty) {
          final rand = DateTime.now().millisecondsSinceEpoch % active.length;
          _gameProvider.onCockroachEscape(active[rand].id);
        }
      }
    });
  }

  void _stopTimers() {
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    _escapeTimer?.cancel();
    _spawnTimer = _gameTimer = _escapeTimer = null;
  }

  void _restartGame() {
    _stopTimers();
    _gameProvider.startGame(widget.level);
    _startTimers();
  }

  void _handleGameOver() {
    final wasWin = _gameProvider.score >= _gameProvider.levelConfig.targetScore;
    _gameProvider.onLevelEnd(wasWin);
    _newAchievements = _gameProvider.getNewAchievements();
    if (_newAchievements.isNotEmpty) {
    }
    _stopTimers();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              isWin: wasWin,
              score: _gameProvider.score,
              level: widget.level,
              onRetry: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => GameScreen(level: widget.level)),
                );
              },
              onMenu: () => Navigator.of(context).pop(),
              newAchievements: _newAchievements,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _stopTimers();
    _gameProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _gameProvider,
      child: Scaffold(
        body: Consumer<GameProvider>(
          builder: (context, game, child) {
            return Stack(
              children: [
                _buildBackground(game),
                SafeArea(child: Column(children: [
                  _buildHUD(game),
                  Expanded(child: _buildPlayArea(game)),
                ])),
                if (game.isPaused) _buildPauseOverlay(game),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackground(GameProvider game) {
    final cfg = game.levelConfig;
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cfg.bgColorTop, cfg.bgColorBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // 動態背景裝飾
            ...List.generate(6, (i) => Positioned(
              left: (i * 70.0 + 20) % 360,
              top: (i * 110.0 + 40) % 700,
              child: Text(
                cfg.bgEmoji,
                style: TextStyle(
                  fontSize: 40,
                  color: Colors.white.withOpacity(0.04 + (i * 0.01)),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD(GameProvider game) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _hudChip('⏱', '${game.timeLeft}s', game.timeLeft <= 10 ? Colors.red : Colors.white),
              _hudChip('💯', '${game.score}', Colors.amber),
              _hudChip('❤️', '${game.lives}', game.lives <= 1 ? Colors.red : Colors.pinkAccent),
              _hudChip('🔥', 'x${game.combo.toStringAsFixed(1)}', Colors.orangeAccent),
            ],
          ),
        ),
        // 目標進度
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${game.levelConfig.name} · 第${widget.level}關',
                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${game.score} / ${game.levelConfig.targetScore}',
                    style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (game.score / game.levelConfig.targetScore).clamp(0, 1),
                  backgroundColor: AppTheme.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    game.checkWin() ? AppTheme.success : AppTheme.primary,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 控制按鈕
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ctrlBtn('⏸️', () {
              _gameProvider.togglePause();
              setState(() {});
            }),
            _ctrlBtn('🔄', _restartGame),
            _ctrlBtn('🏠', () => Navigator.of(context).pop()),
          ],
        ),
      ],
    );
  }

  Widget _hudChip(String emoji, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _ctrlBtn(String emoji, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }

  Widget _buildPlayArea(GameProvider game) {
    return GestureDetector(
      onTapDown: (details) {
        final pos = details.localPosition;
        // 檢查是否點到蟑螂（半徑放大）
        final radius = 40 * game.tapRadiusMultiplier;
        for (final c in game.activeCockroaches.reversed) {
          final dx = c.position.dx + 25 - pos.dx;
          final dy = c.position.dy + 25 - pos.dy;
          if (dx * dx + dy * dy <= radius * radius) {
            game.onCockroachTap(c.id, pos);
            return;
          }
        }
      },
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: game.activeCockroaches.map((c) => Positioned(
            left: c.position.dx,
            top: c.position.dy,
            child: CockroachWidget(
              key: ValueKey(c.id),
              data: c,
              onTap: () => game.onCockroachTap(c.id, c.position),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildPauseOverlay(GameProvider game) {
    return GestureDetector(
      onTap: () {
        _gameProvider.togglePause();
        setState(() {});
      },
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏸️', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 24),
              const Text(
                '遊戲暫停',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              _pauseBtn('▶️ 繼續', () {
                _gameProvider.togglePause();
                setState(() {});
              }),
              const SizedBox(height: 14),
              _pauseBtn('🔄 重新開始', () {
                _gameProvider.togglePause();
                _restartGame();
                setState(() {});
              }),
              const SizedBox(height: 14),
              _pauseBtn('🏠 主頁', () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pauseBtn(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: const TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
        )),
      ),
    );
  }
}

// ─── 結果畫面 ───
class ResultScreen extends StatelessWidget {
  final bool isWin;
  final int score;
  final int level;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  final Set<String> newAchievements;

  const ResultScreen({
    super.key,
    required this.isWin,
    required this.score,
    required this.level,
    required this.onRetry,
    required this.onMenu,
    this.newAchievements = const {},
  });

  @override
  Widget build(BuildContext context) {
    final cfg = LevelConfig.levels[level - 1];
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isWin
              ? [const Color(0xFF0D1F0D), const Color(0xFF0D3B1E)]
              : [const Color(0xFF1A0D0D), const Color(0xFF3B0D0D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(isWin ? '🏆' : '💀', style: const TextStyle(fontSize: 100)),
                const SizedBox(height: 20),
                Text(
                  isWin ? '第$level關 ${cfg.name} 完成！' : '挑戰失敗',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isWin ? '💯 最終得分: $score' : '💯 得分: $score / ${cfg.targetScore}',
                  style: const TextStyle(color: AppTheme.secondary, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                if (newAchievements.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: AppTheme.textGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.textGold.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text('🎉 新成就解鎖！', style: TextStyle(
                          color: AppTheme.textGold, fontWeight: FontWeight.bold,
                          fontSize: 16,
                        )),
                        const SizedBox(height: 8),
                        ...newAchievements.map((id) {
                          final ach = allAchievements.firstWhere((a) => a.id == id);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '${ach.emoji} ${ach.name}',
                              style: const TextStyle(color: AppTheme.textGold, fontSize: 14),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                _resultBtn(isWin ? '🔄 再玩一次' : '🔄 再試一次', onRetry),
                const SizedBox(height: 14),
                _resultBtn('🏠 回主頁', onMenu, secondary: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultBtn(String text, VoidCallback onTap, {bool secondary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
        decoration: BoxDecoration(
          color: secondary ? AppTheme.surfaceLight : AppTheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: secondary ? null : [
            BoxShadow(color: AppTheme.primary.withOpacity(0.5), blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}