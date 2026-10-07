import 'package:budget/ameen/materialIconCatalog.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Renders an "ms:<name>" icon in the same box an upstream PNG category icon uses
class MaterialCategoryIcon extends StatelessWidget {
  const MaterialCategoryIcon({
    required this.iconName,
    required this.size,
    this.color,
    super.key,
  });
  final String iconName;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(
          materialIconFor(iconName) ?? Symbols.category_rounded,
          size: size * 0.92,
          fill: 1,
          color: color ?? Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
