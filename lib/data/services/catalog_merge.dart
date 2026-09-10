import '../models/media_item.dart';

/// Merge Elo (playable primary) with Trakt/TMDB metadata for matching titles.
///
/// Rules:
/// 1. Match by normalized title + year + kind (Elo has no TMDB id).
/// 2. On match → keep Elo players; prefer newer Elo `createdAt`; enrich poster
///    from TMDB when Elo poster is empty.
/// 3. Unique secondary (discovery-only) titles may appear in the merge list;
///    callers must filter with [MediaItem.hasPlayableSource] before showing UI.
/// 4. Sort with playable Elo first, then by recency.
abstract final class CatalogMerge {
  static String fingerprint(MediaItem item) {
    final title = item.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '')
        .trim();
    final year = item.year?.toString() ??
        (item.releaseDate != null && item.releaseDate!.length >= 4
            ? item.releaseDate!.substring(0, 4)
            : '');
    return '${item.kind.name}|$title|$year';
  }

  /// [primary] = Elo (playable). [secondary] = Trakt/TMDB discovery.
  static List<MediaItem> merge({
    required List<MediaItem> primary,
    required List<MediaItem> secondary,
  }) {
    final byFp = <String, MediaItem>{};
    final order = <String>[];

    void upsert(MediaItem item, {required bool fromPrimary}) {
      final fp = fingerprint(item);
      final existing = byFp[fp];
      if (existing == null) {
        byFp[fp] = item;
        order.add(fp);
        return;
      }
      byFp[fp] = _prefer(existing, item, incomingIsPrimary: fromPrimary);
    }

    for (final item in primary) {
      upsert(item, fromPrimary: true);
    }
    for (final item in secondary) {
      upsert(item, fromPrimary: false);
    }

    final merged = [for (final fp in order) byFp[fp]!];
    merged.sort(_recencyCompare);
    return merged;
  }

  static MediaItem _prefer(
    MediaItem a,
    MediaItem b, {
    required bool incomingIsPrimary,
  }) {
    final elo = a.hasPlayableSource
        ? a
        : (b.hasPlayableSource ? b : (incomingIsPrimary ? b : a));
    final other = identical(elo, a) ? b : a;

    // Prefer newer Elo upload when both are Elo-ish.
    MediaItem base = elo;
    if (a.hasPlayableSource && b.hasPlayableSource) {
      final aAt = a.createdAt;
      final bAt = b.createdAt;
      if (aAt != null && bAt != null) {
        base = bAt.isAfter(aAt) ? b : a;
      }
    }

    final tmdbId = base.tmdbId ?? other.tmdbId;
    final poster = (base.posterPath != null && base.posterPath!.isNotEmpty)
        ? base.posterPath
        : other.posterPath;
    final backdrop =
        (base.backdropPath != null && base.backdropPath!.isNotEmpty)
            ? base.backdropPath
            : other.backdropPath;
    final overview =
        base.overview.trim().isNotEmpty ? base.overview : other.overview;
    final vote = base.voteAverage > 0 ? base.voteAverage : other.voteAverage;

    return base.copyWith(
      tmdbId: tmdbId,
      posterPath: poster,
      backdropPath: backdrop,
      overview: overview,
      voteAverage: vote,
      players: base.players.isNotEmpty ? base.players : other.players,
      catalogOrigin: base.hasPlayableSource && other.tmdbId != null
          ? CatalogOrigin.merged
          : base.catalogOrigin,
      createdAt: _newer(base.createdAt, other.createdAt),
    );
  }

  static DateTime? _newer(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  static int _recencyCompare(MediaItem a, MediaItem b) {
    // Playable Elo first, then by createdAt desc, then vote.
    final ap = a.hasPlayableSource ? 0 : 1;
    final bp = b.hasPlayableSource ? 0 : 1;
    if (ap != bp) return ap.compareTo(bp);
    final aAt = a.createdAt;
    final bAt = b.createdAt;
    if (aAt != null && bAt != null) return bAt.compareTo(aAt);
    if (aAt != null) return -1;
    if (bAt != null) return 1;
    return b.voteAverage.compareTo(a.voteAverage);
  }
}
