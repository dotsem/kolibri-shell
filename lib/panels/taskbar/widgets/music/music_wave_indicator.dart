import 'dart:math' as math;
import 'package:flutter/material.dart';

class MusicWaveIndicator extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const MusicWaveIndicator({super.key, required this.isPlaying, required this.color});

  @override
  State<MusicWaveIndicator> createState() => _MusicWaveIndicatorState();
}

class _MusicWaveIndicatorState extends State<MusicWaveIndicator> with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Controller for wave animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Controller for fade in/out
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    if (widget.isPlaying) {
      _waveController.repeat();
      _fadeController.forward();
    }
  }

  @override
  void didUpdateWidget(MusicWaveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _waveController.repeat();
        _fadeController.forward();
      } else {
        _waveController.stop();
        _fadeController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: AnimatedBuilder(
        animation: Listenable.merge([_waveController, _fadeAnimation]),
        builder: (context, child) {
          return CustomPaint(
            painter: MusicWavePainter(
              animation: _waveController.value,
              color: widget.color,
              isPlaying: widget.isPlaying,
              fadeValue: _fadeAnimation.value,
            ),
          );
        },
      ),
    );
  }
}

class MusicWavePainter extends CustomPainter {
  final double animation;
  final Color color;
  final bool isPlaying;
  final double fadeValue;

  MusicWavePainter({
    required this.animation,
    required this.color,
    required this.isPlaying,
    required this.fadeValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    // Draw multiple animated waves
    const int barCount = 40;
    final double barWidth = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      final double progress = (animation + (i / barCount)) % 1.0;

      // Create wave effect with sine waves
      final double wave1 = (i / barCount) * 2 * math.pi;
      final double wave2 = progress * 2 * math.pi;

      // Combine multiple sine waves for complex animation
      double height = 0.3 +
          0.3 * (1 + math.sin(wave1 * 3 + wave2 * 2)) / 2 +
          0.2 * (1 + math.sin(wave1 * 5 - wave2 * 3)) / 2 +
          0.2 * (1 + math.sin(wave1 * 7 + wave2 * 4)) / 2;

      height = height.clamp(0.1, 1.0);

      // Apply fade value to bar height - bars shrink down when fading out
      height = height * fadeValue;

      final double barHeight = size.height * height;
      final double x = i * barWidth;
      final double y = size.height - barHeight; // Start from bottom

      canvas.drawRect(Rect.fromLTWH(x, y, barWidth * 0.7, barHeight), paint);
    }
  }

  @override
  bool shouldRepaint(MusicWavePainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.color != color ||
        oldDelegate.fadeValue != fadeValue;
  }
}
