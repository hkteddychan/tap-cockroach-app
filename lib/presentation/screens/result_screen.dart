import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';

class ResultScreen extends StatelessWidget {
  final int score;
  final int hearts;
  final int level;
  final bool isWin;
  final bool isGameOver;
  final int highScore;
  final VoidCallback onRetry;
  final VoidCallback onNextLevel;
  final VoidCallback onMenu;

  const ResultScreen({
    super.key,
    required this.score,
    required this.hearts,
    required this.level,
    required this.isWin,
    required this.isGameOver,
    required this.highScore,
    required this.onRetry,
    required this.onNextLevel,
    required this.onMenu,
  });

  int get _stars => hearts >= 2 ? (hearts >= 3 ? 3 : 2) : 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                _buildTitle(),
                const SizedBox(height: 30),
                // Stars
                if (isWin) _buildStars(),
                const SizedBox(height: 30),
                // Score card
                _buildScoreCard(),
                const SizedBox(height: 40),
                // Buttons
                if (!isGameOver) ...[
                  _buildButton('▶️ 下一關', AppTheme.primaryGradient, onNextLevel),
                  const SizedBox(height: 12),
                ],
                if (isGameOver || isWin) ...[
                  _buildButton('🔄 再試', AppTheme.cardGradient, onRetry),
                  const SizedBox(height: 12),
                ],
                _buildButton('🏠 主頁', AppTheme.surfaceLight, onMenu),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    String title;
    String emoji;
    Color color;

    if (isGameOver) {
      title = 'GAME OVER';
      emoji = '💀';
      color = AppTheme.error;
    } else if (isWin) {
      title = level >= 10 ? '🎊 全部完成！' : '🎉 關卡完成！';
      emoji = level >= 10 ? '🏆' : '⭐';
      color = AppTheme.secondary;
    }

    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 60))
            .animate()
            .scale(duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [color, color.withOpacity(0.7)],
          ).createShader(bounds),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.3),
      ],
    );
  }

  Widget _buildStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isEarned = i < _stars;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            isEarned ? '⭐' : '☆',
            style: TextStyle(
              fontSize: 48,
              color: isEarned ? null : Colors.white.withOpacity(0.3),
            ),
          ).animate(delay: (i * 200).ms)
            .scale(begin: const Offset(0, 0), duration: 400.ms, curve: Curves.elasticOut),
        );
      }),
    );
  }

  Widget _buildScoreCard() {
    final isNewHighScore = score >= highScore && score > 0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: isNewHighScore
            ? Border.all(color: AppTheme.secondary, width: 2)
            : null,
      ),
      child: Column(
        children: [
          if (isNewHighScore) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '🎯 新紀錄！',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ).animate().scale(),
            const SizedBox(height: 16),
          ],
          _buildStatRow('分數', '$score', AppTheme.secondary),
          const SizedBox(height: 12),
          _buildStatRow('生命', '$hearts / 3', hearts >= 2 ? AppTheme.success : AppTheme.error),
          if (!isGameOver) ...[
            const SizedBox(height: 12),
            _buildStatRow('關卡', '第$level關', AppTheme.primary),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String text, Gradient gradient, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.2);
  }
}