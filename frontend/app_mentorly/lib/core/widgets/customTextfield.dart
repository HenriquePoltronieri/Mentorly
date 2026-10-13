import 'package:flutter/material.dart';
import '../../app/theme.dart';

// Campo de texto padrao usado nos formularios
class CustomTextfield extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool senha;
  final String? Function(String?)? validator;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const CustomTextfield({
    super.key,
    required this.label,
    required this.controller,
    this.senha = false,
    this.validator,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  @override
  State<CustomTextfield> createState() => _CustomTextfieldState();
}

class _CustomTextfieldState extends State<CustomTextfield> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppVisual.raioPilula),
            boxShadow: AppVisual.sombraCampo),
        child: TextFormField(
          controller: widget.controller,
          autofocus: widget.autofocus,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          obscureText: widget.senha && _oculta,
          autocorrect: !widget.senha,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(fontSize: 14),
          validator: widget.validator,
          decoration: InputDecoration(
              labelText: widget.label,
              suffixIcon: widget.senha
                  ? IconButton(
                      tooltip: _oculta ? 'Mostrar senha' : 'Ocultar senha',
                      onPressed: () => setState(() => _oculta = !_oculta),
                      icon: Icon(_oculta
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    )
                  : null),
        ));
  }
}
