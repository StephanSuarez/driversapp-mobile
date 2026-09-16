import 'package:flutter/material.dart';

class ContenedorVidrio extends StatelessWidget {
  final double? ancho;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const ContenedorVidrio({
    super.key,
    this.ancho,
    this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4).withOpacity(0.3),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: child,
    );
  }
}