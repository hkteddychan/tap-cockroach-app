import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/game_models.dart';
import '../../core/theme/app_theme.dart';

class MenuScreen extends StatelessWidget {
  final Function(int) onStartGame;

  const MenuScreen({super.key, required this.onStartGame});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF0D0D1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text('🪳', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 16),
              const Text('撳蟲大挑戰', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              const Text('Tap Cockroach', style: TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 40),
              const Text('選擇關卡', style: TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: LevelConfig.levels.length,
                  itemBuilder: (context, index) {
                    final level = index + 1;
                    final config = LevelConfig.levels[index];
                    return _levelCard(context, level, config);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelCard(BuildContext context, int level, LevelConfig config) {
    return GestureDetector(
      onTap: () => onStartGame(level),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF16213E), Color(0xFF0F3460)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$level', style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('⏱ ${config.timeLimit}s', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text('💯 ${config.targetScore}', style: const TextStyle(color: Colors.amber, fontSize: 12)),
            Text('❤️ ${config.lives}', style: const TextStyle(color: Colors.pink, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}