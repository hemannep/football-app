// lib/core/services/news_service.dart
//
// Football news service.
//
//   PRIMARY :  NewsAPI.org "everything" endpoint (q=football, sortBy=publishedAt)
//   FALLBACK:  BBC Sport football RSS feed (no key, always works)
//
// The BBC RSS feed is parsed manually with a tiny regex pass — we deliberately
// don't add the `webfeed` package because its 0.7.0 release pulls in older
// deps that conflict on null-safety in some Flutter SDK channels.
//
// Everything is cached in Hive box `news_cache` for 30 minutes so users get
// instant news on cold start and the app works offline.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../constants/api_keys.dart';

class NewsArticle {
  final String title;
  final String? description;
  final String? imageUrl;
  final String? source;
  final String? url;
  final DateTime publishedAt;

  const NewsArticle({
    required this.title,
    this.description,
    this.imageUrl,
    this.source,
    this.url,
    required this.publishedAt,
  });

  factory NewsArticle.fromNewsApi(Map<String, dynamic> j) => NewsArticle(
        title: (j['title'] ?? '') as String,
        description: j['description'] as String?,
        imageUrl: j['urlToImage'] as String?,
        source: j['source']?['name'] as String?,
        url: j['url'] as String?,
        publishedAt:
            DateTime.tryParse(j['publishedAt'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'source': source,
        'url': url,
        'publishedAt': publishedAt.toIso8601String(),
      };

  factory NewsArticle.fromJson(Map<String, dynamic> j) => NewsArticle(
        title: j['title'] ?? '',
        description: j['description'],
        imageUrl: j['imageUrl'],
        source: j['source'],
        url: j['url'],
        publishedAt:
            DateTime.tryParse(j['publishedAt'] ?? '') ?? DateTime.now(),
      );
}

class NewsService {
  static const _cacheKey = 'football_news_v1';
  static const _cacheAtKey = 'football_news_v1_at';
  static const _cacheTtlMs = 30 * 60 * 1000; // 30 minutes

  /// Returns latest football news. Falls back to BBC RSS when NewsAPI fails.
  /// Always falls back to cached data when both fail.
  static Future<List<NewsArticle>> fetch({bool forceRefresh = false}) async {
    final box = Hive.box('matches_cache'); // reuse existing box
    final cached = box.get(_cacheKey);
    final cachedAt = box.get(_cacheAtKey);

    if (!forceRefresh && cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < _cacheTtlMs) return _decode(cached as String);
    }

    // 1) Try NewsAPI
    try {
      final list = await _fetchNewsApi();
      if (list.isNotEmpty) {
        await _store(box, list);
        return list;
      }
    } catch (_) {/* fall through */}

    // 2) Try BBC RSS
    try {
      final list = await _fetchBbcRss();
      if (list.isNotEmpty) {
        await _store(box, list);
        return list;
      }
    } catch (_) {/* fall through */}

    // 3) Last-resort: stale cache (may be > 30 min old)
    if (cached != null) return _decode(cached as String);
    return [];
  }

  // ─── NewsAPI ────────────────────────────────────────────────────────────

  static Future<List<NewsArticle>> _fetchNewsApi() async {
    if (ApiKeys.newsApi.isEmpty) return [];
    final uri = Uri.https('newsapi.org', '/v2/everything', {
      'q': 'football OR soccer',
      'language': 'en',
      'sortBy': 'publishedAt',
      'pageSize': '40',
      'apiKey': ApiKeys.newsApi,
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final arts = (body['articles'] as List?) ?? [];
    return arts
        .map((e) => NewsArticle.fromNewsApi(e as Map<String, dynamic>))
        .where((a) => a.title.isNotEmpty && a.title != '[Removed]')
        .toList();
  }

  // ─── BBC RSS fallback ──────────────────────────────────────────────────

  static Future<List<NewsArticle>> _fetchBbcRss() async {
    final res = await http
        .get(Uri.parse(ApiKeys.bbcFootballRss))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return [];
    return _parseRss(res.body, sourceName: 'BBC Sport');
  }

  /// Tiny RSS 2.0 parser — extracts `<item>` blocks and their core fields.
  /// We use regex (not a full XML parser) to avoid an extra dependency.
  static List<NewsArticle> _parseRss(String xml, {required String sourceName}) {
    final items = <NewsArticle>[];
    final itemRegex = RegExp(r'<item>([\s\S]*?)<\/item>', caseSensitive: false);
    final titleRegex = RegExp(
        r'<title>\s*(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?\s*<\/title>',
        caseSensitive: false);
    final descRegex = RegExp(
        r'<description>\s*(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?\s*<\/description>',
        caseSensitive: false);
    final linkRegex =
        RegExp(r'<link>\s*([\s\S]*?)\s*<\/link>', caseSensitive: false);
    final pubRegex =
        RegExp(r'<pubDate>\s*([\s\S]*?)\s*<\/pubDate>', caseSensitive: false);
    final imgRegex =
        RegExp(r'<media:thumbnail[^>]*url="([^"]+)"', caseSensitive: false);

    for (final m in itemRegex.allMatches(xml)) {
      final block = m.group(1) ?? '';
      final title = titleRegex.firstMatch(block)?.group(1)?.trim() ?? '';
      if (title.isEmpty) continue;
      items.add(NewsArticle(
        title: title,
        description: descRegex.firstMatch(block)?.group(1)?.trim(),
        url: linkRegex.firstMatch(block)?.group(1)?.trim(),
        imageUrl: imgRegex.firstMatch(block)?.group(1)?.trim(),
        source: sourceName,
        publishedAt:
            _parseRssDate(pubRegex.firstMatch(block)?.group(1)?.trim()),
      ));
    }
    return items;
  }

  static DateTime _parseRssDate(String? raw) {
    if (raw == null || raw.isEmpty) return DateTime.now();
    // RFC 822: "Fri, 22 May 2026 15:39:00 GMT" — DateTime.tryParse handles it.
    return DateTime.tryParse(raw) ?? _rfc822(raw) ?? DateTime.now();
  }

  static DateTime? _rfc822(String s) {
    try {
      final months = {
        'Jan': 1,
        'Feb': 2,
        'Mar': 3,
        'Apr': 4,
        'May': 5,
        'Jun': 6,
        'Jul': 7,
        'Aug': 8,
        'Sep': 9,
        'Oct': 10,
        'Nov': 11,
        'Dec': 12,
      };
      final m =
          RegExp(r'(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})')
              .firstMatch(s);
      if (m == null) return null;
      return DateTime.utc(
        int.parse(m.group(3)!),
        months[m.group(2)] ?? 1,
        int.parse(m.group(1)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6)!),
      ).toLocal();
    } catch (_) {
      return null;
    }
  }

  // ─── Cache helpers ─────────────────────────────────────────────────────

  static List<NewsArticle> _decode(String raw) => (jsonDecode(raw) as List)
      .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
      .toList();

  static Future<void> _store(Box box, List<NewsArticle> list) async {
    await box.put(_cacheKey, jsonEncode(list.map((a) => a.toJson()).toList()));
    await box.put(_cacheAtKey, DateTime.now().millisecondsSinceEpoch);
  }
}
