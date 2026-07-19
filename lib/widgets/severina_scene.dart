import 'package:flutter/material.dart';
import '../data/app_settings.dart';
import 'severina_face.dart';
export 'severina_face.dart' show SeverinaFaceState;

/// Cenário completo da Severina:
/// - Fundo (cenario trocavel)
/// - Corpo do robo (PNG do pescoço pra baixo)
/// - Cabeca (CustomPainter do severina_face.dart)
///
/// Corpo dimensionado a 40% da largura da tela, centralizado horizontalmente,
/// posicionado a ~32% da altura a partir do rodapé. Cabeça encaixada no topo
/// do corpo, alinhada pelo x_center do pescoço do PNG (49.4% do centro).

class SeverinaScene extends StatelessWidget {
  final SeverinaFaceState state;
  static const _robotAsset = 'assets/robot/robot_body.png';

  // Dimensoes originais do robot_body.png
  static const double _imgW = 1154.0;
  static const double _imgH = 1363.0;
  // x_center do pescoco na imagem original (centro horizontal do topo)
  static const double _neckXCenter = 0.494; // 570 / 1154

  const SeverinaScene({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        // Corpo: 40% da largura da tela
        final bodyW = screenW * 0.40;
        // Altura correspondente mantendo proporcao
        final bodyH = bodyW * (_imgH / _imgW);

        // Centralizar horizontalmente
        final bodyLeft = (screenW - bodyW) / 2;
        // Posicionar ~25% acima do rodapé (para nao ficar colado no fundo)
        final bodyTop = screenH - bodyH - (screenH * 0.32);

        // Cabeça: posicionada no topo do corpo, alinhada horizontalmente
        // com o x_center do pescoco. Largura ~28% da tela.
        final headW = screenW * 0.28;
        // Cabeça fica ligeiramente acima do topo do corpo (sobreposicao)
        final headTop = bodyTop - headW * 1.0;
        // Alinhar horizontalmente: pescoco do corpo está a bodyLeft + bodyW * _neckXCenter
        final neckXInBody = bodyLeft + bodyW * _neckXCenter;
        final headLeft = neckXInBody - headW / 2;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1) Cenário de fundo
            Image.asset(
              AppSettings.I.activeScene.file,
              fit: BoxFit.cover,
            ),

            // 2) Corpo do robô (40% lagura, centralizado, ~25% acima do rodapé)
            Positioned(
              left: bodyLeft,
              top: bodyTop,
              width: bodyW,
              child: Image.asset(
                _robotAsset,
                fit: BoxFit.contain,
              ),
            ),

            // 3) Cabeça (CustomPainter) — encaixada no topo do corpo
            Positioned(
              left: headLeft,
              top: headTop,
              width: headW,
              child: SeverinaFace(state: state),
            ),
          ],
        );
      },
    );
  }
}
