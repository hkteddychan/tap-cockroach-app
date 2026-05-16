import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class MenuScreen extends StatelessWidget {
  final VoidCallback onStartGame;
  final VoidCallback onLevelSelect;
  final int highScore;
  final int unlockedLevel;

  const MenuScreen({
    super.key,
    required this.onStartGame,
    required this.onLevelSelect,
    required this.highScore,
    required this.unlockedLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              _buildLogo(),
              const SizedBox(height: 40),
              if (highScore > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        '最高分: $highScore',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 40),
              _buildButton('🎮 開始遊戲', AppTheme.primaryGradient, onStartGame),
              const SizedBox(height: 16),
              _buildButton('📋 選擇關卡', AppTheme.cardGradient, onLevelSelect),
              const Spacer(),
              Text(
                '撳死所有蟲蟲！',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
            boxShadow: AppTheme.glowShadow,
          ),
          child: const Center(
            child: Text('🪳', style: TextStyle(fontSize: 60)),
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            'TAP',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 8,
            ),
          ),
        ),
        const Text(
          'COCKROACH',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '撳蟲大挑戰',
          style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildButton(String text, LinearGradient gradient, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      height: 60,
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LevelSelectScreen extends StatelessWidget {
  final int unlockedLevel;
  final Function(int) onSelectLevel;
  final VoidCallback onBack;

  const LevelSelectScreen({
    super.key,
    required this.unlockedLevel,
    required this.onSelectLevel,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      '選擇關卡',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    final level = index + 1;
                    final isUnlocked = level <= unlockedLevel;
                    final isCompleted = level < unlockedLevel;
                    final isCurrent = level == unlockedLevel;

                    return _LevelButton(
                      level: level,
                      isUnlocked: isUnlocked,
                      isCompleted: isCompleted,
                      isCurrent: isCurrent,
                      onTap: isUnlocked ? () => onSelectLevel(level) : null,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelButton extends StatelessWidget {
  final int level;
  final bool isUnlocked;
  final bool isCompleted;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _LevelButton({
    required this.level,
    required this.isUnlocked,
    required this.isCompleted,
    required this.isCurrent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: isCompleted
              ? AppTheme.primaryGradient
              : isCurrent
                  ? AppTheme.goldGradient
                  : AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent ? AppTheme.secondary : Colors.transparent,
            width: 3,
          ),
          boxShadow: isCurrent ? AppTheme.glowShadow : null,
        ),
        child: Center(
          child: isUnlocked
              ? Text(
                  '$level',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isCompleted || isCurrent ? Colors.white : AppTheme.textSecondary,
                  ),
                )
              : const Icon(Icons.lock, color: AppTheme.textSecondary, size: 24),
        ),
      ),
    );
  }
}