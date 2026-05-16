import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/game_models.dart';
import '../../game/game_provider.dart';
import '../../game/components/cockroach_widget.dart';

class GameScreen extends StatefulWidget {
  final int level;
  final GameProvider gameProvider;
  final VoidCallback onBack;
  final VoidCallback onLevelComplete;
  final VoidCallback onGameOver;

  const GameScreen({
    super.key,
    required this.level,
    required this.gameProvider,
    required this.onBack,
    required this.onLevelComplete,
    required this.onGameOver,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final List<_ScorePopup> _scorePopups = [];
  int _displayScore = 0;
  int _displayCombo = 0;
  bool _showCombo = false;

  @override
  void initState() {
    super.initState();
    widget.gameProvider.onScorePopup = _showScorePopup;
    widget.gameProvider.onComboPopup = _showComboPopup;
    widget.gameProvider.onLevelComplete = widget.onLevelComplete;
    widget.gameProvider.onGameOver = widget.onGameOver;
    widget.gameProvider.startGame(widget.level);
    
    // Score animation
    _animateScore();
  }

  void _animateScore() {
    Future.delayed(const Duration(milliseconds: 16), () {
      if (!mounted) return;
      if (_displayScore < widget.gameProvider.currentScore) {
        setState(() {
          _displayScore += ((widget.gameProvider.currentScore - _displayScore) * 0.2).ceil().clamp(1, 100);
        });
      }
      _animateScore();
    });
  }

  void _showScorePopup(int score, int combo, Offset position) {
    setState(() {
      _scorePopups.add(_ScorePopup(
        score: score,
        combo: combo,
        position: position,
        key: UniqueKey(),
      ));
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _scorePopups.removeWhere((p) => p.key == _scorePopups.first.key);
        });
      }
    });
  }

  void _showComboPopup(int combo) {
    setState(() {
      _displayCombo = combo;
      _showCombo = true;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showCombo = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Stack(
            children: [
              // Game area
              _buildGameArea(),
              // HUD
              _buildHUD(),
              // Score popups
              ..._scorePopups,
              // Combo popup
              if (_showCombo) _buildComboPopup(),
              // Pause button
              _buildPauseButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    return ListenableBuilder(
      listenable: widget.gameProvider,
      builder: (context, _) {
        // Update cockroach positions
        widget.gameProvider.updateCockroaches();
        
        return Stack(
          children: [
            // Background grid
            CustomPaint(
              size: Size.infinite,
              painter: _GridPainter(),
            ),
            // Cockroaches
            ...widget.gameProvider.activeCockroaches.map((data) => CockroachWidget(
              key: ValueKey(data.id),
              data: data,
              onTap: () => widget.gameProvider.onCockroachTap(data.id, data.position),
              onEscape: () => widget.gameProvider.onCockroachEscape(data.id),
            )),
          ],
        );
      },
    );
  }

  Widget _buildHUD() {
    final level = widget.gameProvider.currentLevel;
    final timePercent = widget.gameProvider.timeLeft / level.timeSeconds;
    
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Level
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '第${widget.gameProvider.currentLevelIndex + 1}關',
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '$_displayScore',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                // Hearts
                Row(
                  children: List.generate(3, (i) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      i < widget.gameProvider.stats.hearts ? '❤️' : '🖤',
                      style: const TextStyle(fontSize: 24),
                    ),
                  )),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Timer bar
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  height: 6,
                  width: MediaQuery.of(context).size.width * timePercent * 0.9,
                  decoration: BoxDecoration(
                    gradient: timePercent > 0.3
                        ? AppTheme.primaryGradient
                        : const LinearGradient(
                            colors: [Colors.red, Colors.orange],
                          ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress
            Text(
              '${widget.gameProvider.stats.cockroachesKilled} / ${level.cockroachCount}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComboPopup() {
    return Center(
      child: Text(
        'x$_displayCombo COMBO!',
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w900,
          color: AppTheme.secondary,
          shadows: [
            Shadow(color: AppTheme.secondary, blurRadius: 20),
            Shadow(color: AppTheme.primary, blurRadius: 40),
          ],
        ),
      ).animate().scale(
        begin: const Offset(0.5, 0.5),
        end: const Offset(1.2, 1.2),
        duration: 200.ms,
      ).then().scale(
        begin: const Offset(1.2, 1.2),
        end: const Offset(1, 1),
        duration: 100.ms,
      ).then().fadeOut(delay: 400.ms, duration: 200.ms),
    );
  }

  Widget _buildPauseButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      right: 16,
      child: IconButton(
        onPressed: () {
          widget.gameProvider.pauseGame();
          _showPauseDialog();
        },
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.pause, color: Colors.white),
        ),
      ),
    );
  }

  void _showPauseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⏸️ 暫停', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPauseButton('▶️ 繼續', () {
              Navigator.pop(context);
              widget.gameProvider.resumeGame();
            }),
            const SizedBox(height: 12),
            _buildPauseButton('🔄 重新開始', () {
              Navigator.pop(context);
              widget.gameProvider.startGame(widget.level);
            }),
            const SizedBox(height: 12),
            _buildPauseButton('🏠 主頁', () {
              Navigator.pop(context);
              widget.onBack();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.surfaceLight,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(text),
      ),
    );
  }
}

class _ScorePopup {
  final int score;
  final int combo;
  final Offset position;
  final Key key;

  _ScorePopup({
    required this.score,
    required this.combo,
    required this.position,
    required this.key,
  });
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
