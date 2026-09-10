import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/wolf_colors.dart';
import '../../core/widgets/category_bar.dart';
import '../../core/widgets/hunt_refresh.dart';
import '../../core/widgets/poster_grid.dart';
import '../../core/widgets/wolf_poster.dart';
import '../../data/controllers/catalog_controller.dart';
import '../../data/models/media_item.dart';
import '../shell/app_shell.dart';

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  late CatalogController _catalog;
  List<Genre> _genres = const [];
  List<MediaItem> _items = const [];
  int _selected = 0;
  bool _loadingGenre = false;
  bool _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    _catalog = AppScope.catalogOf(context);
    _catalog.addListener(_sync);
    _catalog.bootstrap();
    _sync();
  }

  void _sync() {
    void apply() {
      if (!mounted) return;
      setState(() {
        _genres = [
          const Genre(id: -1, name: 'All'),
          ..._catalog.tvGenres,
        ];
        if (_selected == 0) {
          _items = _catalog.series;
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => apply());
  }

  @override
  void dispose() {
    _catalog.removeListener(_sync);
    super.dispose();
  }

  Future<void> _select(int index) async {
    setState(() {
      _selected = index;
      _loadingGenre = true;
    });
    final genre = _genres[index];
    final items = await _catalog.seriesByGenre(genre.id);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loadingGenre = false;
    });
  }

  Future<void> _refresh() async {
    await _catalog.huntRefresh();
    if (_selected == 0) {
      setState(() => _items = _catalog.series);
    } else {
      await _select(_selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sweeping = _catalog.phase == CatalogPhase.sweeping;
    final gen = _catalog.lastUpdated?.millisecondsSinceEpoch ?? 0;

    return Scaffold(
      appBar: WolfTopBar(
        title: 'SERIES',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: HuntRefreshButton(
              compact: true,
              busy: sweeping,
              onPressed: _refresh,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_genres.isNotEmpty)
                CategoryBar(
                  labels: _genres.map((g) => g.name).toList(),
                  selected: _selected,
                  onSelect: _select,
                ),
              const SizedBox(height: 12),
              Expanded(
                child: _catalog.phase == CatalogPhase.loading &&
                        _items.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: WolfColors.lime,
                        ),
                      )
                    : _loadingGenre
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: WolfColors.lime,
                            ),
                          )
                        : LiveCatalogSwitch(
                            generation: '$gen-$_selected-${_items.length}',
                            child: GridView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 8, 20, 100),
                              gridDelegate: posterGridDelegate(context),
                              itemCount: _items.length,
                              itemBuilder: (context, i) {
                                final item = _items[i];
                                return WolfPoster(
                                  item: item,
                                  expand: true,
                                  index: i % 9,
                                  onTap: () =>
                                      context.push('/detail/tv/${item.id}'),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
          HuntSweepOverlay(active: sweeping),
        ],
      ),
    );
  }
}
