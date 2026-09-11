import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wolftvee/app.dart';
import 'package:wolftvee/core/theme/wolf_theme.dart';
import 'package:wolftvee/data/controllers/catalog_controller.dart';
import 'package:wolftvee/data/repositories/media_repository.dart';
import 'package:wolftvee/data/services/elo_api_service.dart';
import 'package:wolftvee/data/services/dead_stream_store.dart';
import 'package:wolftvee/data/services/favorites_store.dart';
import 'package:wolftvee/data/services/settings_store.dart';
import 'package:wolftvee/data/services/tmdb_service.dart';
import 'package:wolftvee/data/services/trakt_service.dart';
import 'package:wolftvee/data/services/watch_progress_store.dart';
import 'package:wolftvee/features/splash/splash_screen.dart';

void main() {
  testWidgets('Splash renders brand', (tester) async {
    final elo = EloApiService();
    final tmdb = TmdbService();
    final trakt = TraktService(tmdb: tmdb);
    final repo = MediaRepository(elo: elo, tmdb: tmdb, trakt: trakt);
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const SizedBox(),
        ),
      ],
    );

    await tester.pumpWidget(
      AppScope(
        repo: repo,
        catalog: CatalogController(repo, elo, tmdb: tmdb, trakt: trakt),
        settings: SettingsStore(),
        watchProgress: WatchProgressStore(),
        favorites: FavoritesStore(),
        deadStreams: DeadStreamStore(),
        child: MaterialApp.router(
          theme: WolfTheme.dark(),
          routerConfig: router,
        ),
      ),
    );

    expect(find.textContaining('W O L F'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
