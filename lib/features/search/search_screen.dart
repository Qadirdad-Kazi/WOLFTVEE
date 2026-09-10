import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/wolf_colors.dart';
import '../../core/widgets/poster_grid.dart';
import '../../core/widgets/wolf_poster.dart';
import '../../data/models/media_item.dart';
import '../shell/app_shell.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<MediaItem> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () => _search(value));
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await AppScope.repoOf(context).search(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WolfTopBar(
        title: 'SEARCH',
        actions: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.close, color: WolfColors.mist),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: Theme.of(context).textTheme.bodyLarge,
              cursorColor: WolfColors.lime,
              decoration: const InputDecoration(
                hintText: 'Hunt titles, series…',
                prefixIcon: Icon(Icons.search, color: WolfColors.lime),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(
              color: WolfColors.lime,
              backgroundColor: WolfColors.steel,
              minHeight: 2,
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _controller.text.isEmpty
                          ? 'Type to stalk the catalog'
                          : 'No matches',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    gridDelegate: posterGridDelegate(context),
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final item = _results[i];
                      return WolfPoster(
                        item: item,
                        expand: true,
                        index: i % 9,
                        onTap: () => context.push(
                          '/detail/${item.kind.name}/${item.id}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
