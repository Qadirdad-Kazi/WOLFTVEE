import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/wolf_colors.dart';
import 'tv_focusable.dart';

class CategoryBar extends StatelessWidget {
  const CategoryBar({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, i) {
          final active = i == selected;
          return WolfTvFocusable(
            onActivate: () => onSelect(i),
            child: GestureDetector(
              onTap: () => onSelect(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    labels[i].toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: active ? WolfColors.lime : WolfColors.mist,
                          letterSpacing: 1.8,
                        ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: 220.ms,
                    height: 2,
                    width: active ? 28 : 0,
                    color: WolfColors.lime,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
