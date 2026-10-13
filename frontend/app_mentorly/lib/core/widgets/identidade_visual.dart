import 'package:flutter/material.dart';
import '../../app/theme.dart';

enum PerfilVisual { neutro, coordenacao, professor }

// Gradientes estáticos isolados da pintura do formulário/lista; nenhum blur em listas.
class FundoMentorly extends StatelessWidget {
  final PerfilVisual perfil;
  final Widget child;
  const FundoMentorly({super.key, required this.perfil, required this.child});
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, tamanho) {
        final cores = switch (perfil) {
          PerfilVisual.neutro => [
              AppCores.neutro.withValues(alpha: .36),
              AppCores.neutro.withValues(alpha: .12),
              Colors.transparent
            ],
          PerfilVisual.coordenacao => [
              AppCores.coordenacao.withValues(alpha: .43),
              AppCores.coordenacao.withValues(alpha: .18),
              Colors.transparent
            ],
          PerfilVisual.professor => [
              AppCores.professorVerde.withValues(alpha: .42),
              AppCores.professorCiano.withValues(alpha: .30),
              AppCores.professorAzul.withValues(alpha: .15),
              Colors.transparent
            ],
        };
        final lado = tamanho.maxWidth < 600 ? 620.0 : tamanho.maxWidth * .9;
        return Stack(children: [
          Positioned.fill(
              child: RepaintBoundary(
                  child: ColoredBox(
                      color: AppCores.fundo,
                      child: Stack(children: [
                        Positioned(
                            right: -lado * .23,
                            top: tamanho.maxHeight * .06,
                            width: lado,
                            height: lado,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    gradient: RadialGradient(colors: cores))))
                      ])))),
          child,
        ]);
      });
}

class MarcaMentorly extends StatelessWidget {
  final bool compacta;
  final bool somenteIcone;
  const MarcaMentorly(
      {super.key, this.compacta = false, this.somenteIcone = false});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Mentorly',
      image: true,
      child: ExcludeSemantics(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/images/logo.png',
            width: compacta ? 54 : 70, height: compacta ? 54 : 70),
        if (!somenteIcone) ...[
          const SizedBox(width: 4),
          Text('Mentorly',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: compacta ? 19 : 25,
                  fontWeight: FontWeight.w500,
                  color: AppCores.texto))
        ],
      ])));
}

class VidroCard extends StatelessWidget {
  final Widget child;
  final bool formas;
  final EdgeInsetsGeometry padding;
  const VidroCard(
      {super.key,
      required this.child,
      this.formas = false,
      this.padding = EdgeInsets.zero});
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppVisual.raioCard),
          boxShadow: AppVisual.sombraCard),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(AppVisual.raioCard),
          child: DecoratedBox(
              decoration: BoxDecoration(
                  color: AppCores.vidro,
                  borderRadius: BorderRadius.circular(AppVisual.raioCard),
                  border: Border.all(color: const Color(0xAAFFFFFF))),
              child: Stack(children: [
                if (formas)
                  Positioned.fill(
                      child: IgnorePointer(
                          child: RepaintBoundary(
                              child: CustomPaint(painter: _FormasAcesso())))),
                Padding(padding: padding, child: child),
              ]))));
}

class _FormasAcesso extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final topo = Path()
      ..moveTo(size.width - 130, 0)
      ..cubicTo(size.width - 160, 48, size.width - 38, 25, size.width - 65, 96)
      ..cubicTo(size.width - 30, 150, size.width + 24, 88, size.width + 10, 10)
      ..lineTo(size.width + 10, -10)
      ..close();
    canvas.drawPath(
        topo, Paint()..color = AppCores.azulForma.withValues(alpha: .7));
    final base = Path()
      ..moveTo(-12, size.height - 125)
      ..cubicTo(
          58, size.height - 170, 20, size.height - 35, 100, size.height - 58)
      ..cubicTo(
          145, size.height - 30, 60, size.height + 25, -12, size.height + 5)
      ..close();
    canvas.drawPath(
        base, Paint()..color = AppCores.acento.withValues(alpha: .55));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TelaAcesso extends StatelessWidget {
  final PerfilVisual perfil;
  final Widget child;
  final double largura;
  const TelaAcesso(
      {super.key,
      required this.perfil,
      required this.child,
      this.largura = 480});
  @override
  Widget build(BuildContext context) => Scaffold(
      body: FundoMentorly(
          perfil: perfil,
          child: LayoutBuilder(builder: (context, tamanho) {
            final cantos = tamanho.maxWidth >= 1000 && tamanho.maxHeight >= 720;
            return Stack(children: [
              SingleChildScrollView(
                  child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: tamanho.maxHeight),
                      child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              tamanho.maxWidth < 600 ? 16 : 40,
                              112,
                              tamanho.maxWidth < 600 ? 16 : 40,
                              cantos ? 144 : 32),
                          child: Center(
                              child: ConstrainedBox(
                                  constraints:
                                      BoxConstraints(maxWidth: largura),
                                  child: child))))),
              Positioned(
                  top: 16,
                  left: tamanho.maxWidth < 600 ? 12 : 32,
                  child: const MarcaMentorly()),
              if (cantos)
                Positioned(
                    left: 40,
                    bottom: 28,
                    child: IgnorePointer(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Cresça com o',
                              style: Theme.of(context).textTheme.headlineLarge),
                          Padding(
                              padding: const EdgeInsets.only(left: 48),
                              child: Text('Mentorly',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge)),
                        ]))),
              if (cantos && perfil != PerfilVisual.neutro)
                Positioned(
                    right: 40,
                    bottom: 40,
                    child: IgnorePointer(
                        child: Text(
                            perfil == PerfilVisual.professor
                                ? 'Professor'
                                : 'Coordenação',
                            style:
                                Theme.of(context).textTheme.headlineMedium))),
            ]);
          })));
}
