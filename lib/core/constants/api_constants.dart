import '../services/firebase_service.dart';

class ApiConstants {
  // Cloudflare Worker proxy — keys never ship in the APK.
  // Remote Config overrides this at runtime; dart-define overrides for CI/dev.
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_PROXY_BASE_URL',
    defaultValue:
        'https://football-fan-hub-proxy.footballapp.workers.dev/api/fd/v4',
  );

  static String get baseUrl {
    final remote = FirebaseService.instance.apiBaseUrl.trim();
    return remote.isNotEmpty ? remote : _defaultBaseUrl;
  }

  // Token is only needed when NOT going through the Worker (e.g. local dev
  // with --dart-define=API_PROXY_BASE_URL=direct).  In production the Worker
  // injects FD_TOKEN server-side so this stays empty in release builds.
  static const String token = String.fromEnvironment('FD_TOKEN');
  static const String competitionCode = 'WC';
  // flagcdn.com — free CDN for nation flags
  static const String flagBase = 'https://flagcdn.com/w80';
}
