import 'package:flutter/material.dart';

/// A round avatar showing the first letter of [name] on [color].
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.name,
    required this.color,
    this.radius = 20,
  });

  final String name;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      foregroundColor: const Color(0xFF263238),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: radius * 0.9),
      ),
    );
  }
}
