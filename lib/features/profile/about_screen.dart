import 'package:flutter/material.dart';

import '../../core/theme/wolf_colors.dart';
import '../../core/widgets/scan_line.dart';
import '../../core/widgets/wolf_brand.dart';
import '../shell/app_shell.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WolfTopBar(title: 'ABOUT'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          const WolfBrandMark(),
          const SizedBox(height: 24),
          Text(
            'Hunt. Stream. Dominate.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'WOLFTVEE is a flat, intense Flutter catalog for films, series, '
            'and live TV. Discovery merges Elo playable catalogs with Trakt/TMDB. '
            'Live TV pulls the global IPTV directory (sports-first) plus optional '
            'Public IPTV and Elo broadcasts. Playback and continue watching run '
            'in-app.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          const ScanLine(height: 2),
          const SizedBox(height: 20),
          _AboutRow(label: 'Version', value: '1.0.0'),
          _AboutRow(label: 'Engine', value: 'Flutter'),
          _AboutRow(label: 'Catalog', value: 'Elo + Trakt/TMDB'),
          _AboutRow(label: 'Live TV', value: 'IPTV + Elo'),
          _AboutRow(label: 'Player', value: 'WOLFTVEE'),
          const SizedBox(height: 24),
          const Center(child: WolfLogoMark(size: 96, radius: 14)),
          const SizedBox(height: 16),
          Text(
            'This product uses the TMDB API but is not endorsed or certified '
            'by TMDB.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: WolfColors.steel),
        color: WolfColors.charcoal,
      ),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
