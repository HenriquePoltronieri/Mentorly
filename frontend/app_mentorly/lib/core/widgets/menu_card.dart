import 'package:flutter/material.dart';

class MenuCard extends StatefulWidget {
  final String titulo, descricao;
  final IconData icone;
  final VoidCallback onTap;
  const MenuCard(
      {super.key,
      required this.titulo,
      required this.descricao,
      required this.icone,
      required this.onTap});
  @override
  State<MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<MenuCard> {
  bool _hover = false, _pressed = false;
  @override
  Widget build(BuildContext context) {
    final ativo = _hover || _pressed;
    final raio = BorderRadius.circular(18);
    return AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
            borderRadius: raio,
            boxShadow: ativo
                ? [
                    const BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 12,
                        offset: Offset(0, 3))
                  ]
                : []),
        child: Material(
            color: Colors.white.withValues(alpha: ativo ? .45 : .25),
            shape: RoundedRectangleBorder(
                borderRadius: raio,
                side: BorderSide(
                    color: Colors.white.withValues(alpha: ativo ? 1 : .6))),
            child: InkWell(
                borderRadius: raio,
                onTap: widget.onTap,
                onHover: (v) => setState(() => _hover = v),
                onHighlightChanged: (v) => setState(() => _pressed = v),
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(children: [
                      Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .4),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(widget.icone)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(widget.titulo,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(widget.descricao,
                                style: Theme.of(context).textTheme.bodySmall),
                          ])),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ])))));
  }
}
