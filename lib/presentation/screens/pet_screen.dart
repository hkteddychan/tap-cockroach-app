import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/game_models.dart';
import '../../game/game_provider.dart';

class PetScreen extends StatelessWidget {
  const PetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, g, _) {
        final pets = g.gameState.unlockedPets;
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accent.withOpacity(0.15),
                    AppTheme.primary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Text('🐾', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '我的寵物',
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold,
                            color: AppTheme.accent,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '寵物可以自動幫你消滅蟑螂',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                itemCount: allPets.length,
                itemBuilder: (context, index) {
                  final pet = allPets[index];
                  final unlocked = pets.contains(pet.id);
                  return _petCard(pet, unlocked, g);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _petCard(PetConfig pet, bool unlocked, GameProvider g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: unlocked
            ? LinearGradient(colors: [AppTheme.surface, AppTheme.surfaceLight])
            : null,
        color: unlocked ? null : AppTheme.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? AppTheme.accent.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: unlocked ? AppTheme.accent.withOpacity(0.2) : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(pet.emoji, style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: unlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unlocked ? pet.description : '🔒 尚未解鎖',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                if (unlocked) ...[
                  const SizedBox(height: 4),
                  Text(
                    '技能：${pet.skillDesc}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.accent),
                  ),
                ],
              ],
            ),
          ),
          if (unlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('已擁有', style: TextStyle(
                color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.bold,
              )),
            ),
        ],
      ),
    );
  }
}