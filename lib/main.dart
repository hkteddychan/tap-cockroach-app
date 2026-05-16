import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'data/models/game_models.dart';
import 'game/game_provider.dart';
import 'presentation/screens/menu_screen.dart';
import 'presentation/screens/game_screen.dart';
import 'presentation/screens/result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  
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
  final GameProvider _gameProvider = GameProvider();
  
  late int _highScore;
  late int _unlockedLevel;
  int _totalScore = 0;
  int _totalKills = 0;
  int _maxCombo = 0;

  // Screens
  static const int _screenMenu = 0;
  static const int _screenLevelSelect = 1;
  static const int _screenGame = 2;
  static const int _screenResult = 3;
  
  int _currentScreen = _screenMenu;
  bool _isWin = false;
  bool _isGameOver = false;
  int _lastScore = 0;
  int _lastHearts = 3;

  @override
  void initState() {
    super.initState();
    _highScore = 0;
    _unlockedLevel = 1;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _highScore = prefs.getInt('highScore') ?? 0;
        _unlockedLevel = prefs.getInt('unlockedLevel') ?? 1;
        _totalScore = prefs.getInt('totalScore') ?? 0;
        _totalKills = prefs.getInt('totalKills') ?? 0;
        _maxCombo = prefs.getInt('maxCombo') ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('highScore', _highScore);
      await prefs.setInt('unlockedLevel', _unlockedLevel);
      await prefs.setInt('totalScore', _totalScore);
      await prefs.setInt('totalKills', _totalKills);
      await prefs.setInt('maxCombo', _maxCombo);
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
  }

  void _onLevelComplete() {
    final score = _gameProvider.currentScore;
    final hearts = _gameProvider.stats.hearts;
    
    _lastScore = score;
    _lastHearts = hearts;
    _isWin = true;
    _isGameOver = false;
    
    if (score > _highScore) _highScore = score;
    if (_gameProvider.currentLevelIndex + 1 >= _unlockedLevel && _unlockedLevel < 10) {
      _unlockedLevel = _gameProvider.currentLevelIndex + 2;
    }
    _totalScore += score;
    _totalKills += _gameProvider.stats.cockroachesKilled;
    if (_gameProvider.stats.maxCombo > _maxCombo) _maxCombo = _gameProvider.stats.maxCombo;
    
    _saveData();
    setState(() => _currentScreen = _screenResult);
  }

  void _onGameOver(String reason) {
    _lastScore = _gameProvider.currentScore;
    _lastHearts = _gameProvider.stats.hearts;
    _isWin = false;
    _isGameOver = true;
    
    if (_lastScore > _highScore) _highScore = _lastScore;
    _totalScore += _lastScore;
    _totalKills += _gameProvider.stats.cockroachesKilled;
    if (_gameProvider.stats.maxCombo > _maxCombo) _maxCombo = _gameProvider.stats.maxCombo;
    
    _saveData();
    setState(() => _currentScreen = _screenResult);
  }

  void _startLevel(int level) {
    _gameProvider.startGame(level);
    setState(() => _currentScreen = _screenGame);
  }

  void _retry() {
    setState(() => _currentScreen = _screenMenu);
    _startLevel(_gameProvider.currentLevelIndex + 1);
  }

  void _nextLevel() {
    if (_gameProvider.currentLevelIndex < 9) {
      _startLevel(_gameProvider.currentLevelIndex + 2);
    } else {
      setState(() => _currentScreen = _screenMenu);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_currentScreen == _screenGame) {
            _gameProvider.pauseGame();
          }
          setState(() => _currentScreen = _screenMenu);
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildScreen(),
      ),
    );
  }

  Widget _buildScreen() {
    switch (_currentScreen) {
      case _screenMenu:
        return MenuScreen(
          key: const ValueKey('menu'),
          onStartGame: () => _startLevel(_unlockedLevel),
          onLevelSelect: () => setState(() => _currentScreen = _screenLevelSelect),
          highScore: _highScore,
          unlockedLevel: _unlockedLevel,
        );
      
      case _screenLevelSelect:
        return LevelSelectScreen(
          key: const ValueKey('levels'),
          unlockedLevel: _unlockedLevel,
          onSelectLevel: _startLevel,
          onBack: () => setState(() => _currentScreen = _screenMenu),
        );
      
      case _screenGame:
        return GameScreen(
          key: ValueKey('game_${_gameProvider.currentLevelIndex}'),
          level: _gameProvider.currentLevelIndex + 1,
          gameProvider: _gameProvider,
          onBack: () {
            _gameProvider.pauseGame();
            setState(() => _currentScreen = _screenMenu);
          },
          onLevelComplete: _onLevelComplete,
          onGameOver: (reason) => _onGameOver(reason),
        );
      
      case _screenResult:
        return ResultScreen(
          key: const ValueKey('result'),
          score: _lastScore,
          hearts: _lastHearts,
          level: _gameProvider.currentLevelIndex + 1,
          isWin: _isWin,
          isGameOver: _isGameOver,
          highScore: _highScore,
          onRetry: _retry,
          onNextLevel: _nextLevel,
          onMenu: () => setState(() => _currentScreen = _screenMenu),
        );
      
      default:
        return const SizedBox();
    }
  }
}