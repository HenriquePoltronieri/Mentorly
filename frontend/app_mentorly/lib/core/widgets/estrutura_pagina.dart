import 'package:flutter/material.dart';
import '../../app/theme.dart';
import 'identidade_visual.dart';

// Limita a largura sem impor um segundo scroll às listas e formulários.
class ConteudoPagina extends StatelessWidget {
  final Widget child;
  final double largura;
  final bool vidro;
  const ConteudoPagina(
      {super.key, required this.child, this.largura = 1120, this.vidro = true});
  @override
  Widget build(BuildContext context) => ColoredBox(
      color: AppCores.fundo,
      child: Padding(
          padding:
              EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 12 : 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: largura),
                child: vidro ? VidroCard(child: child) : child),
          )));
}

class FormularioAcesso extends StatelessWidget {
  final String titulo;
  final String descricao;
  final Widget child;
  const FormularioAcesso(
      {super.key,
      required this.titulo,
      required this.descricao,
      required this.child});
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppEspacos.grande),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Mentorly',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: AppCores.acento)),
                  const SizedBox(height: 40),
                  Text(titulo,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(descricao,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppCores.secundario)),
                  const SizedBox(height: 32),
                  child,
                ]),
          ),
        ),
      );
}

class CarregamentoPagina extends StatelessWidget {
  const CarregamentoPagina({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Carregando conteúdo',
        child: ExcludeSemantics(
            child: ListView(
          padding: const EdgeInsets.all(24),
          children: List.generate(
              5,
              (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              height: 16,
                              width: i == 0 ? 180 : 240,
                              color: AppCores.linha),
                          const SizedBox(height: 8),
                          Container(
                              height: 12,
                              width: 140,
                              color: AppCores.linha.withValues(alpha: .5)),
                        ]),
                  )),
        )),
      );
}

class EstadoPagina extends StatelessWidget {
  final String titulo;
  final String mensagem;
  final String? acao;
  final VoidCallback? onPressed;
  const EstadoPagina(
      {super.key,
      required this.titulo,
      required this.mensagem,
      this.acao,
      this.onPressed});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 32),
          Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(mensagem),
          if (acao != null) ...[
            const SizedBox(height: 24),
            Align(
                alignment: Alignment.centerLeft,
                child:
                    OutlinedButton(onPressed: onPressed, child: Text(acao!))),
          ],
        ],
      );
}
