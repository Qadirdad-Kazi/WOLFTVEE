import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/platform/wolf_tv.dart';
import 'core/theme/wolf_theme.dart';
import 'core/widgets/tv_focusable.dart';
import 'data/controllers/catalog_controller.dart';
import 'data/repositories/media_repository.dart';
import 'data/services/cache_store.dart';
import 'data/services/dead_stream_store.dart';
import 'data/services/elo_api_service.dart';
import 'data/services/favorites_store.dart';
import 'data/services/iptv_org_service.dart';
import 'data/services/public_iptv_service.dart';
import 'data/services/settings_store.dart';
import 'data/services/trakt_service.dart';
import 'data/services/tmdb_service.dart';
import 'data/services/watch_progress_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await Env.load();
  await WolfTv.init();

  if (WolfTv.isTv) {
    // Fire Stick / Android TV — landscape, immersive.
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    // Handheld only — never lock desktop.
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  final settings = SettingsStore();
  await settings.load();

  final watchProgress = WatchProgressStore();
  await watchProgress.load();

  final favorites = FavoritesStore();
  await favorites.load();

  final deadStreams = DeadStreamStore();
  await deadStreams.load();

  final cache = CacheStore(ttl: Duration(hours: settings.cacheHours));
  await cache.init();

  final elo = EloApiService(cache: cache);
  final iptv = IptvOrgService(cache: cache);
  final publicIptv = PublicIptvService(cache: cache);
  final tmdb = TmdbService(cache: cache);
  final trakt = TraktService(tmdb: tmdb, cache: cache);
  final repo = MediaRepository(
    elo: elo,
    iptv: iptv,
    publicIptv: publicIptv,
    tmdb: tmdb,
    trakt: trakt,
  );
  final catalog = CatalogController(repo, elo, tmdb: tmdb, trakt: trakt);

  runApp(
    AppScope(
      repo: repo,
      catalog: catalog,
      settings: settings,
      watchProgress: watchProgress,
      favorites: favorites,
      deadStreams: deadStreams,
      child: WolfApp(router: buildRouter()),
    ),
  );
}

class WolfApp extends StatelessWidget {
  const WolfApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WOLFTVEE',
      debugShowCheckedModeBanner: false,
      theme: WolfTheme.dark(),
      routerConfig: router,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        return WolfTvShortcuts(child: content);
      },
    );
  }
}
