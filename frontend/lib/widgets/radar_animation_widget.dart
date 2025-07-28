import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Widget personalizado para mostrar la animación del radar
class RadarAnimationWidget extends StatefulWidget {
  final bool isActive;
  final double size;
  final Color color;
  final Duration duration;

  const RadarAnimationWidget({
    super.key,
    required this.isActive,
    this.size = 300.0,
    this.color = Colors.red,
    this.duration = const Duration(milliseconds: 1000), // Sincronizar con los intervalos del mapa
  });

  @override
  State<RadarAnimationWidget> createState() => _RadarAnimationWidgetState();
}

class _RadarAnimationWidgetState extends State<RadarAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _radiusAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _radiusAnimation = Tween<double>(
      begin: 0.0,
      end: widget.size / 2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    if (widget.isActive) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _animationController.repeat();
  }

  @override
  void didUpdateWidget(RadarAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startAnimation();
    } else if (!widget.isActive && oldWidget.isActive) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: RadarPainter(
            radius: _radiusAnimation.value,
            opacity: _opacityAnimation.value,
            color: widget.color,
            sweepAngle: _animationController.value * 2 * math.pi,
          ),
          size: Size(widget.size, widget.size),
        );
      },
    );
  }
}

/// Painter personalizado para dibujar los círculos del radar
class RadarPainter extends CustomPainter {
  final double radius;
  final double opacity;
  final Color color;
  final double sweepAngle;

  RadarPainter({
    required this.radius,
    required this.opacity,
    required this.color,
    required this.sweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Dibujar múltiples círculos concéntricos
    for (int i = 1; i <= 3; i++) {
      final currentRadius = radius * (i / 3);
      canvas.drawCircle(center, currentRadius, paint);
    }

    // Dibujar línea de barrido del radar
    final sweepPaint = Paint()
      ..color = color.withOpacity(opacity * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final lineEnd = Offset(
      center.dx + radius * math.cos(sweepAngle),
      center.dy + radius * math.sin(sweepAngle),
    );

    canvas.drawLine(center, lineEnd, sweepPaint);
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.opacity != opacity ||
        oldDelegate.color != color ||
        oldDelegate.sweepAngle != sweepAngle;
  }
}
