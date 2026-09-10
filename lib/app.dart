import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/controllers/catalog_controller.dart';
import 'data/models/media_item.dart';
import 'data/repositories/media_repository.dart';
import 'data/services/favorites_store.dart';
import 'data/services/settings_store.dart';
import 'data/services/watch_progress_store.dart';
import 'features/detail/detail_screen.dart';
import 'features/home/home_screen.dart';
import 'features/live/live_screen.dart';
import 'features/movies/movies_screen.dart';
import 'features/player/stream_player_screen.dart';
import 'features/player/trailer_player_screen.dart';
import 'features/profile/about_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/search/search_screen.dart';
import 'features/series/series_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/splash/splash_screen.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repo,
    required this.catalog,
    required this.settings,
    required this.watchProgress,
    required this.favorites,
    required super.child,
  });

  final MediaRepository repo;
  final CatalogController catalog;
  final SettingsStore settings;
  final WatchProgressStore watchProgress;
  final FavoritesStore favorites;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!;
  }

  static MediaRepository repoOf(BuildContext context) => of(context).repo;
  static CatalogController catalogOf(BuildContext context) =>
      of(context).catalog;
  static SettingsStore settingsOf(BuildContext context) =>
      of(context).settings;
  static WatchProgressStore watchProgressOf(BuildContext context) =>
      of(context).watchProgress;
  static FavoritesStore favoritesOf(BuildContext context) =>
      of(context).favorites;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      repo != oldWidget.repo ||
      catalog != oldWidget.catalog ||
      settings != oldWidget.settings ||
      watchProgress != oldWidget.watchProgress ||
      favorites != oldWidget.favorites;
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/movies',
                builder: (context, state) => const MoviesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/series',
                builder: (context, state) => const SeriesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/live',
                builder: (context, state) => const LiveScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/detail/:kind/:id',
        builder: (context, state) {
          final kind = state.pathParameters['kind'] == 'tv'
              ? MediaKind.tv
              : MediaKind.movie;
          final id = int.parse(state.pathParameters['id']!);
          return DetailScreen(kind: kind, id: id);
        },
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return TrailerPlayerScreen(
            title: (extra['title'] ?? 'Trailer').toString(),
            youtubeKey: extra['key'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/stream',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final rawSources = extra['sources'];
          final sources = <LiveStreamSource>[];
          if (rawSources is List) {
            for (final s in rawSources) {
              if (s is Map) {
                final src =
                    LiveStreamSource.fromJson(Map<String, dynamic>.from(s));
                if (src.url.isNotEmpty) sources.add(src);
              }
            }
          }
          return StreamPlayerScreen(
            title: (extra['title'] ?? 'Stream').toString(),
            streamUrl: (extra['url'] ?? '').toString(),
            userAgent: extra['userAgent'] as String?,
            referrer: extra['referrer'] as String?,
            mode: (extra['mode'] ?? 'live').toString(),
            provider: (extra['provider'] ?? 'live').toString(),
            kind: extra['kind']?.toString(),
            mediaId: extra['mediaId']?.toString(),
            season: (extra['season'] as int?) ?? 1,
            episode: (extra['episode'] as int?) ?? 1,
            sources: sources,
            sourceIndex: (extra['sourceIndex'] as int?) ?? 0,
            forceWebView: extra['webview'] == true,
          );
        },
      ),
    ],
  );
}
