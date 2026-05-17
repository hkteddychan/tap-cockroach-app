import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../game/game_provider.dart';
import '../../game/components/cockroach_widget.dart';

class GameScreen extends StatefulWidget {
  final int level;
  final VoidCallback onMenu;
  final VoidCallback onWin;
  final VoidCallback onLose;

  const GameScreen({super.key, required this.level, required this.onMenu, required this.onWin, required this.onLose});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameProvider _gameProvider;

  @override
  void initState() {
    super.initState();
    _gameProvider = GameProvider();
    _gameProvider.onGameOver = widget.onLose;
    _gameProvider.startGame(widget.level);
    _startSpawnTimer();
    _startGameTimer();
  }

  void _startSpawnTimer() {
    Future.doWhile(() async {
      if (!_gameProvider.isPlaying) return false;
      await Future.delayed(Duration(milliseconds: (1000 / _gameProvider.levelConfig.spawnRate * 1000).round()));
      if (_gameProvider.isPlaying && !_gameProvider.isPaused) {
        _gameProvider.spawnCockroach();
      }
      return _gameProvider.isPlaying;
    });
  }

  void _startGameTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_gameProvider.isPlaying) return false;
      if (!_gameProvider.isPaused) {
        _gameProvider.timeLeft--;
        if (_gameProvider.timeLeft <= 0) {
          _gameProvider.onTimeUp();
          return false;
        }
        if (_gameProvider.checkWin()) {
          _gameProvider.onWin();
          widget.onWin();
          return false;
        }
      }
      return _gameProvider.isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _gameProvider,
      child: Scaffold(
        body: Consumer<GameProvider>(
          builder: (context, game, child) {
            if (game.isPaused) return _buildPauseOverlay(game);
            return Stack(
              children: [
                _buildBackground(),
                SafeArea(child: _buildHUD(game)),
                ...game.activeCockroaches.map((c) => Positioned(
                  left: c.position.dx,
                  top: c.position.dy,
                  child: CockroachWidget(
                    key: ValueKey(c.id),
                    data: c,
                    onTap: () => _onTap(c.id, c.position),
                  ),
                )),
              ],
            );
          },
        ),
      ),
    );
  }

  void _onTap(int id, Offset position) {
    _gameProvider.onCockroachTap(id, position);
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF0D0D1A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildHUD(GameProvider game) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _hudItem('⏱️', '${game.timeLeft}s', game.timeLeft <= 10 ? Colors.red : Colors.white),
              _hudItem('💯', '${game.score}', Colors.amber),
              _hudItem('❤️', '${game.lives}', game.lives <= 1 ? Colors.red : Colors.pink),
              _hudItem('🔥', 'x${game.combo.toStringAsFixed(1)}', Colors.orange),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '目標: ${game.score}/${game.levelConfig.targetScore}',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _pauseBtn('⏸️', game.togglePause),
            _pauseBtn('🔄', () => _gameProvider.startGame(widget.level)),
            _pauseBtn('🏠', widget.onMenu),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _hudItem(String emoji, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _pauseBtn(String emoji, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }

  Widget _buildPauseOverlay(GameProvider game) {
    return GestureDetector(
      onTap: game.togglePause,
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏸️', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 24),
              const Text('遊戲暫停', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              _pauseMenuBtn('▶️ 繼續', game.togglePause),
              const SizedBox(height: 16),
              _pauseMenuBtn('🔄 重新開始', () {
                game.togglePause();
                _gameProvider.startGame(widget.level);
              }),
              const SizedBox(height: 16),
              _pauseMenuBtn('🏠 主頁', widget.onMenu),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pauseMenuBtn(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  void dispose() {
    _gameProvider.dispose();
    super.dispose();
  }
}