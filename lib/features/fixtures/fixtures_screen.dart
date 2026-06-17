import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/live_score_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/live_data_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/match.dart' show Match;
import '../../shared/widgets/inline_banner_ad.dart';
import '../../shared/widgets/match_card.dart';
import '../league picker/league_picker.dart';
import '../match details/match_details_screen.dart';

class FixturesScreen extends ConsumerStatefulWidget {
  const FixturesScreen({super.key});
  @override
  ConsumerState<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends ConsumerState<FixturesScreen> {
  String _query = '';
  String _stage = 'ALL';
  String _filter = 'ALL';
  final _searchCtrl = TextEditingController();

  static const _filters = [
    ('All', 'ALL'),
    ('🔴 Live', 'LIVE'),
    ('Upcoming', 'UPCOMING'),
    ('Finished', 'FINISHED'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final s = ref.watch(liveScoreProvider);
    final freshnessLabel =
        ref.watch(relayMetaProvider).asData?.value.freshnessLabel ?? '';

    final liveCount = s.matches.where((m) => m.isLive).length;
    final stages = [
      'ALL',
      ...{...s.matches.map((m) => m.stage)}
    ];

    final list = s.matches.where((m) {
      final mq = _query.isEmpty ||
          m.homeTeam.name.toLowerCase().contains(_query.toLowerCase()) ||
          m.awayTeam.name.toLowerCase().contains(_query.toLowerCase()) ||
          m.homeTeam.tla.toLowerCase().contains(_query.toLowerCase()) ||
          m.awayTeam.tla.toLowerCase().contains(_query.toLowerCase());
      final ms = _stage == 'ALL' || m.stage == _stage;
      final mf = switch (_filter) {
        'LIVE' => m.isLive,
        'UPCOMING' => m.isScheduled,
        'FINISHED' => m.isFinished,
        _ => true,
      };
      return mq && ms && mf;
    }).toList()
      ..sort((a, b) => a.utcDate.compareTo(b.utcDate));

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1510) : const Color(0xFFF2F8F3),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fixtures',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            color: p.textHi,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${s.matches.length} matches',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: p.textLow,
                                  fontWeight: FontWeight.w500),
                            ),
                            if (liveCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.liveGradient,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$liveCount LIVE',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const LeaguePickerChip(),
                ],
              ),
            ),
            if (freshnessLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 4),
                child: Text(freshnessLabel,
                    style: TextStyle(fontSize: 10, color: p.textLow)),
              ),
            // ── Search bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.stroke),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(color: p.textHi, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search team or country…',
                    hintStyle: TextStyle(color: p.textLow, fontSize: 14),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: p.textLow, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 18, color: p.textLow),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                  ),
                ),
              ),
            ),
            // ── Status filter pills ───────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: _filters.map((f) {
                  final sel = _filter == f.$2;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f.$2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: sel ? AppTheme.brandGradient : null,
                        color: sel ? null : p.surfaceHi,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: sel ? AppTheme.brand : p.stroke),
                      ),
                      child: Text(
                        f.$1,
                        style: TextStyle(
                          color: sel ? Colors.black : p.textMid,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // ── Stage filter (only when multiple stages exist) ────────────
            if (stages.length > 2) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: stages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final st = stages[i];
                    final sel = st == _stage;
                    return GestureDetector(
                      onTap: () => setState(() => _stage = st),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppTheme.brand.withValues(alpha: 0.12)
                              : p.surfaceHi,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: sel
                                ? AppTheme.brand.withValues(alpha: 0.5)
                                : p.stroke,
                          ),
                        ),
                        child: Text(
                          _prettyStage(st),
                          style: TextStyle(
                            color: sel ? AppTheme.brand : p.textMid,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 4),
            // ── Match list (with inline ads every 3 date groups) ──────────
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.brand,
                onRefresh: () =>
                    ref.read(liveScoreProvider.notifier).forceRefresh(),
                child: list.isEmpty
                    ? _empty(p, s.isLoading)
                    : Builder(builder: (ctx) {
                        // Pre-build flat list with ad slots.
                        final flatItems =
                            <({Match? match, bool isAd, bool showHeader})>[];
                        DateTime? lastDate;
                        var dateGroupCount = 0;
                        for (final m in list) {
                          final newDate = lastDate == null ||
                              !_sameDay(lastDate, m.utcDate);
                          if (newDate) {
                            if (dateGroupCount > 0 && dateGroupCount % 3 == 0) {
                              flatItems.add(
                                  (match: null, isAd: true, showHeader: false));
                            }
                            dateGroupCount++;
                            lastDate = m.utcDate;
                          }
                          flatItems.add(
                              (match: m, isAd: false, showHeader: newDate));
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24, top: 4),
                          itemCount: flatItems.length,
                          itemBuilder: (_, i) {
                            final item = flatItems[i];
                            if (item.isAd) return const InlineBannerAd();
                            final m = item.match!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.showHeader) _dateHeader(p, m.utcDate),
                                MatchCard(
                                  match: m,
                                  onTap: () => Navigator.of(ctx).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          MatchDetailsScreen(match: m),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateHeader(Palette p, DateTime dt) {
    final isToday = _sameDay(dt, DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: isToday ? AppTheme.brand : p.textLow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isToday
                ? 'TODAY  ·  ${DateFormat('d MMM').format(dt).toUpperCase()}'
                : DateFormat('EEE, d MMM').format(dt).toUpperCase(),
            style: TextStyle(
              color: isToday ? AppTheme.brand : p.textMid,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(Palette p, bool loading) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: p.surfaceHi,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                loading
                    ? Icons.hourglass_top_rounded
                    : Icons.search_off_rounded,
                size: 32,
                color: p.textLow,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              loading ? 'Loading fixtures…' : 'No matches found',
              style: TextStyle(
                  color: p.textMid, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            if (!loading) ...[
              const SizedBox(height: 6),
              Text(
                'Try adjusting your search or filters.',
                style: TextStyle(fontSize: 12, color: p.textLow),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _prettyStage(String s) {
    if (s == 'ALL') return 'All stages';
    return s
        .split('_')
        .map((p) => p.isEmpty ? p : p[0] + p.substring(1).toLowerCase())
        .join(' ');
  }
}
