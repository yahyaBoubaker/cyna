import 'package:flutter/material.dart';

class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.controller,
    required this.label,
    this.keyboard,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboard;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }
}
