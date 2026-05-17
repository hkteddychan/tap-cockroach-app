import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/game_models.dart';
import '../../game/game_provider.dart';

class AchievementScreen extends StatelessWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, g, _) {
        final earned = g.gameState.achievements;
        final totalAch = allAchievements.length;
        final earnedCount = earned.length;
        final pct = totalAch > 0 ? earnedCount / totalAch : 0.0;

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.textGold.withOpacity(0.15),
                    AppTheme.primary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.textGold.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '成就 $earnedCount / $totalAch',
                          style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold,
                            color: AppTheme.textGold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: AppTheme.surface,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.textGold),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: allAchievements.length,
                itemBuilder: (context, index) {
                  final ach = allAchievements[index];
                  final unlocked = earned.contains(ach.id);
                  return _achCard(ach, unlocked);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _achCard(AchievementConfig ach, bool unlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: unlocked
            ? LinearGradient(colors: [AppTheme.surface, AppTheme.surfaceLight])
            : null,
        color: unlocked ? null : AppTheme.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked
              ? AppTheme.textGold.withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: unlocked ? AppTheme.textGold.withOpacity(0.2) : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(unlocked ? ach.emoji : '🔒', style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ach.name,
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold,
                    color: unlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ach.description,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                if (unlocked)
                  const Text(
                    '✓ 已達成',
                    style: TextStyle(fontSize: 11, color: AppTheme.success),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}