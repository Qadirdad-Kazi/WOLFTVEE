/// Ad / tracker blocking for the in-app WOLFTVEE WebView player.
///
/// Platform is ad-free: block ad networks, VAST/IMA prerolls, popups, and
/// scrub overlay DOM so movies start directly.
abstract final class PlayerAdBlock {
  static const hosts = <String>[
    // Google / IMA
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'googletagmanager.com',
    'googletagservices.com',
    'adservice.google.com',
    'pagead2.googlesyndication.com',
    'googleads.g.doubleclick.net',
    'imasdk.googleapis.com',
    'tpc.googlesyndication.com',
    'fundingchoicesmessages.google.com',
    // Ad networks
    'adnxs.com',
    'adsrvr.org',
    'advertising.com',
    'adform.net',
    'adsafeprotected.com',
    'adsymptotic.com',
    'amazon-adsystem.com',
    'aaxads.com',
    'criteo.com',
    'criteo.net',
    'exoclick.com',
    'exosrv.com',
    'juicyads.com',
    'popads.net',
    'popcash.net',
    'propellerads.com',
    'propellerclick.com',
    'revcontent.com',
    'taboola.com',
    'outbrain.com',
    'mgid.com',
    'moatads.com',
    'scorecardresearch.com',
    'quantserve.com',
    'pubmatic.com',
    'openx.net',
    'rubiconproject.com',
    'casalemedia.com',
    'smartadserver.com',
    'yieldmo.com',
    'zedo.com',
    'ad-delivery.net',
    'adcash.com',
    'adsterra.com',
    'hilltopads.com',
    'trafficjunky.net',
    'tsyndicate.com',
    'bidswitch.net',
    'lijit.com',
    '3lift.com',
    'sharethrough.com',
    'media.net',
    'onetag.com',
    'sovrn.com',
    'adskeeper.com',
    'adk2x.com',
    'admedo.com',
    'adcolony.com',
    'unityads.unity3d.com',
    'applovin.com',
    'mopub.com',
    'inmobi.com',
    'spotxchange.com',
    'spotx.tv',
    'teads.tv',
    'smartclip.net',
    'fwmrm.net',
    'stickyadstv.com',
    'serving-sys.com',
    'adobedtm.com',
    'omtrdc.net',
    'demdex.net',
    'everesttech.net',
    'facebook.net',
    'connect.facebook.net',
    'hotjar.com',
    'clarity.ms',
    'mouseflow.com',
    'luckyorange.com',
    'nr-data.net',
    // Common stream-site ad / redirect helpers
    'histats.com',
    'statcounter.com',
    'mc.yandex.ru',
    'yandex.ru/ads',
    'ad.mail.ru',
  ];

  /// Hosts allowed for licensed iframe / HLS helper origins.
  static const fallbackAllowHosts = <String>[
    'salku434jeb.com',
    'www.salku434jeb.com',
    'tmdbsrcimg.site',
    'jam01su.site',
    'img.elochkaigolochla.com',
    'mapi.elochkaigolochla.com',
    'elochkaigolochla.com',
    'allmovielandapp.app',
    'challenges.cloudflare.com',
    'cdn.jsdelivr.net',
    'fonts.googleapis.com',
    'fonts.gstatic.com',
  ];

  /// Legacy alias — same allowlist as iframe player hosts.
  static const popcornAllowHosts = fallbackAllowHosts;

  static bool isAdUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    for (final host in hosts) {
      if (lower.contains(host)) return true;
    }
    if (lower.contains('googlesyndication') ||
        lower.contains('doubleclick') ||
        lower.contains('imasdk') ||
        lower.contains('/preroll') ||
        lower.contains('vast.xml') ||
        lower.contains('/vast?')) {
      return true;
    }
    return false;
  }

  static bool isAllowedHost(String? url, {required bool popcorn}) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'about' || scheme == 'blob' || scheme == 'data') return true;
    if (scheme != 'http' && scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return true;
    final allow = popcorn ? popcornAllowHosts : fallbackAllowHosts;
    for (final h in allow) {
      if (host == h || host.endsWith('.$h')) return true;
    }
    // Fallback embeds often load stream CDNs — allow media extensions.
    if (!popcorn) {
      final path = uri.path.toLowerCase();
      if (path.endsWith('.m3u8') ||
          path.endsWith('.mp4') ||
          path.endsWith('.ts') ||
          path.endsWith('.vtt') ||
          path.endsWith('.srt') ||
          path.contains('/playlist') ||
          path.contains('/manifest')) {
        return !isAdUrl(url);
      }
    }
    return false;
  }

  /// CSS + known-ad iframe/script removal. Avoids nuking player DOM.
  static const hideAdsJs = r'''
(function () {
  if (window.__WOLF_AD_HIDE_V3__) return;
  window.__WOLF_AD_HIDE_V3__ = true;

  var css = document.createElement('style');
  css.id = 'wolf-ad-hide';
  css.textContent = `
    iframe[src*="doubleclick"], iframe[src*="googlesyndication"],
    iframe[src*="imasdk"], iframe[src*="adnxs"], iframe[src*="popads"],
    iframe[src*="exoclick"], iframe[src*="juicyads"], iframe[src*="propeller"],
    iframe[src*="adskeeper"], iframe[src*="adsterra"], iframe[id*="google_ads"],
    [id*="google_ads"], [id*="adsense"], [class*="adsbygoogle"],
    .vturb-ad, .video-ads, .ima-ad-container, .ima-sdk-frame,
    .jw-plugin-ads, .ytp-ad-module, .fc-consent-root {
      display: none !important; visibility: hidden !important;
      pointer-events: none !important; opacity: 0 !important;
      width: 0 !important; height: 0 !important; max-height: 0 !important;
    }
  `;
  (document.head || document.documentElement).appendChild(css);

  function scrub() {
    try {
      document.querySelectorAll('iframe, script').forEach(function (el) {
        var src = (el.getAttribute('src') || '').toLowerCase();
        if (!src) return;
        if (
          src.indexOf('doubleclick') !== -1 ||
          src.indexOf('googlesyndication') !== -1 ||
          src.indexOf('imasdk') !== -1 ||
          src.indexOf('adnxs') !== -1 ||
          src.indexOf('popads') !== -1 ||
          src.indexOf('exoclick') !== -1 ||
          src.indexOf('juicyads') !== -1 ||
          src.indexOf('propeller') !== -1 ||
          src.indexOf('adskeeper') !== -1
        ) {
          try { el.remove(); } catch (e) {}
        }
      });
      document.querySelectorAll('button, a, [role="button"]').forEach(function (el) {
        var t = ((el.textContent || '') + ' ' + (el.getAttribute('aria-label') || '')).toLowerCase().trim();
        if (t.indexOf('skip ad') !== -1 || t === 'skip ads') {
          try { el.click(); } catch (e) {}
        }
      });
    } catch (e) {}
  }

  scrub();
  setInterval(scrub, 1200);

  try { window.open = function () { return null; }; } catch (e) {}
})();
''';

  /// Stop click-through overlays from navigating the WebView to a white ad page.
  static const trapClicksJs = r'''
(function () {
  if (window.__WOLF_TRAP_CLICKS__) return;
  window.__WOLF_TRAP_CLICKS__ = true;

  function isBadLink(href) {
    if (!href) return false;
    var h = String(href).toLowerCase();
    if (h === '#' || h.indexOf('javascript:') === 0) return false;
    if (h.indexOf('about:blank') !== -1) return true;
    if (h.indexOf('doubleclick') !== -1) return true;
    if (h.indexOf('popads') !== -1 || h.indexOf('exoclick') !== -1) return true;
    try {
      var u = new URL(h, location.href);
      if (u.hostname && u.hostname !== location.hostname &&
          u.hostname.indexOf('salku434jeb.com') === -1 &&
          u.hostname.indexOf('tmdbsrcimg.site') === -1 &&
          u.hostname.indexOf('jam01su.site') === -1 &&
          u.hostname.indexOf('elochkaigolochla.com') === -1 &&
          u.hostname.indexOf('cloudflare') === -1 &&
          u.hostname.indexOf('jsdelivr') === -1) {
        return true;
      }
    } catch (e) {}
    return false;
  }

  document.addEventListener('click', function (ev) {
    try {
      var t = ev.target;
      for (var i = 0; i < 5 && t; i++) {
        if (t.tagName === 'A') {
          var href = t.getAttribute('href') || '';
          if (isBadLink(href) || t.getAttribute('target') === '_blank') {
            ev.preventDefault();
            ev.stopPropagation();
            return false;
          }
        }
        t = t.parentElement;
      }
    } catch (e) {}
  }, true);

  try { window.open = function () { return null; }; } catch (e) {}
})();
''';

  /// Optional cinema helpers for Popcorn watch pages (unused for HLS primary).
  static const popcornCinemaJs = r'''
(function () {
  if (window.__WOLF_POPCORN_CINEMA__) return;
  window.__WOLF_POPCORN_CINEMA__ = true;
  try {
    var v = document.querySelector('video');
    if (v) {
      v.setAttribute('playsinline', 'true');
      var p = v.play();
      if (p && p.catch) p.catch(function () {});
    }
  } catch (e) {}
})();
''';
}
