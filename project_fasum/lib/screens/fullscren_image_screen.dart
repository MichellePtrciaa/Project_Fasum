import 'package:flutter/material.dart';

class FullscrenImageScreen extends StatefulWidget {
  final String imageBase64;

  const FullscrenImageScreen({
    super.key,
    required this.imageBase64,});

  @override
  State<FullscrenImageScreen> createState() => _FullscrenImageScreenState();
}

class _FullscrenImageScreenState extends State<FullscrenImageScreen> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}