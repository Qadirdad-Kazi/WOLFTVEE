import 'package:flutter/foundation.dart';

import '../models/media_item.dart';
import '../repositories/media_repository.dart';
import '../services/cache_store.dart';
import '../services/elo_api_service.dart';
import '../services/trakt_service.dart';
import '../services/tmdb_service.dart';

enum CatalogPhase { idle, loading, sweeping, ready, error }

/// Holds home catalog and drives live refresh with sweep phase.
class CatalogController extends ChangeNotifier {
  CatalogController(
    this._repo,
    this._elo, {
    TmdbService? tmdb,
    TraktService? trakt,
  })  : _tmdb = tmdb,
        _trakt = trakt;

  final MediaRepository _repo;
  final EloApiService _elo;
  final TmdbService? _tmdb;
  final TraktService? _trakt;

  CatalogBundle? catalog;
  CatalogPhase phase = CatalogPhase.idle;
  String? error;
  DateTime? lastUpdated;

  List<MediaItem> movies = const [];
  List<MediaItem> series = const [];
  List<Genre> movieGenres = const [];
  List<Genre> tvGenres = const [];

  Future<void> bootstrap({bool preferFresh = false}) async {
    if (catalog != null && !preferFresh) {
      phase = CatalogPhase.ready;
      notifyListeners();
      return;
    }
    phase = CatalogPhase.loading;
    error = null;
    notifyListeners();
    try {
      _setForce(preferFresh);
      await _loadAll();
      phase = CatalogPhase.ready;
    } catch (e) {
      error = e.toString();
      phase = CatalogPhase.error;
    } finally {
      _setForce(false);
      notifyListeners();
    }
  }

  Future<void> huntRefresh() async {
    if (phase == CatalogPhase.sweeping) return;
    phase = CatalogPhase.sweeping;
    error = null;
    notifyListeners();

    try {
      _setForce(true);
      await Future.wait([
        _loadAll(),
        Future<void>.delayed(const Duration(milliseconds: 1100)),
      ]);
      lastUpdated = DateTime.now();
      phase = CatalogPhase.ready;
    } catch (e) {
      error = e.toString();
      phase = catalog == null ? CatalogPhase.error : CatalogPhase.ready;
    } finally {
      _setForce(false);
      notifyListeners();
    }
  }

  void _setForce(bool v) {
    _elo.forceRefresh = v;
    _tmdb?.forceRefresh = v;
    _trakt?.forceRefresh = v;
  }

  Future<void> _loadAll() async {
    // One catalog pass only — shelves come from loadHome (no re-fetch).
    final home = await _repo.loadHome();
    catalog = home;
    movies = home.movies;
    series = home.series;
    movieGenres = home.movieGenres;
    tvGenres = home.tvGenres;
    lastUpdated = DateTime.now();
  }

  Future<List<MediaItem>> moviesByGenre(int genreId) async {
    if (genreId < 0) return movies;
    // Filter in-memory — do not hit the network again.
    return movies.where((m) => m.genreIds.contains(genreId)).toList();
  }

  Future<List<MediaItem>> seriesByGenre(int genreId) async {
    if (genreId < 0) return series;
    return series.where((m) => m.genreIds.contains(genreId)).toList();
  }

  Future<void> clearCache() => _elo.clearCache();

  Future<CacheStats> cacheStats() => _elo.cacheStats();

  void updateCacheTtl(Duration ttl) {
    // Elo / TMDB / Trakt share the same CacheStore instance from main.dart.
    _elo.updateCacheTtl(ttl);
  }
}
