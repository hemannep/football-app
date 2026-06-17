// lib/features/home/home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football_fan_hub_2026/features/settings_drawer.dart';
import 'package:intl/intl.dart';
import '../../core/providers/live_score_provider.dart';
import '../../core/providers/favorites_provider.dart';
import '../../core/providers/selected_leagues_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/live_data_service.dart';
import '../../core/services/user_profile_service.dart';
import '../../core/theme/app_theme.dart';

import '../../shared/models/match.dart';
import '../../shared/widgets/inline_banner_ad.dart';
import '../../shared/widgets/match_card.dart';
import '../../shared/widgets/team_crest_widget.dart';
import '../league picker/league_picker.dart';
import '../match details/match_details_screen.dart' hide SectionLabel;
import '../team details/team_details_screen.dart';
import 'home_extras_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  DateTime _selectedDay = DateTime.now();
  Timer? _tick;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final n = ref.read(liveScoreProvider.notifier);
    if (state == AppLifecycleState.paused) n.pausePolling();
    if (state == AppLifecycleState.resumed) n.resumePolling();
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime(2027, 12, 31),
    );
    if (picked != null) setState(() => _selectedDay = picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final s = ref.watch(liveScoreProvider);
    final league = ref.watch(selectedLeagueProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final favorites = ref.watch(favoritesProvider).teamTlas;
    final freshnessLabel =
        ref.watch(relayMetaProvider).asData?.value.freshnessLabel ?? '';

    final now = DateTime.now();

    final dayMatches = s.matches.where((m) => m.sameDay(_selectedDay)).toList()
      ..sort((a, b) => a.utcDate.compareTo(b.utcDate));

    final favMatches = s.matches
        .where((m) =>
            favorites.contains(m.homeTeam.tla) ||
            favorites.contains(m.awayTeam.tla))
        .where((m) => !m.isFinished || m.sameDay(DateTime.now()))
        .toList()
      ..sort((a, b) => a.utcDate.compareTo(b.utcDate));

    final crestByTla = <String, String?>{};
    final idByTla = <String, int>{};
    for (final m in s.matches) {
      crestByTla[m.homeTeam.tla] ??= m.homeTeam.crest;
      crestByTla[m.awayTeam.tla] ??= m.awayTeam.crest;
      if (m.homeTeam.id != null) idByTla[m.homeTeam.tla] ??= m.homeTeam.id!;
      if (m.awayTeam.id != null) idByTla[m.awayTeam.tla] ??= m.awayTeam.id!;
    }

    final comingSoon = s.matches
        .where((m) =>
            !m.isLive &&
            !m.isFinished &&
            m.utcDate.toLocal().isAfter(now) &&
            !m.sameDay(_selectedDay))
        .toList()
      ..sort((a, b) => a.utcDate.compareTo(b.utcDate));
    final upcomingMatches = comingSoon.take(3).toList();

    final liveMatches = s.matches.where((m) => m.isLive).toList();
    final liveCount = liveMatches.length;

    // Time-based greeting + real user name
    final rawName = UserProfileService.instance.localName;
    final displayName = rawName.isNotEmpty ? rawName : 'Football Fan';
    final hour = DateTime.now().hour;
    final greetWord = hour < 5
        ? 'Good night'
        : hour < 12
            ? 'Good morning'
            : hour < 17
                ? 'Good afternoon'
                : hour < 22
                    ? 'Good evening'
                    : 'Good night';
    final greetEmoji = hour < 5
        ? '🌙'
        : hour < 12
            ? '☀️'
            : hour < 17
                ? '⛅'
                : hour < 22
                    ? '🌆'
                    : '🌙';

    // Prefer a live match for the hero; fall back to next upcoming.
    final Match? featuredMatch = liveMatches.isNotEmpty
        ? liveMatches.first
        : comingSoon.isNotEmpty
            ? comingSoon.first
            : null;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const SettingsDrawer(),
      backgroundColor:
          isDark ? const Color(0xFF0B1510) : const Color(0xFFF2F8F3),
      body: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: () => ref.read(liveScoreProvider.notifier).forceRefresh(),
        child: CustomScrollView(
          slivers: [
            // ── Custom top bar ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: _TopBar(
                  liveCount: liveCount,
                  palette: p,
                  onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                  onToggleTheme: () =>
                      ref.read(themeModeProvider.notifier).toggle(),
                  isDark: isDark,
                ),
              ),
            ),
            // ── Hero greeting ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greetWord, $displayName $greetEmoji',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: p.textHi,
                        height: 1.2,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Get live scores, detailed stats, and instant\nmatch alerts around the world.',
                      style: TextStyle(
                        fontSize: 13,
                        color: p.textMid,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Featured match hero card ───────────────────────────────────
            if (featuredMatch != null)
              SliverToBoxAdapter(
                child: _HeroMatchCard(
                  match: featuredMatch,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          MatchDetailsScreen(match: featuredMatch))),
                ),
              ),
            // ── League picker + match count ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    const LeaguePickerChip(),
                    const Spacer(),
                    if (s.matches.isNotEmpty)
                      Text(
                        '${s.matches.length} matches',
                        style: TextStyle(
                            color: p.textLow,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ),
            if (freshnessLabel.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(freshnessLabel,
                      style: TextStyle(fontSize: 10, color: p.textLow)),
                ),
              ),
            // ── Pinned date strip ──────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _DateStripDelegate(
                selected: _selectedDay,
                onPick: (d) => setState(() => _selectedDay = d),
                onCalendar: _pickDate,
                palette: p,
                matchDays: {
                  ...s.matches.map((m) {
                    final d = m.utcDate.toLocal();
                    return DateTime(d.year, d.month, d.day);
                  })
                },
                liveDays: {
                  ...s.matches.where((m) => m.isLive).map((m) {
                    final d = m.utcDate.toLocal();
                    return DateTime(d.year, d.month, d.day);
                  })
                },
              ),
            ),
            // ── Engagement extras ──────────────────────────────────────────
            const SliverToBoxAdapter(child: WelcomeBackRecap()),
            const SliverToBoxAdapter(child: XpProgressBar()),
            // ── Favorites ─────────────────────────────────────────────────
            if (favMatches.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                  child: Row(
                    children: [
                      const Text('⭐  YOUR FAVORITES',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AppTheme.brand)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: favorites.take(8).map((tla) {
                              final teamId = idByTla[tla];
                              return GestureDetector(
                                onTap: teamId != null
                                    ? () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => TeamDetailScreen(
                                              teamId: teamId,
                                              fallbackName: tla,
                                              fallbackTla: tla,
                                            ),
                                          ),
                                        )
                                    : null,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TeamCrestWidget(
                                          crestUrl: crestByTla[tla],
                                          tla: tla,
                                          size: 28),
                                      const SizedBox(height: 3),
                                      Text(tla,
                                          style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: p.textMid)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: favMatches.take(5).length,
                itemBuilder: (_, i) {
                  final m = favMatches[i];
                  return MatchCard(
                    match: m,
                    showDate: true,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MatchDetailsScreen(match: m))),
                  );
                },
              ),
            ],
            // ── Coming Soon ────────────────────────────────────────────────
            if (upcomingMatches.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text('🕐  COMING SOON',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brand,
                              letterSpacing: 1.1)),
                      const SizedBox(width: 8),
                      Text('· tap a card to jump to that day',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: p.textLow)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 148,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: upcomingMatches.length,
                    itemBuilder: (_, i) {
                      final m = upcomingMatches[i];
                      return _ComingSoonCard(
                        match: m,
                        palette: p,
                        onTap: () {
                          final matchDay = m.utcDate.toLocal();
                          setState(() => _selectedDay = DateTime(
                              matchDay.year, matchDay.month, matchDay.day));
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => MatchDetailsScreen(match: m)));
                        },
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ],
            // ── Today's Matches header ─────────────────────────────────────
            SliverToBoxAdapter(
              child: _TodayMatchesHeader(
                dayLabel: _dayLabel(_selectedDay),
                leagueName: league.name,
                count: dayMatches.length,
              ),
            ),
            // ── Match list (loading / empty / grouped) ─────────────────────
            if (s.isLoading && s.matches.isEmpty)
              const SliverToBoxAdapter(child: _SkeletonList()),
            if (!s.isLoading && dayMatches.isEmpty)
              SliverToBoxAdapter(child: _EmptyDay(date: _selectedDay)),
            Builder(builder: (context) {
              final seen = <String>{};
              final compOrder = <String>[];
              final grouped = <String, List<Match>>{};
              for (final m in dayMatches) {
                final key = m.competitionName ?? m.competitionCode ?? 'Other';
                if (seen.add(key)) compOrder.add(key);
                grouped.putIfAbsent(key, () => []).add(m);
              }
              // isAd=true items inject an inline banner every 3 competitions.
              final items = <({
                String? header,
                int liveCount,
                Match? match,
                bool isAd
              })>[];
              var compIdx = 0;
              for (final comp in compOrder) {
                if (compIdx > 0 && compIdx % 3 == 0) {
                  items.add(
                      (header: null, liveCount: 0, match: null, isAd: true));
                }
                compIdx++;
                final live = grouped[comp]!.where((m) => m.isLive).length;
                items.add(
                    (header: comp, liveCount: live, match: null, isAd: false));
                for (final m in grouped[comp]!) {
                  items
                      .add((header: null, liveCount: 0, match: m, isAd: false));
                }
              }
              return SliverList.builder(
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  if (item.isAd) return const InlineBannerAd();
                  if (item.header != null) {
                    return _CompetitionHeader(
                        name: item.header!, liveCount: item.liveCount);
                  }
                  final m = item.match!;
                  return MatchCard(
                    match: m,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MatchDetailsScreen(match: m))),
                  );
                },
              );
            }),
            if (s.lastUpdated != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text('Updated ${_ago(s.lastUpdated!)}',
                        style: TextStyle(fontSize: 11, color: p.textLow)),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  String _dayLabel(DateTime d) {
    final today = DateTime.now();
    final isToday =
        d.year == today.year && d.month == today.month && d.day == today.day;
    return isToday ? "Today's Matches" : DateFormat('d MMM').format(d);
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt).inSeconds;
    if (d < 60) return '${d}s ago';
    if (d < 3600) return '${d ~/ 60}m ago';
    return '${d ~/ 3600}h ago';
  }
}

// ─── Custom top bar ──────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int liveCount;
  final bool isDark;
  final Palette palette;
  final VoidCallback onMenu;
  final VoidCallback onToggleTheme;

  const _TopBar({
    required this.liveCount,
    required this.isDark,
    required this.palette,
    required this.onMenu,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          // Grid / menu icon
          GestureDetector(
            onTap: onMenu,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: p.surfaceHi,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.stroke),
              ),
              child: Icon(Icons.grid_view_rounded, color: p.textMid, size: 20),
            ),
          ),
          const Spacer(),
          // Notification bell with live dot
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: p.surfaceHi,
                shape: BoxShape.circle,
                border: Border.all(color: p.stroke),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(Icons.notifications_outlined,
                        color: p.textMid, size: 20),
                  ),
                  if (liveCount > 0)
                    Positioned(
                      right: 9,
                      top: 9,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.live,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar / theme toggle
          GestureDetector(
            onTap: onToggleTheme,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                gradient: AppTheme.brandGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero featured match card ─────────────────────────────────────────────────

class _HeroMatchCard extends StatelessWidget {
  final Match match;
  final VoidCallback onTap;

  const _HeroMatchCard({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLive = match.isLive;
    final isFinished = match.isFinished;
    final isHt = match.status == 'PAUSED';

    int? liveMin;
    if (isLive) {
      final elapsed = DateTime.now().difference(match.utcDate).inMinutes;
      liveMin = match.minute ??
          (elapsed < 55
                  ? elapsed
                  : elapsed < 105
                      ? elapsed - 15
                      : elapsed - 30)
              .clamp(1, 120);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF163324), Color(0xFF0C1E32)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isLive
                ? AppTheme.live.withValues(alpha: 0.55)
                : AppTheme.brand.withValues(alpha: 0.30),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isLive ? AppTheme.live : AppTheme.brand)
                  .withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Decorative pitch-circle rings
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04), width: 32),
                ),
              ),
            ),
            Positioned(
              left: -24,
              bottom: -24,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.03), width: 22),
                ),
              ),
            ),
            // Main content
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Competition name
                  Text(
                    match.competitionName ?? match.competitionCode ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // Live badge / kickoff time / FT
                  if (isLive)
                    _HeroLiveBadge(minute: isHt ? null : liveMin, isHt: isHt)
                  else if (!isFinished)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.brand.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        DateFormat('HH:mm  ·  d MMM')
                            .format(match.utcDate.toLocal()),
                        style: const TextStyle(
                          color: AppTheme.brand,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'FULL TIME',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  // Teams + score row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Home team
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.12)),
                              ),
                              child: TeamCrestWidget(
                                crestUrl: match.homeTeam.crest,
                                tla: match.homeTeam.tla,
                                name: match.homeTeam.name,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              match.homeTeam.tla,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Score / vs
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          isLive || isFinished ? match.score.display : 'vs',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.0,
                          ),
                        ),
                      ),
                      // Away team
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.12)),
                              ),
                              child: TeamCrestWidget(
                                crestUrl: match.awayTeam.crest,
                                tla: match.awayTeam.tla,
                                name: match.awayTeam.name,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              match.awayTeam.tla,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Group / stage subtitle
                  if (match.group != null || match.stage.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _stageLabel(match),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stageLabel(Match m) {
    if (m.group != null) {
      final g = m.group!.startsWith('GROUP_')
          ? 'Group ${m.group!.substring(6)}'
          : m.group!;
      return m.isLive ? 'Live · $g' : g;
    }
    final stage = m.stage
        .split('_')
        .map((p) => p.isEmpty ? p : p[0] + p.substring(1).toLowerCase())
        .join(' ');
    return m.isLive ? 'Live · $stage' : stage;
  }
}

// ─── Hero live badge (animated pulse) ────────────────────────────────────────

class _HeroLiveBadge extends StatefulWidget {
  final int? minute;
  final bool isHt;
  const _HeroLiveBadge({this.minute, required this.isHt});

  @override
  State<_HeroLiveBadge> createState() => _HeroLiveBadgeState();
}

class _HeroLiveBadgeState extends State<_HeroLiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isHt
        ? 'HT'
        : widget.minute != null
            ? "${widget.minute}'"
            : 'LIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        gradient: AppTheme.liveGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _c,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Today's Matches section header ──────────────────────────────────────────

class _TodayMatchesHeader extends StatelessWidget {
  final String dayLabel;
  final String leagueName;
  final int count;

  const _TodayMatchesHeader({
    required this.dayLabel,
    required this.leagueName,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: p.textHi,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  leagueName,
                  style: TextStyle(
                    fontSize: 12,
                    color: p.textLow,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppTheme.brand.withValues(alpha: 0.25)),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: AppTheme.brand,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Live badge (pulsing dot + count) ────────────────────────────────────────

class _LiveBadge extends StatefulWidget {
  final int count;
  const _LiveBadge({required this.count});
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: AppTheme.liveGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _c,
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 4),
          Text('${widget.count} LIVE',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

// ─── Coming Soon Card ─────────────────────────────────────────────────────────

class _ComingSoonCard extends StatelessWidget {
  final Match match;
  final Palette palette;
  final VoidCallback onTap;

  const _ComingSoonCard({
    required this.match,
    required this.palette,
    required this.onTap,
  });

  String _timeUntil(DateTime utcDate) {
    final local = utcDate.toLocal();
    final diff = local.difference(DateTime.now());
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'in ${diff.inHours}h';
    if (diff.inDays == 1) return 'Tomorrow';
    return DateFormat('d MMM').format(local);
  }

  String _kickoffTime(DateTime utcDate) =>
      DateFormat('HH:mm').format(utcDate.toLocal());

  Widget _team(TeamRef t, {required bool reverse}) => Column(
        crossAxisAlignment:
            reverse ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.surfaceHi,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.stroke),
            ),
            padding: const EdgeInsets.all(3),
            alignment: Alignment.center,
            child: TeamCrestWidget(
                crestUrl: t.crest, tla: t.tla, name: t.name, size: 28),
          ),
          const SizedBox(height: 5),
          Text(t.tla,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: palette.textHi),
              overflow: TextOverflow.ellipsis),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 210,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppTheme.r),
          border: Border.all(color: palette.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _timeUntil(match.utcDate),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _team(match.homeTeam, reverse: false),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('vs',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: palette.textLow)),
                ),
                _team(match.awayTeam, reverse: true),
              ],
            ),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 11, color: palette.textLow),
                const SizedBox(width: 4),
                Text(_kickoffTime(match.utcDate),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.textLow)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Date strip ───────────────────────────────────────────────────────────────

class _DateStripDelegate extends SliverPersistentHeaderDelegate {
  final DateTime selected;
  final ValueChanged<DateTime> onPick;
  final VoidCallback onCalendar;
  final Palette palette;
  final Set<DateTime> matchDays;
  final Set<DateTime> liveDays;

  _DateStripDelegate({
    required this.selected,
    required this.onPick,
    required this.onCalendar,
    required this.palette,
    this.matchDays = const {},
    this.liveDays = const {},
  });

  @override
  double get minExtent => 80;
  @override
  double get maxExtent => 80;

  @override
  bool shouldRebuild(_DateStripDelegate old) =>
      old.selected != selected ||
      old.palette.isDark != palette.isDark ||
      old.matchDays.length != matchDays.length ||
      old.liveDays.length != liveDays.length;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final diff = selected.difference(base).inDays;
    final start = diff.abs() > 3
        ? selected.subtract(const Duration(days: 3))
        : base.subtract(const Duration(days: 2));
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    return Container(
      color: palette.bg,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onCalendar,
            child: Container(
              width: 44,
              height: 56,
              margin: const EdgeInsets.only(left: 12, right: 6),
              decoration: BoxDecoration(
                color: palette.surfaceHi,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.stroke),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: AppTheme.brand, size: 20),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: days.length,
              itemBuilder: (_, i) {
                final d = days[i];
                final isSelected = _sameDay(d, selected);
                final isToday = _sameDay(d, today);
                final hasMatches = matchDays.any((md) => _sameDay(md, d));
                final hasLive = liveDays.any((ld) => _sameDay(ld, d));
                return GestureDetector(
                  onTap: () => onPick(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppTheme.brandGradient : null,
                      color: isSelected ? null : palette.surfaceHi,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppTheme.brand : palette.stroke,
                        width: isSelected ? 0 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isToday
                              ? 'TODAY'
                              : DateFormat('EEE').format(d).toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isSelected ? Colors.black : palette.textMid,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('d/MM').format(d),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.black : palette.textHi,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasMatches
                                ? (isSelected
                                    ? Colors.black.withValues(alpha: 0.5)
                                    : hasLive
                                        ? AppTheme.live
                                        : AppTheme.brand)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─── Skeleton loader ──────────────────────────────────────────────────────────

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();
  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final opacity = 0.4 + 0.6 * _c.value;
        return Column(
          children: List.generate(4, (_) {
            return Container(
              height: 84,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(AppTheme.r),
                border: Border.all(color: p.stroke),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 60,
                        height: 10,
                        decoration: BoxDecoration(
                            color: p.surfaceHi.withValues(alpha: opacity),
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                                color: p.surfaceHi.withValues(alpha: opacity),
                                borderRadius: BorderRadius.circular(6))),
                        const SizedBox(width: 8),
                        Container(
                            width: 70,
                            height: 10,
                            decoration: BoxDecoration(
                                color: p.surfaceHi.withValues(alpha: opacity),
                                borderRadius: BorderRadius.circular(4))),
                        const Spacer(),
                        Container(
                            width: 68,
                            height: 34,
                            decoration: BoxDecoration(
                                color: p.surfaceHi.withValues(alpha: opacity),
                                borderRadius: BorderRadius.circular(8))),
                        const Spacer(),
                        Container(
                            width: 70,
                            height: 10,
                            decoration: BoxDecoration(
                                color: p.surfaceHi.withValues(alpha: opacity),
                                borderRadius: BorderRadius.circular(4))),
                        const SizedBox(width: 8),
                        Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                                color: p.surfaceHi.withValues(alpha: opacity),
                                borderRadius: BorderRadius.circular(6))),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Empty day ────────────────────────────────────────────────────────────────

class _EmptyDay extends StatelessWidget {
  final DateTime date;
  const _EmptyDay({required this.date});
  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppTheme.r),
          border: Border.all(color: p.stroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: p.surfaceHi, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.event_busy_rounded, size: 26, color: p.textLow),
            ),
            const SizedBox(height: 12),
            Text(
              'No matches on ${DateFormat('d MMM').format(date)}',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: p.textMid),
            ),
            const SizedBox(height: 4),
            Text(
              'Try another day or switch the competition above.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: p.textLow),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Competition group header — Livescore style ───────────────────────────────

class _CompetitionHeader extends StatelessWidget {
  final String name;
  final int liveCount;
  const _CompetitionHeader({required this.name, this.liveCount = 0});

  static const _competitionColors = <String, Color>{
    'WC': Color(0xFF8B0000),
    'CL': Color(0xFF1A237E),
    'EL': Color(0xFFE65100),
    'ECL': Color(0xFF1B5E20),
    'EC': Color(0xFF004D40),
    'PL': Color(0xFF38003C),
    'BL1': Color(0xFFD32F2F),
    'PD': Color(0xFFFF6F00),
    'SA': Color(0xFF0D47A1),
    'FL1': Color(0xFF1565C0),
    'PPL': Color(0xFF006400),
  };

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    // Derive a color badge from competition name initial
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    // Try to match known codes in the name
    final badgeColor = _competitionColors.entries
            .where((e) => name.toUpperCase().contains(e.key))
            .map((e) => e.value)
            .firstOrNull ??
        AppTheme.brand.withValues(alpha: 0.6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                  color: p.stroke.withValues(alpha: 0.6), width: 0.5),
              bottom: BorderSide(
                  color: p.stroke.withValues(alpha: 0.3), width: 0.5),
            ),
            color: p.surfaceHi.withValues(alpha: 0.5),
          ),
          child: Row(
            children: [
              // Colored competition badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.textHi,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (liveCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.live,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$liveCount LIVE',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ] else ...[
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: p.textLow.withValues(alpha: 0.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section label (shared export) ───────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
              color: p.textLow)),
    );
  }
}
