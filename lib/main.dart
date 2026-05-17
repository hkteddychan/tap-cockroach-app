import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/menu_screen.dart';
import 'presentation/screens/game_screen.dart';
import 'presentation/screens/result_screen.dart';

void main() {
  runApp(const TapCockroachApp());
}

class TapCockroachApp extends StatelessWidget {
  const TapCockroachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tap Cockroach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const GameHome(),
    );
  }
}

class GameHome extends StatefulWidget {
  const GameHome({super.key});

  @override
  State<GameHome> createState() => _GameHomeState();
}

class _GameHomeState extends State<GameHome> {
  int _currentScreen = 0;
  int _currentLevel = 1;
  int _lastScore = 0;
  bool _lastResult = false;

  void _startGame(int level) {
    setState(() {
      _currentLevel = level;
      _currentScreen = 1;
    });
  }

  void _onWin() {
    setState(() {
      _lastResult = true;
      _lastScore = _currentLevel * 100;
      if (_currentLevel < 10) {
        _currentScreen = 3;
      } else {
        _currentScreen = 3;
      }
    });
  }

  void _onLose() {
    setState(() {
      _lastResult = false;
      _lastScore = _currentLevel * 50;
      _currentScreen = 3;
    });
  }

  void _onMenu() {
    setState(() => _currentScreen = 0);
  }

  void _onRetry() {
    if (_lastResult && _currentLevel < 10) {
      _currentLevel++;
    }
    _currentScreen = 1;
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _currentScreen,
      children: [
        MenuScreen(onStartGame: _startGame),
        GameScreen(
          level: _currentLevel,
          onMenu: _onMenu,
          onWin: _onWin,
          onLose: _onLose,
        ),
        ResultScreen(
          isWin: _lastResult,
          score: _lastScore,
          level: _currentLevel,
          onRetry: _onRetry,
          onMenu: _onMenu,
        ),
      ],
    );
  }
}