import 'package:flutter/material.dart';

class ColorUtils {
  static const Map<String, Color> _colorMap = {
    'Blanco': Color(0xFFF5F5F5),
    'Marfil': Color(0xFFFFFFF0),
    'Hueso': Color(0xFFF8F0E3),
    'Nude': Color(0xFFE8C9A0),
    'Beige': Color(0xFFD4B896),
    'Camel': Color(0xFFC19A6B),
    'Tierra': Color(0xFF8B6347),
    'Cafe': Color(0xFF795548),
    'Chocolate': Color(0xFF5D4037),
    'Gris': Color(0xFF9E9E9E),
    'Plata': Color(0xFFBDBDBD),
    'Negro': Color(0xFF212121),
    'Dorado': Color(0xFFFFD700),
    'Rose': Color(0xFFFFB6C1),
    'Rosa': Color(0xFFF48FB1),
    'Rojo': Color(0xFFF44336),
    'Coral': Color(0xFFFF7F50),
    'Salmón': Color(0xFFFA8072),
    'Fucsia': Color(0xFFFF4081),
    'Vino': Color(0xFF6A1B32),
    'Burdeos': Color(0xFF880E4F),
    'Granate': Color(0xFF6D1B22),
    'Mostaza': Color(0xFFFFDB58),
    'Naranja': Color(0xFFFF9800),
    'Amarillo': Color(0xFFFFEB3B),
    'Azul': Color(0xFF2196F3),
    'Marino': Color(0xFF001F5B),
    'Celeste': Color(0xFF81D4FA),
    'Turquesa': Color(0xFF009688),
    'Verde': Color(0xFF4CAF50),
    'Morado': Color(0xFF9C27B0),
    'Lavanda': Color(0xFFE6E6FA),
  };

  static const Set<String> _lightColors = {
    'Blanco', 'Marfil', 'Hueso', 'Lavanda', 'Rose', 'Amarillo',
    'Mostaza', 'Celeste', 'Nude', 'Beige',
  };

  static Color? fromName(String? name) {
    if (name == null) return null;
    return _colorMap[name];
  }

  static bool needsBorder(String? name) => _lightColors.contains(name);

  /// Returns a small filled circle representing the color.
  static Widget colorDot(String? colorName, {double size = 12}) {
    if (colorName == null) return const SizedBox.shrink();
    final color = fromName(colorName);
    if (color == null) return const SizedBox.shrink();
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: needsBorder(colorName) ? const Color(0xFFAAAAAA) : Colors.transparent,
          width: 0.8,
        ),
      ),
    );
  }
}
