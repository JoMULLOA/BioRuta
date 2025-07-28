import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Constante para el texto de la notificación
const String _rideAcceptedText = 'Viaje Aceptado';

class RideAcceptedNotification extends StatefulWidget {
  final VoidCallback? onAnimationComplete;

  const RideAcceptedNotification({
    super.key,
    this.onAnimationComplete,
  });

  @override
  State<RideAcceptedNotification> createState() => _RideAcceptedNotificationState();
}

class _RideAcceptedNotificationState extends State<RideAcceptedNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeOutAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.4, curve: Curves.easeOut),
    ));

    _fadeOutAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
    ));

    _startAnimation();
  }

  void _startAnimation() async {
    // Feedback háptico
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    
    // Iniciar animación
    await _controller.forward();
    
    // Completar
    if (widget.onAnimationComplete != null) {
      widget.onAnimationComplete!();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value * 200),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeOutAnimation.value,
                    child: Container(
                      width: 280,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF4CAF50),
                            Color(0xFF66BB6A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.4),
                            spreadRadius: 4,
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 48,
                          ),
                          SizedBox(width: 16),
                          Text(
                            _rideAcceptedText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Helper para mostrar la notificación
class RideAcceptedHelper {
  static void show(BuildContext context, {VoidCallback? onComplete}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => RideAcceptedNotification(
        onAnimationComplete: () {
          overlayEntry.remove();
          onComplete?.call();
        },
      ),
    );

    overlay.insert(overlayEntry);
  }
}
