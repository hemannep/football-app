// lib/features/home/home_screen.dart
//
// Updates:
//   • Coming Soon cards now use the shared TeamCrestWidget — so club crests
//     (PL, La Liga, etc.) render reliably, national teams get country flags,
//     and unknown clubs get a styled initials badge (no broken images).

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
import '../../core/theme/app_theme.dart';

import '../../shared/models/match.dart';
import '../../shared/widgets/match_card.dart';
import '../../shared/widgets/team_crest_widget.dart';
import '../league picker/league_picker.dart';
import '../match details/match_details_screen.dart' hide SectionLabel;
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
    if (picked != null) {
      setState(() => _selectedDay = picked);
    }
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

    // Build tla→crest map for the favorites strip (uses all matches, not just today).
    final crestByTla = <String, String?>{};
    for (final m in s.matches) {
      crestByTla[m.homeTeam.tla] ??= m.homeTeam.crest;
      crestByTla[m.awayTeam.tla] ??= m.awayTeam.crest;
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

    final liveCount = s.matches.where((m) => m.isLive).length;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const SettingsDrawer(),
      body: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: () => ref.read(liveScoreProvider.notifier).forceRefresh(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: p.bg,
              leading: IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: AppTheme.brandGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sports_soccer,
                        color: Colors.black, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('FootballHub',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  if (liveCount > 0) ...[
                    const SizedBox(width: 8),
                    _LiveBadge(count: liveCount),
                  ],
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded),
                  onPressed: () =>
                      ref.read(themeModeProvider.notifier).toggle(),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  children: [
                    const LeaguePickerChip(),
                    const Spacer(),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    freshnessLabel,
                    style: TextStyle(fontSize: 10, color: p.textLow),
                  ),
                ),
              ),
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
            // ── Engagement extras (orphan widgets we wire here) ────────────
            const SliverToBoxAdapter(child: WelcomeBackRecap()),
            const SliverToBoxAdapter(child: XpProgressBar()),
            const SliverToBoxAdapter(child: DailyFactCard()),
            const SliverToBoxAdapter(child: OnThisDayCard()),
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
                            children: favorites
                                .take(8)
                                .map((tla) => Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TeamCrestWidget(
                                            crestUrl: crestByTla[tla],
                                            tla: tla,
                                            size: 26,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(tla,
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: p.textMid)),
                                        ],
                                      ),
                                    ))
                                .toList(),
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
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => MatchDetailsScreen(match: m)),
                    ),
                  );
                },
              ),
            ],
            if (upcomingMatches.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text(
                        '🕐  COMING SOON',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brand,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· tap a card to jump to that day',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: p.textLow,
                        ),
                      ),
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
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MatchDetailsScreen(match: m),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ],
            SliverToBoxAdapter(
              child: SectionLabel(
                dayMatches.isEmpty
                    ? _dayLabel(_selectedDay, league.name)
                    : '${_dayLabel(_selectedDay, league.name)}  ·  ${dayMatches.length}',
              ),
            ),
            if (s.isLoading && s.matches.isEmpty)
              const SliverToBoxAdapter(child: _SkeletonList()),
            if (!s.isLoading && dayMatches.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyDay(date: _selectedDay),
              ),
            // ── Matches grouped by competition ─────────────────────────
            Builder(builder: (context) {
              // Group by competition, preserving time-sort order.
              final seen = <String>{};
              final compOrder = <String>[];
              final grouped = <String, List<Match>>{};
              for (final m in dayMatches) {
                final key = m.competitionName ?? m.competitionCode ?? 'Other';
                if (seen.add(key)) compOrder.add(key);
                grouped.putIfAbsent(key, () => []).add(m);
              }
              // Flat list: alternating header + match items.
              final items = <({String? header, int liveCount, Match? match})>[];
              for (final comp in compOrder) {
                final live = grouped[comp]!.where((m) => m.isLive).length;
                items.add((header: comp, liveCount: live, match: null));
                for (final m in grouped[comp]!) {
                  items.add((header: null, liveCount: 0, match: m));
                }
              }
              return SliverList.builder(
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  if (item.header != null) {
                    return _CompetitionHeader(
                        name: item.header!, liveCount: item.liveCount);
                  }
                  final m = item.match!;
                  return MatchCard(
                    match: m,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MatchDetailsScreen(match: m),
                      ),
                    ),
                  );
                },
              );
            }),
            if (s.lastUpdated != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Updated ${_ago(s.lastUpdated!)}',
                      style: TextStyle(fontSize: 11, color: p.textLow),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  String _dayLabel(DateTime d, String leagueName) {
    final today = DateTime.now();
    final isToday =
        d.year == today.year && d.month == today.month && d.day == today.day;
    final prefix = isToday ? "Today's" : DateFormat('d MMM').format(d);
    return '$prefix matches  •  $leagueName';
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt).inSeconds;
    if (d < 60) return '${d}s ago';
    if (d < 3600) return '${d ~/ 60}m ago';
    return '${d ~/ 3600}h ago';
  }
}

// ─── Live badge (pulsing dot + count) ───────────────────────────────────────

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

// ─── Coming Soon Card ───────────────────────────────────────────────────────

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
              crestUrl: t.crest,
              tla: t.tla,
              name: t.name,
              size: 28,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            t.tla,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: palette.textHi,
            ),
            overflow: TextOverflow.ellipsis,
          ),
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
                  child: Text(
                    'vs',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: palette.textLow,
                    ),
                  ),
                ),
                _team(match.awayTeam, reverse: true),
              ],
            ),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 11, color: palette.textLow),
                const SizedBox(width: 4),
                Text(
                  _kickoffTime(match.utcDate),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.textLow,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Date strip ─────────────────────────────────────────────────────────────

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

// ─── Helpers ────────────────────────────────────────────────────────────────

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
          children: List.generate(4, (i) {
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
                    // Stage chip placeholder
                    Container(
                      width: 60,
                      height: 10,
                      decoration: BoxDecoration(
                        color: p.surfaceHi.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Home team
                        Container(width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: p.surfaceHi.withValues(alpha: opacity),
                              borderRadius: BorderRadius.circular(6))),
                        const SizedBox(width: 8),
                        Container(width: 70, height: 10,
                            decoration: BoxDecoration(
                              color: p.surfaceHi.withValues(alpha: opacity),
                              borderRadius: BorderRadius.circular(4))),
                        const Spacer(),
                        // Score box
                        Container(width: 68, height: 34,
                            decoration: BoxDecoration(
                              color: p.surfaceHi.withValues(alpha: opacity),
                              borderRadius: BorderRadius.circular(8))),
                        const Spacer(),
                        // Away team
                        Container(width: 70, height: 10,
                            decoration: BoxDecoration(
                              color: p.surfaceHi.withValues(alpha: opacity),
                              borderRadius: BorderRadius.circular(4))),
                        const SizedBox(width: 8),
                        Container(width: 28, height: 28,
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
                color: p.surfaceHi,
                borderRadius: BorderRadius.circular(16),
              ),
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

// ─── Competition group header ────────────────────────────────────────────────

class _CompetitionHeader extends StatelessWidget {
  final String name;
  final int liveCount;
  const _CompetitionHeader({required this.name, this.liveCount = 0});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: liveCount > 0 ? AppTheme.live : AppTheme.brand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: p.textMid,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (liveCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          ],
        ],
      ),
    );
  }
}

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
