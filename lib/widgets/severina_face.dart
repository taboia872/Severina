import 'package:flutter/material.dart';

/// Face da Severina — robozinho estilo 🤖 via CustomPainter.
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
    _speakController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _thinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
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
          painter: _RobotFacePainter(
            state: widget.state,
            speakProgress: _speakController.value,
            blinkProgress: _blinkController.value,
            thinkProgress: _thinkController.value,
            accentColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }
}

class _RobotFacePainter extends CustomPainter {
  final SeverinaFaceState state;
  final double speakProgress;
  final double blinkProgress;
  final double thinkProgress;
  final Color accentColor;

  _RobotFacePainter({
    required this.state,
    required this.speakProgress,
    required this.blinkProgress,
    required this.thinkProgress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // === Cores ===
    final bodyColor = accentColor;
    final faceColor = Colors.white;
    final eyeColor = const Color(0xFF3C465A);
    final mouthColor = const Color(0xFF3C465A);

    // === Antena ===
    final antenaX = cx;
    final antenaTop = cy - 70;
    final antenaBot = cy - 42;
    final antenaPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(antenaX, antenaTop + 8), Offset(antenaX, antenaBot), antenaPaint);

    // Bolinha da antena
    final antenaBall = Paint()
      ..color = _antennaBallColor()
      ..style = PaintingStyle.fill;
    final ballR = 7.0;
    canvas.drawCircle(Offset(antenaX, antenaTop + 4), ballR, antenaBall);

    // === Cabeça (retângulo arredondado) ===
    final headW = 100.0;
    final headH = 84.0;
    final headLeft = cx - headW / 2;
    final headTop = cy - 38;
    final headRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(headLeft, headTop, headW, headH),
      const Radius.circular(16),
    );

    // Corpo/cabeça beef color
    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(headRect, bodyPaint);

    // Face interior (área branca)
    final faceW = 84.0;
    final faceH = 60.0;
    final faceLeft = cx - faceW / 2;
    final faceTop = cy - 28;
    final faceRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(faceLeft, faceTop, faceW, faceH),
      const Radius.circular(10),
    );
    final facePaint = Paint()
      ..color = faceColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(faceRect, facePaint);

    // "Orelhas" laterais (barbs do robô)
    final earW = 6.0;
    final earH = 34.0;
    final earPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(headLeft - earW, cy - earH / 2, earW, earH),
        const Radius.circular(3),
      ),
      earPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(headLeft + headW, cy - earH / 2, earW, earH),
        const Radius.circular(3),
      ),
      earPaint,
    );

    // === Olhos ===
    final eyeR = 8.0;
    final eyeY = faceTop + 20;
    final eyeOffset = 20.0;
    final blinkAmt = (blinkProgress > 0.85) ? (1 - (blinkProgress - 0.85) / 0.15) : 1.0;
    final eyeHeight = state == SeverinaFaceState.thinking
        ? 0.2 + 0.15 * thinkProgress
        : blinkAmt;

    _drawEye(canvas, Offset(cx - eyeOffset, eyeY), eyeR, eyeHeight, eyeColor);
    _drawEye(canvas, Offset(cx + eyeOffset, eyeY), eyeR, eyeHeight, eyeColor);

    // === Boca ===
    final mouthY = faceTop + faceH - 18;

    switch (state) {
      case SeverinaFaceState.speaking:
        final mouthOpen = 4.0 + 12.0 * speakProgress;
        _drawMouthSpeaking(canvas, Offset(cx, mouthY), mouthOpen, mouthColor);
        break;
      case SeverinaFaceState.listening:
        _drawMouthOval(canvas, Offset(cx, mouthY), 12, 5, mouthColor);
        break;
      case SeverinaFaceState.thinking:
        _drawMouthThinking(canvas, Offset(cx, mouthY), mouthColor, thinkProgress);
        break;
      case SeverinaFaceState.idle:
        _drawMouthSmile(canvas, Offset(cx, mouthY), 16, mouthColor);
        break;
    }
  }

  Color _antennaBallColor() {
    return switch (state) {
      SeverinaFaceState.thinking => Colors.amber,
      SeverinaFaceState.speaking => Colors.green,
      SeverinaFaceState.listening => Colors.red[300]!,
      SeverinaFaceState.idle => Colors.white,
    };
  }

  void _drawEye(Canvas canvas, Offset center, double radius, double heightFactor, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final h = radius * 2 * heightFactor.clamp(0.05, 1.0);
    canvas.drawOval(Rect.fromCenter(center: center, width: radius * 2, height: h), paint);
  }

  void _drawMouthSpeaking(Canvas canvas, Offset center, double radius, Color color) {
    // Boca em meia lua (D deitado) apontando pra baixo.
    // Expande apenas pra baixo (maxilar desce) conforme speakProgress.
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final halfW = radius * 1.0;
    final maxDrop = radius * 0.8;
    final drop = maxDrop * (radius - 4.0) / 12.0; // escala com mouthOpen

    // Arco superior (linha reta na parte de cima) + curva embaixo
    final path = Path();
    path.moveTo(center.dx - halfW, center.dy);
    // Lado esquerdo desce
    path.quadraticBezierTo(
      center.dx, center.dy + drop,
      center.dx + halfW, center.dy,
    );
    // Linha de topo (fecha a boca)
    path.lineTo(center.dx - halfW, center.dy);
    path.close();
    canvas.drawPath(path, paint);

    // Interior escuro (expande pra baixo junto)
    final inner = Paint()..color = Colors.black54..style = PaintingStyle.fill;
    final innerPath = Path();
    final innerDrop = drop * 0.7;
    final innerHalfW = halfW * 0.8;
    innerPath.moveTo(center.dx - innerHalfW, center.dy);
    innerPath.quadraticBezierTo(
      center.dx, center.dy + innerDrop,
      center.dx + innerHalfW, center.dy,
    );
    innerPath.lineTo(center.dx - innerHalfW, center.dy);
    innerPath.close();
    canvas.drawPath(innerPath, inner);
  }

  void _drawMouthOval(Canvas canvas, Offset center, double w, double h, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: center, width: w, height: h), paint);
  }

  void _drawMouthSmile(Canvas canvas, Offset center, double width, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3.0..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(center.dx, center.dy - 3), width: width, height: width * 0.6),
      0.2, 2.5, false, paint,
    );
  }

  void _drawMouthThinking(Canvas canvas, Offset center, Color color, double progress) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3.0..strokeCap = StrokeCap.round;
    final wave = 3.0 * progress;
    final path = Path();
    path.moveTo(center.dx - 12, center.dy);
    path.quadraticBezierTo(center.dx - 4, center.dy - wave, center.dx, center.dy);
    path.quadraticBezierTo(center.dx + 4, center.dy + wave, center.dx + 12, center.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RobotFacePainter oldDelegate) => true;
}
