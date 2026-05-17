import 'package:flutter/material.dart';
import '../../data/models/game_models.dart';

class CockroachWidget extends StatefulWidget {
  final CockroachData data;
  final VoidCallback onTap;

  const CockroachWidget({super.key, required this.data, required this.onTap});

  @override
  State<CockroachWidget> createState() => _CockroachWidgetState();
}

class _CockroachWidgetState extends State<CockroachWidget>
    with TickerProviderStateMixin {
  late AnimationController _walkController;
  late AnimationController _squishController;
  late Animation<double> _walkAnimation;
  bool _isSquishing = false;

  @override
  void initState() {
    super.initState();
    _walkController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (300 / widget.data.speed * 2).round().clamp(100, 600)),
    )..repeat(reverse: true);

    _walkAnimation = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(parent: _walkController, curve: Curves.easeInOut),
    );

    _squishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _walkController.dispose();
    _squishController.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.data.type) {
      case CockroachType.fast:   return Colors.green.shade700;
      case CockroachType.giant:  return Colors.deepOrange.shade800;
      case CockroachType.golden: return Colors.amber.shade600;
      default:                   return Colors.brown.shade600;
    }
  }

  double get _size {
    switch (widget.data.type) {
      case CockroachType.giant:  return 80;
      case CockroachType.golden: return 52;
      default:                   return 46;
    }
  }

  String get _emoji {
    switch (widget.data.type) {
      case CockroachType.fast:   return '🏃';
      case CockroachType.giant:  return '🦗';
      case CockroachType.golden: return '⭐';
      default:                   return '🪳';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _isSquishing = true);
        _squishController.forward().then((_) => widget.onTap());
      },
      child: ListenableBuilder(
        animation: Listenable.merge([_walkAnimation, _squishController]),
        builder: (context, child) {
          final squish = _squishController.value;
          final scale = 1.0 - (squish * 0.3);
          final rotation = _walkAnimation.value * 0.06;
          return Transform.translate(
            offset: Offset(_walkAnimation.value, _walkAnimation.value * 0.3),
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: _isSquishing ? (1 - squish).clamp(0.3, 1.0) : 1.0,
                  child: Container(
                    width: _size,
                    height: _size,
                    decoration: BoxDecoration(
                      color: _color.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(_size / 4),
                      boxShadow: [
                        BoxShadow(
                          color: _color.withOpacity(0.6),
                          blurRadius: 12,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(child: Text(_emoji, style: TextStyle(fontSize: _size * 0.5))),
                        if (widget.data.type == CockroachType.golden)
                          Positioned(
                            top: 2, right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.star, color: Colors.white, size: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}