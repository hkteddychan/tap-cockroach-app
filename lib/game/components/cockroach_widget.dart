import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../data/models/game_models.dart';

class CockroachWidget extends StatefulWidget {
  final CockroachData data;
  final VoidCallback onTap;
  final VoidCallback onEscape;

  const CockroachWidget({
    super.key,
    required this.data,
    required this.onTap,
    required this.onEscape,
  });

  @override
  State<CockroachWidget> createState() => _CockroachWidgetState();
}

class _CockroachWidgetState extends State<CockroachWidget>
    with TickerProviderStateMixin {
  late AnimationController _legController;
  late AnimationController _antennaController;
  late AnimationController _wobbleController;
  late AnimationController _squishController;
  bool _isSquishing = false;

  @override
  void initState() {
    super.initState();
    _legController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
    
    _antennaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);
    
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..repeat(reverse: true);
    
    _squishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onTap();
      }
    });
  }

  @override
  void dispose() {
    _legController.dispose();
    _antennaController.dispose();
    _wobbleController.dispose();
    _squishController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_isSquishing) return;
    setState(() => _isSquishing = true);
    _squishController.forward();
  }

  Color get _bodyColor {
    switch (widget.data.config.type) {
      case CockroachType.gold:
        return const Color(0xFFFFD700);
      case CockroachType.giant:
        return const Color(0xFF5C4033);
      case CockroachType.fast:
        return const Color(0xFF2D1F14);
      default:
        return const Color(0xFF3D2817);
    }
  }

  double get _size {
    switch (widget.data.config.type) {
      case CockroachType.giant:
        return 80;
      default:
        return 60;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isSlowed = widget.data.isSlowed &&
        (widget.data.slowEndTime == null || widget.data.slowEndTime!.isAfter(now));

    return Positioned(
      left: widget.data.position.dx,
      top: widget.data.position.dy,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _legController,
            _antennaController,
            _wobbleController,
            _squishController,
          ]),
          builder: (context, child) {
            final squish = _squishController.value;
            return Transform.scale(
              scale: _isSquishing ? (1 + squish * 0.3) * (1 - squish * 0.5) : 1.0,
              opacity: _isSquishing ? 1 - squish : 1.0,
              child: Transform.translate(
                offset: Offset(0, squish * 20),
                child: SizedBox(
                  width: _size,
                  height: _size,
                  child: Stack(
                    children: [
                      // Shadow
                      Positioned(
                        bottom: 0,
                        left: 5,
                        child: Container(
                          width: _size * 0.7,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                      // Cockroach body
                      Transform.scale(
                        scaleX: widget.data.facingRight ? 1 : -1,
                        child: CustomPaint(
                          size: Size(_size, _size),
                          painter: _CockroachPainter(
                            bodyColor: _bodyColor,
                            legPhase: _legController.value,
                            antennaPhase: _antennaController.value,
                            wobblePhase: _wobbleController.value,
                            isSlowed: isSlowed,
                            isGold: widget.data.config.type == CockroachType.gold,
                          ),
                        ),
                      ),
                      // Slow effect glow
                      if (isSlowed)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyan.withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CockroachPainter extends CustomPainter {
  final Color bodyColor;
  final double legPhase;
  final double antennaPhase;
  final double wobblePhase;
  final bool isSlowed;
  final bool isGold;

  _CockroachPainter({
    required this.bodyColor,
    required this.legPhase,
    required this.antennaPhase,
    required this.wobblePhase,
    required this.isSlowed,
    required this.isGold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    
    // Body wobble
    final wobbleOffset = math.sin(wobblePhase * math.pi * 2) * 1.5;
    
    // Legs
    final legPaint = Paint()
      ..color = bodyColor.withOpacity(0.8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    for (int i = 0; i < 3; i++) {
      final legAngle = (i - 1) * 0.4 + math.pi / 2;
      final legLen = 12 + (i == 1 ? 4 : 0);
      final legMove = math.sin((legPhase + i * 0.33) * math.pi * 2) * 3;
      
      // Top legs
      canvas.drawLine(
        Offset(cx + math.cos(legAngle) * 10, cy - 5 + wobbleOffset),
        Offset(cx + math.cos(legAngle) * (legLen + legMove) + 5, 
               cy - 5 + math.sin(legAngle) * legLen - 5),
        legPaint,
      );
      // Bottom legs
      canvas.drawLine(
        Offset(cx + math.cos(math.pi - legAngle) * 10, cy + 5 + wobbleOffset),
        Offset(cx + math.cos(math.pi - legAngle) * (legLen - legMove) + 5, 
               cy + 5 + math.sin(math.pi - legAngle) * legLen + 5),
        legPaint,
      );
    }
    
    // Body
    final bodyPaint = Paint()..color = bodyColor;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy + wobbleOffset),
        width: isSlowed ? 35 : 30,
        height: isSlowed ? 40 : 35,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, bodyPaint);
    
    // Head
    final headPaint = Paint()..color = bodyColor;
    canvas.drawCircle(Offset(cx, cy - 18 + wobbleOffset), 10, headPaint);
    
    // Eyes
    final eyePaint = Paint()..color = Colors.red;
    canvas.drawCircle(Offset(cx - 4, cy - 20 + wobbleOffset), 3, eyePaint);
    canvas.drawCircle(Offset(cx + 4, cy - 20 + wobbleOffset), 3, eyePaint);
    
    // Antennae
    final antennaPaint = Paint()
      ..color = bodyColor.withOpacity(0.9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final antWobble = math.sin(antennaPhase * math.pi * 2) * 3;
    
    // Left antenna
    final leftAntPath = Path()
      ..moveTo(cx - 5, cy - 26 + wobbleOffset)
      ..quadraticBezierTo(
        cx - 15 + antWobble, cy - 40,
        cx - 12 + antWobble, cy - 45,
      );
    canvas.drawPath(leftAntPath, antennaPaint);
    
    // Right antenna
    final rightAntPath = Path()
      ..moveTo(cx + 5, cy - 26 + wobbleOffset)
      ..quadraticBezierTo(
        cx + 15 - antWobble, cy - 40,
        cx + 12 - antWobble, cy - 45,
      );
    canvas.drawPath(rightAntPath, antennaPaint);
    
    // Gold sparkle effect
    if (isGold) {
      final sparklePaint = Paint()
        ..color = Colors.white.withOpacity(0.5 + math.sin(legPhase * math.pi * 4) * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(cx, cy + wobbleOffset), 20 + legPhase * 5, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CockroachPainter oldDelegate) =>
      oldDelegate.legPhase != legPhase ||
      oldDelegate.antennaPhase != antennaPhase ||
      oldDelegate.wobblePhase != wobblePhase ||
      oldDelegate.isSlowed != isSlowed;
}