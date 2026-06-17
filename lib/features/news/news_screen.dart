// lib/features/news/news_screen.dart
//
// Football news feed (NewsAPI primary + BBC RSS fallback).
// Clean magazine-style layout: hero card on top, list below.
//
// Access this screen from the Settings drawer entry "Football News".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/live_data_service.dart';
import '../../core/services/news_service.dart';
import '../../core/theme/app_theme.dart';

/// Converts a raw Firestore news map to a NewsArticle.
/// Handles Timestamp objects via duck-typing so we avoid importing cloud_firestore.
NewsArticle _articleFromMap(Map<String, dynamic> data) {
  DateTime publishedAt = DateTime.now();
  final ts = data['publishedAt'];
  if (ts != null) {
    try {
      publishedAt = (ts as dynamic).toDate().toLocal() as DateTime;
    } catch (_) {
      final ms = data['publishedAtMs'];
      if (ms is int) {
        publishedAt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
      } else if (ts is String) {
        publishedAt = DateTime.tryParse(ts)?.toLocal() ?? publishedAt;
      }
    }
  }
  return NewsArticle(
    title: (data['title'] ?? '') as String,
    description: data['description'] as String?,
    imageUrl: data['imageUrl'] as String?,
    source: data['source'] as String?,
    url: (data['link'] ?? data['url']) as String?,
    publishedAt: publishedAt,
  );
}

class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    // Convert raw Firestore maps → NewsArticle so the existing widgets work unchanged.
    final async = ref
        .watch(newsStreamProvider)
        .whenData((maps) => maps.map(_articleFromMap).toList());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Football News'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              LiveDataService.instance.evict('news_30');
              ref.invalidate(newsStreamProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: () async {
          LiveDataService.instance.evict('news_30');
          ref.invalidate(newsStreamProvider);
        },
        child: async.when(
          loading: () => const _NewsSkeleton(),
          error: (e, _) => _errorState(p, ref),
          data: (list) {
            if (list.isEmpty) return _errorState(p, ref);
            final hero = list.first;
            final rest = list.skip(1).toList();
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _HeroCard(article: hero),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Text('LATEST',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                          color: p.textLow)),
                ),
                ...rest.map((a) => _ArticleTile(article: a)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _errorState(Palette p, WidgetRef ref) => ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.cloud_off_rounded, size: 64, color: p.textLow),
          const SizedBox(height: 16),
          Center(
            child: Text('No news available right now',
                style: TextStyle(
                    color: p.textMid,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Pull to refresh, or check your connection.',
                style: TextStyle(color: p.textLow, fontSize: 12)),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () {
                LiveDataService.instance.evict('news_30');
                ref.invalidate(newsStreamProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
}

// ─── Hero card ──────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final NewsArticle article;
  const _HeroCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: InkWell(
        onTap: () => _open(article.url),
        borderRadius: BorderRadius.circular(AppTheme.r),
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppTheme.r),
            border: Border.all(color: p.stroke),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.imageUrl != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        article.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: p.surfaceHi,
                            child:
                                const Icon(Icons.image_not_supported_outlined)),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.45),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AppTheme.brandGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('TOP STORY',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1)),
                        ),
                        const SizedBox(width: 8),
                        if (article.source != null)
                          Text(article.source!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: p.textMid,
                                  fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text(_ago(article.publishedAt),
                            style: TextStyle(fontSize: 11, color: p.textLow)),
                        if (article.description != null) ...[
                          Text(' · ',
                              style: TextStyle(color: p.textLow, fontSize: 11)),
                          Text('${_readMin(article.description!)} min',
                              style: TextStyle(fontSize: 11, color: p.textLow)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 18,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: p.textHi)),
                    if (article.description != null) ...[
                      const SizedBox(height: 6),
                      Text(article.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, height: 1.35, color: p.textMid)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── List tile ──────────────────────────────────────────────────────────────

class _ArticleTile extends StatelessWidget {
  final NewsArticle article;
  const _ArticleTile({required this.article});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return InkWell(
      onTap: () => _open(article.url),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppTheme.r),
          border: Border.all(color: p.stroke),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 96,
                height: 72,
                child: article.imageUrl != null
                    ? Image.network(article.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: p.surfaceHi,
                            child:
                                Icon(Icons.image_outlined, color: p.textLow)))
                    : Container(
                        color: p.surfaceHi,
                        child: Icon(Icons.sports_soccer_rounded,
                            color: p.textLow)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: p.textHi)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (article.source != null) ...[
                        Flexible(
                          child: Text(article.source!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: p.textMid,
                                  fontWeight: FontWeight.w700)),
                        ),
                        Text(' • ',
                            style: TextStyle(color: p.textLow, fontSize: 10.5)),
                      ],
                      Text(_ago(article.publishedAt),
                          style: TextStyle(fontSize: 10.5, color: p.textLow)),
                      if (article.description != null) ...[
                        Text(' • ',
                            style: TextStyle(color: p.textLow, fontSize: 10.5)),
                        Text(
                          '${_readMin(article.description!)} min read',
                          style: TextStyle(fontSize: 10.5, color: p.textLow),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

int _readMin(String text) =>
    (text.trim().split(RegExp(r'\s+')).length / 200).ceil().clamp(1, 10);

String _ago(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return DateFormat('d MMM').format(dt);
}

Future<void> _open(String? url) async {
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─── Skeleton ───────────────────────────────────────────────────────────────

class _NewsSkeleton extends StatelessWidget {
  const _NewsSkeleton();
  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    Widget box(double h, double w) => Container(
          width: w,
          height: h,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: p.surfaceHi,
            borderRadius: BorderRadius.circular(8),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
              color: p.surfaceHi, borderRadius: BorderRadius.circular(12)),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < 6; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: p.surface,
                border: Border.all(color: p.stroke),
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Container(
                    width: 96,
                    height: 72,
                    decoration: BoxDecoration(
                        color: p.surfaceHi,
                        borderRadius: BorderRadius.circular(8))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      box(14, double.infinity),
                      box(14, 220),
                      box(10, 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
