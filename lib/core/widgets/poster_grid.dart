import 'package:flutter/material.dart';

/// Compact poster grid — caps tile width so cards stay poster-sized on wide
/// windows (fixes the “one card fills the screen” bug).
SliverGridDelegate posterGridDelegate(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  // ~128–150px tiles; more columns on large screens.
  final maxExtent = width >= 1100
      ? 148.0
      : width >= 800
          ? 140.0
          : 132.0;
  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: maxExtent,
    // Poster (~2:3) + title block ≈ 0.58 width/height.
    childAspectRatio: 0.58,
    crossAxisSpacing: 10,
    mainAxisSpacing: 14,
  );
}
