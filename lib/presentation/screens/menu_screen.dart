import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/game_models.dart';
import '../../game/game_provider.dart';
import 'game_screen.dart';
import 'skill_tree_screen.dart';
import 'td_game_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _tabIndex = 0; // 0=關卡, 1=技能, 2=寵物, 3=成就

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(child: _buildContent()),
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, g, _) {
        final s = g.gameState;
        final xpNext = s.xpForLevel(s.playerLevel);
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.5),
            border: Border(
              bottom: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // 角色頭像
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.glowShadow,
                    ),
                    child: Center(
                      child: Text(protagonist.emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 角色名+標題
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          protagonist.name,
                          style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          protagonist.title,
                          style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 等級
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Lv.${s.playerLevel}',
                      style: const TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 貨幣列
              Row(
                children: [
                  _currencyChip('🪙', '${s.coins}', AppTheme.secondary),
                  const SizedBox(width: 10),
                  _currencyChip('✨', '${s.essence}', AppTheme.accent),
                  const Spacer(),
                  // XP進度
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${s.totalXp} / $xpNext XP',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: xpNext > 0 ? (s.totalXp / xpNext).clamp(0, 1) : 0,
                            backgroundColor: AppTheme.surface,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.success),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _currencyChip(String emoji, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_tabIndex) {
      case 0: return _buildLevelGrid();
      case 1: return const SkillTreeScreen();
      case 2: return const PetScreen();
      case 3: return const AchievementScreen();
      default: return _buildLevelGrid();
    }
  }

  Widget _buildLevelGrid() {
    return Consumer<GameProvider>(
      builder: (context, g, _) {
        return Column(
          children: [
            // 故事banner
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.15),
                    AppTheme.accent.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Text('📖', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '《蟲族逆襲：香港除菌風暴》',
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '林婆婆 ${grandma.emoji} 話：「蒨妤，蟑螂大軍嚟喇！」',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 標題
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Text('🏠 選擇關卡', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  )),
                ],
              ),
            ),
            // 關卡網格
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.15,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: LevelConfig.levels.length,
                itemBuilder: (context, index) {
                  final cfg = LevelConfig.levels[index];
                  final level = index + 1;
                  final stars = g.gameState.levelStars[level] ?? 0;
                  final isUnlocked = level == 1 || g.gameState.completedLevels.contains(level - 1);
                  return _levelCard(cfg, level, stars, isUnlocked, g);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _levelCard(LevelConfig cfg, int level, int stars, bool isUnlocked, GameProvider g) {
    final isCompleted = g.gameState.completedLevels.contains(level);
    return GestureDetector(
      onTap: isUnlocked ? () => _navigateToGame(level) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isUnlocked
              ? [cfg.bgColorTop, cfg.bgColorBottom]
              : [AppTheme.surface, AppTheme.surface.withOpacity(0.5)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCompleted
              ? AppTheme.success.withOpacity(0.6)
              : (isUnlocked ? AppTheme.primary.withOpacity(0.3) : Colors.transparent),
            width: isCompleted ? 2 : 1,
          ),
          boxShadow: isUnlocked ? AppTheme.cardShadow : [],
        ),
        child: Stack(
          children: [
            // 背景emoji
            Positioned(
              right: -8, bottom: -8,
              child: Text(cfg.bgEmoji, style: TextStyle(
                fontSize: 50, color: Colors.white.withOpacity(0.08),
              )),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isUnlocked
                            ? AppTheme.primary.withOpacity(0.9)
                            : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '第$level關',
                          style: TextStyle(
                            color: isUnlocked ? Colors.white : AppTheme.textSecondary,
                            fontWeight: FontWeight.bold, fontSize: 13,
                          ),
                        ),
                      ),
                      if (!isUnlocked)
                        const Icon(Icons.lock, color: AppTheme.textSecondary, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cfg.name,
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      color: isUnlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cfg.theme,
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const Spacer(),
                  // 星級
                  Row(
                    children: List.generate(3, (i) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        i < stars ? Icons.star : Icons.star_border,
                        color: i < stars ? AppTheme.textGold : AppTheme.textSecondary,
                        size: 20,
                      ),
                    )),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('⏱ ${cfg.timeLimit}s', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      Text('💯 ${cfg.targetScore}', style: const TextStyle(fontSize: 11, color: AppTheme.secondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToGame(int level) {
    final g = context.read<GameProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TDGameScreen(level: level, gameProvider: g),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      ('🏠', '關卡'),
      ('🌳', '技能'),
      ('🐾', '寵物'),
      ('🏆', '成就'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.primary.withOpacity(0.15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(4, (i) {
          final selected = _tabIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _tabIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: selected
                  ? Border.all(color: AppTheme.primary.withOpacity(0.4))
                  : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(items[i].$1, style: TextStyle(fontSize: selected ? 26 : 22)),
                  const SizedBox(height: 2),
                  Text(
                    items[i].$2,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? AppTheme.primary : AppTheme.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}