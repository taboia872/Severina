import 'package:flutter/material.dart';

/// Face da Severina desenhada com CustomPainter.
/// Boca anima (abre/fecha) durante speaking.
/// Olhos mudam de forma durante thinking.
class SeverinaFace extends StatefulWidget {
  final SeverinaFaceState state;

  const SeverinaFace({super.key, required this.state});

  @override
  State<SeverinaFace> createState() => _SeverinaFaceState();
}

enum SeverinaFaceState { idle, listening, thinking, speaking }

class _SeverinaFaceState extends State<SeverinaFace>
    with TickerProviderStateMixin {
  late AnimationController _speakController;
  late AnimationController _blinkController;
  late AnimationController _thinkController;

  @override
  void initState() {
    super.initState();

    _speakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _thinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _blinkController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(SeverinaFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimations();
  }

  void _updateAnimations() {
    switch (widget.state) {
      case SeverinaFaceState.speaking:
        if (!_speakController.isAnimating) _speakController.repeat(reverse: true);
        _thinkController.stop();
        break;
      case SeverinaFaceState.thinking:
        if (!_thinkController.isAnimating) _thinkController.repeat(reverse: true);
        _speakController.stop();
        break;
      default:
        _speakController.stop();
        _thinkController.stop();
    }
  }

  @override
  void dispose() {
    _speakController.dispose();
    _blinkController.dispose();
    _thinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_speakController, _blinkController, _thinkController]),
      builder: (context, _) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _FacePainter(
            state: widget.state,
            speakProgress: _speakController.value,
            blinkProgress: _blinkController.value,
            thinkProgress: _thinkController.value,
          ),
        );
      },
    );
  }
}

class _FacePainter extends CustomPainter {
  final SeverinaFaceState state;
  final double speakProgress;
  final double blinkProgress;
  final double thinkProgress;

  _FacePainter({
    required this.state,
    required this.speakProgress,
    required this.blinkProgress,
    required this.thinkProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // === Cores por estado ===
    final eyeColor = switch (state) {
      SeverinaFaceState.thinking => Colors.amber,
      SeverinaFaceState.speaking => Colors.green,
      SeverinaFaceState.listening => Colors.red[300]!,
      SeverinaFaceState.idle => Colors.indigo,
    };

    final mouthColor = eyeColor;

    // === Olhos ===
    final eyeRadius = 14.0;
    final eyeY = center.dy - 20;
    final leftEyeCenter = Offset(center.dx - 32, eyeY);
    final rightEyeCenter = Offset(center.dx + 32, eyeY);

    // Blink: quando blinkProgress > 0.85, olhos fecham
    final blinkAmount = (blinkProgress > 0.85) ? (1 - (blinkProgress - 0.85) / 0.15) : 1.0;

    // Thinking: olhos viram linha horizontal (piscar lento)
    final eyeHeightFactor = state == SeverinaFaceState.thinking
        ? 0.15 + 0.1 * (0.5 + 0.5 * thinkProgress)
        : blinkAmount;

    _drawEye(canvas, leftEyeCenter, eyeRadius, eyeHeightFactor, eyeColor);
    _drawEye(canvas, rightEyeCenter, eyeRadius, eyeHeightFactor, eyeColor);

    // === Boca ===
    final mouthY = center.dy + 30;

    switch (state) {
      case SeverinaFaceState.speaking:
        // Boca circular que pulsa (abre/fecha)
        final mouthOpen = 8.0 + 18.0 * speakProgress;
        _drawMouthSpeaking(canvas, Offset(center.dx, mouthY), mouthOpen, mouthColor);
        break;
      case SeverinaFaceState.listening:
        // Boca pequena, ligeiramente aberta (ouvindo)
        _drawMouthOval(canvas, Offset(center.dx, mouthY), 14, 6, mouthColor);
        break;
      case SeverinaFaceState.thinking:
        // Boca como pequena linha ondulada (pensando)
        _drawMouthThinking(canvas, Offset(center.dx, mouthY), mouthColor, thinkProgress);
        break;
      case SeverinaFaceState.idle:
        // Boca como linha suave (sorriso discreto)
        _drawMouthSmile(canvas, Offset(center.dx, mouthY), 20, mouthColor);
        break;
    }
  }

  void _drawEye(Canvas canvas, Offset center, double radius, double heightFactor, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final eyeRect = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 2 * heightFactor.clamp(0.05, 1.0),
    );

    canvas.drawOval(eyeRect, paint);
  }

  void _drawMouthSpeaking(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Elipse vertical que pulsa
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 1.5, height: radius * 1.8),
      paint,
    );

    // Interior escuro (boca aberta)
    final innerPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 0.8, height: radius * 1.2),
      innerPaint,
    );
  }

  void _drawMouthOval(Canvas canvas, Offset center, double w, double h, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: center, width: w, height: h), paint);
  }

  void _drawMouthSmile(Canvas canvas, Offset center, double width, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - 4),
      width: width,
      height: width * 0.6,
    );

    canvas.drawArc(rect, 0.2, 2.5, false, paint);
  }

  void _drawMouthThinking(Canvas canvas, Offset center, Color color, double progress) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Pequena linha ondulada
    final wave = 3.0 * progress;
    final path = Path();
    path.moveTo(center.dx - 15, center.dy);
    path.quadraticBezierTo(
      center.dx - 5, center.dy - wave,
      center.dx, center.dy,
    );
    path.quadraticBezierTo(
      center.dx + 5, center.dy + wave,
      center.dx + 15, center.dy,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FacePainter oldDelegate) => true;
}
