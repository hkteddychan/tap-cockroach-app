import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/game_models.dart';
import '../../game/game_provider.dart';

class SkillTreeScreen extends StatelessWidget {
  const SkillTreeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, g, _) {
        final s = g.gameState;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Text('🌳 技能樹', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  )),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          '${s.essence}',
                          style: const TextStyle(
                            color: AppTheme.accent, fontWeight: FontWeight.bold,
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: skills.length,
                itemBuilder: (context, index) {
                  final skill = skills[index];
                  final currentLevel = s.skillLevels[index] ?? 0;
                  return _skillCard(context, g, skill, index, currentLevel);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _skillCard(BuildContext context, GameProvider g, Skill skill, int index, int currentLevel) {
    final canUpgrade = currentLevel < 3;
    final cost = canUpgrade ? skill.essenceCosts[currentLevel] : -1;
    final canAfford = canUpgrade && g.gameState.essence >= cost;

    // 分支標籤
    final branchLabels = ['⚡ 速度分支', '🛡️ 防禦分支', '🔥 狂暴分支'];
    final branchIndex = index < 2 ? 0 : (index < 4 ? 1 : 2);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: currentLevel > 0
            ? AppTheme.primary.withOpacity(0.4)
            : AppTheme.surfaceLight,
        ),
        boxShadow: currentLevel > 0 ? [
          BoxShadow(color: AppTheme.primary.withOpacity(0.1), blurRadius: 12),
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  gradient: currentLevel > 0
                    ? AppTheme.orangeGradient
                    : null,
                  color: currentLevel == 0 ? AppTheme.surfaceLight : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(skill.emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      skill.description,
                      style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(branchLabels[branchIndex], style: const TextStyle(
                fontSize: 10, color: AppTheme.textSecondary,
              )),
            ],
          ),
          const SizedBox(height: 14),
          // 等級指示器
          Row(
            children: List.generate(3, (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                height: 8,
                decoration: BoxDecoration(
                  color: i < currentLevel
                    ? AppTheme.primary
                    : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )),
          ),
          const SizedBox(height: 14),
          // 效果列表
          ...List.generate(3, (i) {
            final isActive = i < currentLevel;
            final isNext = i == currentLevel && currentLevel < 3;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    isActive ? Icons.check_circle
                      : (isNext ? Icons.radio_button_unchecked : Icons.circle_outlined),
                    size: 16,
                    color: isActive
                      ? AppTheme.success
                      : (isNext ? AppTheme.textSecondary : AppTheme.surfaceLight),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Lv.${i + 1}: ${skill.effects[i]}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive
                        ? AppTheme.textPrimary
                        : (isNext ? AppTheme.textSecondary : AppTheme.surfaceLight),
                      fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  if (isNext) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: canAfford
                          ? AppTheme.accent.withOpacity(0.2)
                          : AppTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: canAfford
                            ? AppTheme.accent.withOpacity(0.4)
                            : AppTheme.error.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '✨ $cost',
                        style: TextStyle(
                          fontSize: 12,
                          color: canAfford ? AppTheme.accent : AppTheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          if (currentLevel < 3) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canAfford
                  ? () => _doUpgrade(context, g, index, cost)
                  : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAfford ? AppTheme.primary : AppTheme.surfaceLight,
                  foregroundColor: canAfford ? Colors.white : AppTheme.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  canAfford ? '升級 (✨ $cost)' : '精華不足 (需要 ✨ $cost)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              ),
              child: const Center(
                child: Text(
                  '✅ 已滿級',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _doUpgrade(BuildContext context, GameProvider g, int index, int cost) {
    final ok = g.upgradeSkill(index);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ 精華不足，無法升級'),
          backgroundColor: AppTheme.error,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${skills[index].name} 升級成功！'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }
}

// ─── 寵物畫面 ───
class PetScreen extends StatelessWidget {
  const PetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, g, _) {
        final pets = g.currentPets;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Text('🐾 寵物收集', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  )),
                  const Spacer(),
                  Text(
                    '${pets.where((p) => p.unlocked).length} / ${pets.length}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: pets.length,
                itemBuilder: (context, index) {
                  final pet = pets[index];
                  return _petCard(pet);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _petCard(Pet pet) {
    final rarityColor = {
      '普通': AppTheme.textSecondary,
      '稀有': AppTheme.primary,
      '史詩': AppTheme.accent,
    }[pet.rarity] ?? AppTheme.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: pet.unlocked
          ? Border.all(color: rarityColor.withOpacity(0.4))
          : null,
      ),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: pet.unlocked
                ? rarityColor.withOpacity(0.15)
                : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: pet.unlocked ? rarityColor.withOpacity(0.3) : AppTheme.surfaceLight,
              ),
            ),
            child: Center(
              child: Text(
                pet.unlocked ? pet.emoji : '❓',
                style: TextStyle(
                  fontSize: 32,
                  color: pet.unlocked ? null : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      pet.name,
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: pet.unlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: rarityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        pet.rarity,
                        style: TextStyle(fontSize: 11, color: rarityColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  pet.unlocked
                    ? '關卡 ${pet.unlockLevel} 解鎖'
                    : '在關卡 ${pet.unlockLevel} 完成後解鎖',
                  style: TextStyle(
                    fontSize: 12,
                    color: pet.unlocked ? AppTheme.textSecondary : AppTheme.textSecondary.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pet.bonus,
                    style: const TextStyle(
                      fontSize: 13, color: AppTheme.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (pet.unlocked)
            const Icon(Icons.check_circle, color: AppTheme.success, size: 28),
        ],
      ),
    );
  }
}

// ─── 成就畫面 ───
class AchievementScreen extends StatelessWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, g, _) {
        final achievements = g.achievementsWithStatus;
        final unlocked = achievements.where((a) => g.isAchievementUnlocked(a.id)).length;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Text('🏆 成就', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  )),
                  const Spacer(),
                  Text(
                    '$unlocked / ${achievements.length}',
                    style: const TextStyle(
                      color: AppTheme.textGold, fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: achievements.length,
                itemBuilder: (context, index) {
                  final ach = achievements[index];
                  final isUnlocked = g.isAchievementUnlocked(ach.id);
                  return _achievementCard(ach, isUnlocked);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _achievementCard(Achievement ach, bool isUnlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnlocked
          ? AppTheme.textGold.withOpacity(0.08)
          : AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: isUnlocked
          ? Border.all(color: AppTheme.textGold.withOpacity(0.3))
          : Border.all(color: AppTheme.surfaceLight),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: isUnlocked
                ? AppTheme.textGold.withOpacity(0.2)
                : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                isUnlocked ? ach.emoji : '🔒',
                style: TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ach.name,
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: isUnlocked ? AppTheme.textGold : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ach.condition,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                if ((ach.essenceReward > 0 || ach.coinReward > 0))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (ach.essenceReward > 0)
                          _rewardChip('✨ ${ach.essenceReward}'),
                        if (ach.coinReward > 0)
                          _rewardChip('🪙 ${ach.coinReward}'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (isUnlocked)
            const Icon(Icons.star, color: AppTheme.textGold, size: 24),
        ],
      ),
    );
  }

  Widget _rewardChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
    );
  }
}