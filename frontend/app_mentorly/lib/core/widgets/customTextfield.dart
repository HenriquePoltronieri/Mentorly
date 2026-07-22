import 'package:flutter/material.dart';

// Campo de texto padrao usado nos formularios
class CustomTextfield extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool senha;
  final String? Function(String?)? validator;

  const CustomTextfield({
    super.key,
    required this.label,
    required this.controller,
    this.senha = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: senha,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    );
  }
}
