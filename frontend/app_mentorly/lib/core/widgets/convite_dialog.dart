import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> mostrarConvite(
    BuildContext context, Map<String, dynamic> resposta) {
  final link = resposta['conviteLink'] as String?;
  return showDialog<void>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: const Text('Convite do professor'),
      content: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(resposta['conviteEnviado'] == true
                ? 'Convite enviado por e-mail. O professor já pode criar a senha.'
                : 'O e-mail não foi enviado. Copie o link abaixo e compartilhe com o professor.'),
            const SizedBox(height: 16),
            if (link != null) SelectableText(link),
            const SizedBox(height: 12),
            const Text(
                'Válido por 48 horas, para um único uso. Um novo convite substitui o anterior.'),
          ])),
      actions: [
        if (link != null)
          OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (!contexto.mounted) return;
                ScaffoldMessenger.of(contexto).showSnackBar(
                    const SnackBar(content: Text('Link copiado')));
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copiar link do convite')),
        FilledButton(
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Concluir')),
      ],
    ),
  );
}
