import 'package:flutter/material.dart';
import '../data/app_settings.dart';
import 'severina_face.dart';
export 'severina_face.dart' show SeverinaFaceState;

/// Cenário completo da Severina:
/// - Fundo (cenario trocavel)
/// - Corpo do robo (PNG do pescoço pra baixo)
/// - Cabeca (CustomPainter do severina_face.dart)
///
/// Layout: corpo alinhado ao fundo da tela. Cabeca desenhada no topo do corpo,
/// alinhada por x_center do pescoço do PNG (1154px largura, x_center=570).

class SeverinaScene extends StatelessWidget {
  final SeverinaFaceState state;
  static const _robotAsset = 'assets/robot/robot_body.png';

  const SeverinaScene({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1) Cenário de fundo
            Image.asset(
              AppSettings.I.activeScene.file,
              fit: BoxFit.cover,
            ),

            // 2) Corpo do robô (alinhado ao rodapé)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Image.asset(
                _robotAsset,
                fit: BoxFit.fitWidth,
                width: screenW,
                alignment: Alignment.bottomCenter,
              ),
            ),

            // 3) Cabeça (CustomPainter) — sobreposta no topo do corpo
            Positioned(
              left: screenW * 0.32,
              right: screenW * 0.32,
              top: screenH * 0.08,
              child: SeverinaFace(state: state),
            ),
          ],
        );
      },
    );
  }
}
