import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final bool isWin;
  final int score;
  final int level;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  const ResultScreen({super.key, required this.isWin, required this.score, required this.level, required this.onRetry, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isWin ? [const Color(0xFF1A1A2E), const Color(0xFF0D3B1E)] : [const Color(0xFF1A1A2E), const Color(0xFF3B1A1A)],
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
                const SizedBox(height: 24),
                Text(
                  isWin ? '關卡 $level 完成！' : '遊戲結束',
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '最終得分: $score',
                    style: const TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 48),
                _buildBtn(isWin ? '下一關' : '再試一次', isWin ? Color(0xFF4ADE80) : Color(0xFFFF6B35), onRetry),
                const SizedBox(height: 16),
                _buildBtn('🏠 主頁', const Color(0xFF0F3460), onMenu),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBtn(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)],
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }
}