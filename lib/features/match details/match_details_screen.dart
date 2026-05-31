// lib/features/match_details/match_details_screen.dart
//
// Match details screen — fragmented for easy editing.
//
// This is the LIBRARY ROOT. It holds the imports, the Riverpod providers,
// the screen scaffold (MatchDetailsScreen) and its hero header. Each tab and
// the shared widgets live in separate `part` files so you can edit one tab
// without scrolling through the whole screen:
//
//   match_details_screen.dart   ← you are here (providers + scaffold + hero)
//   match_details_shared.dart   ← DetailCard, SectionLabel, Unavailable, etc.
//   tabs/summary_tab.dart       ← Summary tab + live ticker + incident rows
//   tabs/lineups_tab.dart       ← Lineups tab + pitch view + columns
//   tabs/stats_tab.dart         ← Stats tab + momentum graph + stat bars
//   tabs/h2h_tab.dart           ← Head-to-head tab
//   tabs/standings_tab.dart     ← Standings tab
//
// Because they are `part` files, every class shares ONE library — the
// `_private` widgets and the `_lineupsProvider` etc. are visible across all
// fragments with no extra exports. To add a new tab: create a new part file,
// add a `part 'tabs/your_tab.dart';` line below, and reference it from the
// TabBarView in the scaffold.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers/live_score_provider.dart';
import '../../core/providers/favorites_provider.dart';
import '../../core/providers/match_goal_provider.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/extras_service.dart';
import '../../core/services/live_data_service.dart';
import '../../core/services/match_details_resolver.dart';
import '../../shared/widgets/pitch_painter.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/match.dart';
import '../../shared/models/standing.dart';
import '../../shared/widgets/team_crest_widget.dart';
import '../../shared/widgets/match_heat_meter.dart';
import '../../shared/widgets/rivalry_card_widget.dart';
import '../../shared/widgets/ai_insights_widget.dart';
import '../../shared/widgets/fan_poll_widget.dart';
import '../team details/team_details_screen.dart';
import '../team_comparison/team_comparison_screen.dart';

part 'match_details_shared.dart';
part 'summary_tab.dart';
part 'lineups_tab.dart';
part 'stats_tab.dart';
part 'h2h_tab.dart';
part 'standings_tab.dart';

// ─── Providers ──────────────────────────────────────────────────────────────
//
// All match-detail data now comes from MatchDetailsResolver, which pulls
// lineups / incidents / stats from BSD (free, no rate limits) and falls back
// to football-data.org goals when BSD has nothing. Providers are keyed on the
// Match directly — no more event-id indirection.

final _incidentsProvider = FutureProvider.family
    .autoDispose<List<MatchIncident>, Match>((ref, m) async {
  return MatchDetailsResolver.incidents(m);
});

final _statsProvider =
    FutureProvider.family.autoDispose<List<MatchStat>, Match>((ref, m) async {
  return MatchDetailsResolver.stats(m);
});

final _matchStandingsProvider = FutureProvider.family
    .autoDispose<List<GroupTable>, String>((ref, code) async {
  return LiveDataService.instance.getStandings();
});

/// Real-time Firestore match document stream — includes all Bzzoiro-enriched
/// fields: incidents, bzzLineups, liveStats, xg, head_to_head, etc.
/// Using StreamProvider means the ticker, stats, and lineup tabs all update
/// automatically as the relay writes new data during live matches (~5 min cadence).
final _rawMatchProvider = StreamProvider.family
    .autoDispose<Map<String, dynamic>?, int>((ref, matchId) {
  return LiveDataService.instance.watchMatchRaw(matchId);
});

// ─── Screen ─────────────────────────────────────────────────────────────────

class MatchDetailsScreen extends ConsumerStatefulWidget {
  final Match match;
  const MatchDetailsScreen({super.key, required this.match});

  @override
  ConsumerState<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends ConsumerState<MatchDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);

    // Opening a match details counts as a meaningful action — feeds the
    // frequency cap so that *eventually* an interstitial will fire, but
    // never two in quick succession.
    AdService.recordAction();
    // Preload an interstitial silently for later.
    AdService.loadInterstitial();
  }

  @override
  void dispose() {
    _tab.dispose();
    // Try to fire an interstitial when the user leaves — but only if the
    // frequency cap allows it. This is the highest-value moment (natural
    // transition, user is between tasks) and feels far less intrusive than
    // mid-task ads.
    AdService.showInterstitialIfReady();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    // Use the live Firestore stream for real-time score/status updates;
    // fall back to the passed-in match when the stream hasn't emitted yet.
    final liveMatch =
        ref.watch(matchStreamProvider(widget.match.id)).value;
    final m = liveMatch ?? widget.match;
    final favorites = ref.watch(favoritesProvider).teamTlas;
    final isFav = favorites.contains(m.homeTeam.tla) ||
        favorites.contains(m.awayTeam.tla);

    return Scaffold(
      backgroundColor: p.bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 310,
            backgroundColor: p.bg,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              _NavAction(
                icon: isFav
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isFav ? AppTheme.live : Colors.white,
                onTap: () {
                  ref.read(favoritesProvider.notifier).toggle(m.homeTeam.tla);
                  ref.read(favoritesProvider.notifier).toggle(m.awayTeam.tla);
                },
              ),
              const SizedBox(width: 4),
              _NavAction(
                icon: Icons.compare_arrows_rounded,
                color: Colors.white,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TeamComparisonScreen(
                    initialA: m.homeTeam,
                    initialB: m.awayTeam,
                  ),
                )),
              ),
              const SizedBox(width: 4),
              _NavAction(
                icon: Icons.share_rounded,
                color: Colors.white,
                onTap: () {
                  final scorers = _sortedGoals(m)
                      .map(_heroScorerLine)
                      .join(' · ');
                  Share.share(
                    '⚽ ${m.homeTeam.name} ${m.score.display} ${m.awayTeam.name}\n'
                    '${scorers.isNotEmpty ? '$scorers\n' : ''}'
                    '${DateFormat('EEE d MMM • HH:mm').format(m.utcDate)}'
                    '${m.competitionName != null ? ' • ${m.competitionName}' : ''}',
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _MatchHero(match: m),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                color: p.bg,
                child: TabBar(
                  controller: _tab,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: AppTheme.brand,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: AppTheme.brand,
                  unselectedLabelColor: p.textMid,
                  labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tabs: const [
                    Tab(text: 'Detail'),
                    Tab(text: 'Lineup'),
                    Tab(text: 'Stats'),
                    Tab(text: 'Standings'),
                    Tab(text: 'H2H'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _SummaryTab(match: m),
            _LineupsTab(match: m),
            _StatsTab(match: m),
            _StandingsTab(match: m),
            _H2HTab(match: m),
          ],
        ),
      ),
    );
  }
}

// ─── Nav action button ───────────────────────────────────────────────────────

class _NavAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _NavAction(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ─── Hero header ─────────────────────────────────────────────────────────────

class _MatchHero extends StatelessWidget {
  final Match match;
  const _MatchHero({required this.match});

  @override
  Widget build(BuildContext context) {
    final scoreText = match.score.display;

    // Status text + color shown below the score
    final String statusText;
    final Color statusColor;
    if (match.status == 'IN_PLAY') {
      final elapsed = DateTime.now().difference(match.utcDate).inMinutes;
      // match.minute comes from the relay's fetchMatchDetail and is the most
      // accurate source; fall back to a wall-clock estimate when not yet set.
      final liveMin = match.minute ??
          (elapsed < 55 ? elapsed : elapsed < 105 ? elapsed - 15 : elapsed - 30)
              .clamp(1, 120);
      final half = liveMin <= 45 ? '1st Half' : liveMin <= 90 ? '2nd Half' : 'Extra Time';
      statusText = "$half · $liveMin'";
      statusColor = AppTheme.live;
    } else if (match.status == 'PAUSED') {
      statusText = 'Half-Time';
      statusColor = AppTheme.warn;
    } else if (match.isFinished) {
      final dur = match.score.duration;
      final label = dur == 'EXTRA_TIME'
          ? 'After Extra Time'
          : dur == 'PENALTY_SHOOTOUT'
              ? 'After Penalties'
              : 'Full Time';
      statusText = '$label  ·  ${DateFormat('d MMM').format(match.utcDate)}';
      statusColor = Colors.black54;
    } else if (match.isScheduled) {
      final diff = match.utcDate.difference(DateTime.now());
      if (!diff.isNegative && diff.inMinutes > 0) {
        final days = diff.inDays;
        final hours = diff.inHours % 24;
        final mins = diff.inMinutes % 60;
        statusText = days > 0
            ? 'Kicks off in ${days}d ${hours}h'
            : hours > 0
                ? 'Kicks off in ${hours}h ${mins}m'
                : 'Kicks off in ${mins}m';
      } else {
        statusText = DateFormat('EEE d MMM · HH:mm').format(match.utcDate);
      }
      statusColor = Colors.black54;
    } else {
      statusText = DateFormat('EEE d MMM · HH:mm').format(match.utcDate);
      statusColor = Colors.black54;
    }

    // Sub-row: stage · group
    final stageLabel = match.stage
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
        .join(' ');
    final groupLabel = match.group?.replaceAll('GROUP_', 'Group ');
    final subRow = [stageLabel, if (groupLabel != null) groupLabel].join(' · ');

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (match.competitionName != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    match.competitionName!.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Home team — tappable → TeamDetailScreen
                  Expanded(
                    child: _TappableTeamColumn(
                      tla: match.homeTeam.tla,
                      name: match.homeTeam.name,
                      crest: match.homeTeam.crest,
                      teamId: match.homeTeam.id,
                    ),
                  ),
                  // Score center
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (match.status == 'IN_PLAY') ...[
                          Builder(builder: (ctx) {
                            final elapsed = DateTime.now()
                                .difference(match.utcDate)
                                .inMinutes;
                            final liveMin = match.minute ??
                                (elapsed < 55
                                        ? elapsed
                                        : elapsed < 105
                                            ? elapsed - 15
                                            : elapsed - 30)
                                    .clamp(1, 120);
                            final half = liveMin <= 45 ? '1H' : liveMin <= 90 ? '2H' : 'ET';
                            return _LiveChip(minute: liveMin, half: half);
                          }),
                          const SizedBox(height: 6),
                        ] else if (match.status == 'PAUSED') ...[
                          _HalfTimeChip(),
                          const SizedBox(height: 6),
                        ],
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: anim,
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: Text(
                            scoreText,
                            key: ValueKey(scoreText),
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2,
                                height: 1),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                        if ((match.isFinished || match.isLive) &&
                            match.goals.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ..._sortedGoals(match).take(5).map(
                            (g) => Text(
                              _heroScorerLine(g),
                              style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (match.goals.length > 5)
                            Text(
                              '+ ${match.goals.length - 5} more',
                              style: const TextStyle(
                                  color: Colors.black38,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600),
                            ),
                        ],
                      ],
                    ),
                  ),
                  // Away team — tappable → TeamDetailScreen
                  Expanded(
                    child: _TappableTeamColumn(
                      tla: match.awayTeam.tla,
                      name: match.awayTeam.name,
                      crest: match.awayTeam.crest,
                      teamId: match.awayTeam.id,
                    ),
                  ),
                ],
              ),
              // Sub-row: stage · group · venue
              if (subRow.isNotEmpty || match.venue != null) ...[
                const SizedBox(height: 8),
                Text(
                  [
                    if (subRow.isNotEmpty) subRow,
                    if (match.venue != null) match.venue!,
                  ].join(' · '),
                  style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable wrapper around the team flag + name in the match hero.
/// Pushes [TeamDetailScreen] when the team's fd.org numeric id is known.
/// If the id is null (rare; fd.org gives it on most competitions) the tap
/// is a no-op rather than a broken navigation.
class _TappableTeamColumn extends StatelessWidget {
  final String tla;
  final String name;
  final String? crest;
  final int? teamId;
  const _TappableTeamColumn({
    required this.tla,
    required this.name,
    this.crest,
    required this.teamId,
  });

  @override
  Widget build(BuildContext context) {
    final col = Column(
      children: [
        _TeamBadge(tla: tla, crest: crest),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.2),
        ),
      ],
    );
    if (teamId == null) return col;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TeamDetailScreen(
            teamId: teamId!,
            fallbackName: name,
            fallbackTla: tla,
          ),
        ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: col,
      ),
    );
  }
}

List<MatchGoal> _sortedGoals(Match m) =>
    [...m.goals]..sort((a, b) => a.minute.compareTo(b.minute));

String _heroScorerLine(MatchGoal g) {
  final name = g.scorerName ?? '';
  final parts = name.trim().split(' ');
  final short = parts.length > 1
      ? '${parts.first[0]}. ${parts.last}'
      : name;
  final suffix = g.isPenalty ? ' (P)' : g.isOwnGoal ? ' (OG)' : '';
  return "${g.minute}' $short$suffix";
}

class _TeamBadge extends StatelessWidget {
  final String tla;
  final String? crest;
  const _TeamBadge({required this.tla, this.crest});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Center(
        child: TeamCrestWidget(crestUrl: crest, tla: tla, size: 34, circular: true),
      ),
    );
  }
}

class _LiveChip extends StatefulWidget {
  final int? minute;
  final String? half;
  const _LiveChip({this.minute, this.half});

  @override
  State<_LiveChip> createState() => _LiveChipState();
}

class _LiveChipState extends State<_LiveChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.live,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _ctrl,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            widget.minute != null
                ? widget.half != null
                    ? "LIVE · ${widget.half} · ${widget.minute}'"
                    : "LIVE · ${widget.minute}'"
                : 'LIVE',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

class _HalfTimeChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.warn,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'HALF TIME',
        style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5),
      ),
    );
  }
}
