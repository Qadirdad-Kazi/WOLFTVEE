import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime config — secrets/base URLs live in `.env` (gitignored).
abstract final class Env {
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      await dotenv.load(fileName: '.env.example');
    }
  }

  /// Licensed catalog / live API (playback primary).
  static String get apiBaseUrl {
    final v = dotenv.env['MAPI_BASE_URL']?.trim();
    if (v != null && v.isNotEmpty) {
      return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    }
    return 'https://mapi.elochkaigolochla.com/api/v1';
  }

  static String get imageCdn {
    final v = dotenv.env['IMG_CDN']?.trim();
    if (v != null && v.isNotEmpty) {
      return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    }
    return 'https://img.elochkaigolochla.com';
  }

  /// TMDB — catalog metadata / posters / gap-fill (secondary discovery).
  static String get tmdbApiKey => dotenv.env['TMDB_API_KEY']?.trim() ?? '';

  static bool get hasTmdbKey => tmdbApiKey.isNotEmpty;

  static String get tmdbBaseUrl {
    final v = dotenv.env['TMDB_BASE_URL']?.trim();
    if (v != null && v.isNotEmpty) {
      return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    }
    return 'https://api.themoviedb.org/3';
  }

  static String get tmdbImageBase {
    final v = dotenv.env['TMDB_IMAGE_BASE']?.trim();
    if (v != null && v.isNotEmpty) {
      return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    }
    return 'https://image.tmdb.org/t/p';
  }

  /// Trakt — optional trending lists (needs your own Client ID).
  static String get traktClientId =>
      dotenv.env['TRAKT_CLIENT_ID']?.trim() ?? '';

  /// Optional second Client ID tried automatically if primary fails.
  static String get traktClientIdFallback =>
      dotenv.env['TRAKT_CLIENT_ID_FALLBACK']?.trim() ?? '';

  /// Primary + fallback, deduped, non-empty.
  static List<String> get traktClientIds {
    final out = <String>[];
    final seen = <String>{};
    for (final id in [traktClientId, traktClientIdFallback]) {
      if (id.isNotEmpty && seen.add(id)) out.add(id);
    }
    return out;
  }

  static bool get hasTrakt => traktClientIds.isNotEmpty;

  static String get traktBaseUrl {
    final v = dotenv.env['TRAKT_BASE_URL']?.trim();
    if (v != null && v.isNotEmpty) {
      return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    }
    return 'https://api.trakt.tv';
  }

  static String get accentHex =>
      (dotenv.env['ACCENT_HEX'] ?? 'C8FF00').replaceAll('#', '');

  /// Absolute URLs pass through; TMDB `/xyz.jpg` paths use image.tmdb.org;
  /// other relative paths use Elo CDN.
  static String posterUrl(String? path, {String size = 'w342'}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final p = path.startsWith('/') ? path : '/$path';
    final lower = p.toLowerCase();
    final looksTmdb = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
    if (looksTmdb) return '$tmdbImageBase/$size$p';
    return '$imageCdn$p';
  }

  static String backdropUrl(String? path, {String size = 'w1280'}) =>
      posterUrl(path, size: size);
}
