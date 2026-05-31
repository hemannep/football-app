// lib/features/team details/team_details_screen.dart
//
// Updates:
//   • Player cards are now tappable → PlayerDetailScreen
//   • Banner ad pinned at the bottom of the screen
//   • Photo coverage improved via Wikipedia fallback in SportsDbService

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers/favorites_provider.dart';
import '../../core/services/live_data_service.dart';
import '../../core/services/sportsdb_service.dart';
import '../../core/theme/app_theme.dart' hide SectionLabel;
import '../../shared/models/match.dart';
import '../../shared/widgets/ad_banner_widget.dart';
import '../../shared/models/standing.dart';
import '../../shared/widgets/flag_widget.dart';
import '../../shared/widgets/match_card.dart';
import '../../shared/widgets/team_crest_widget.dart';
import '../match details/match_details_screen.dart'
    show MatchDetailsScreen, SectionLabel;
import '../player screen/player_details_screen.dart';

// ─── Providers ──────────────────────────────────────────────────────────────

// Team matches: watchMatches() now uses a shared in-memory TTL cache on the
// LiveDataService singleton, so this stream emits from cache (0 reads) whenever
// the same data was recently fetched by liveScoreProvider or any other caller.
final _teamMatchesProvider =
    StreamProvider.family<List<Match>, int>((ref, teamId) {
  return LiveDataService.instance.watchMatches().map((all) => all
      .where((m) =>
          (m.homeTeam.id != null && m.homeTeam.id == teamId) ||
          (m.awayTeam.id != null && m.awayTeam.id == teamId))
      .toList());
});

final _sportsDbTeamProvider =
    FutureProvider.family<SportsDbTeam?, String>((ref, nameAndTla) async {
  final parts = nameAndTla.split('|');
  final name = parts.isNotEmpty ? parts[0] : '';
  final tla = parts.length > 1 ? parts[1] : '';
  return SportsDbService.searchTeam(name, tla: tla);
});

final playerPhotoProvider =
    FutureProvider.family.autoDispose<String?, String>((ref, key) async {
  final parts = key.split('|');
  final name = parts.isNotEmpty ? parts[0] : '';
  final hint = parts.length > 1 ? parts[1] : null;
  return SportsDbService.searchPlayerPhoto(name, teamHint: hint);
});

class UnifiedPlayer {
  final String name;
  final String? position;
  final String? nationality;
  final int? shirtNumber;
  final DateTime? dateOfBirth;
  final String? photoUrl;
  final int? playerId;
  const UnifiedPlayer({
    required this.name,
    this.position,
    this.nationality,
    this.shirtNumber,
    this.dateOfBirth,
    this.photoUrl,
    this.playerId,
  });
}

class TeamDetailScreen extends ConsumerWidget {
  final int teamId;
  final String fallbackName;
  final String fallbackTla;
  const TeamDetailScreen({
    super.key,
    required this.teamId,
    required this.fallbackName,
    required this.fallbackTla,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final teamA = ref.watch(teamProvider(teamId));
    final matchesA = ref.watch(_teamMatchesProvider(teamId));
    final sportsA =
        ref.watch(_sportsDbTeamProvider('$fallbackName|$fallbackTla'));
    final favs = ref.watch(favoritesProvider).teamTlas;
    final isFav = favs.contains(fallbackTla);

    final team = teamA.value;
    final tla = (team?['tla'] ?? fallbackTla) as String;
    final name = (team?['name'] ?? fallbackName) as String;
    final venue = team?['venue'] as String?;
    final founded = team?['founded'];
    final coach = team?['coach']?['name'] as String?;
    final website = team?['website'] as String?;
    final fdCrest = team?['crest'] as String?;
    final clubColors = team?['clubColors'] as String?;
    final country = team?['area']?['name'] as String?;

    final sportsTeam = _validateSportsTeam(sportsA.value, name, fallbackTla);

    final allMatches = matchesA.value ?? const <Match>[];
    final upcoming = allMatches.where((m) => !m.isFinished).toList()
      ..sort((a, b) => a.utcDate.compareTo(b.utcDate));
    final played = allMatches.where((m) => m.isFinished).toList()
      ..sort((a, b) => b.utcDate.compareTo(a.utcDate));
    final last5 = played.take(5).toList();

    // Most common competition code (best guess for league standings lookup)
    final compFreq = <String, int>{};
    for (final m in allMatches) {
      if (m.competitionCode != null) {
        compFreq[m.competitionCode!] = (compFreq[m.competitionCode!] ?? 0) + 1;
      }
    }
    final compCode = compFreq.isEmpty
        ? ''
        : compFreq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final standingsAsync = ref.watch(standingsByLeagueProvider(compCode));
    final standingsGroups = standingsAsync.asData?.value ?? [];
    // Find the specific group (league/tournament table) that contains this team
    final teamGroup = standingsGroups.cast<GroupTable?>().firstWhere(
          (g) => g!.teams.any((t) => t.tla == tla),
          orElse: () => null,
        );
    final teamStanding = teamGroup?.teams
        .where((t) => t.tla == tla)
        .firstOrNull;

    int w = 0, d = 0, l = 0, gf = 0, ga = 0;
    int homeW = 0, homeD = 0, homeL = 0;
    int awayW = 0, awayD = 0, awayL = 0;
    for (final m in played) {
      final hg = m.score.homeGoals ?? 0;
      final ag = m.score.awayGoals ?? 0;
      final isHome = m.homeTeam.tla == tla;
      final us = isHome ? hg : ag;
      final them = isHome ? ag : hg;
      gf += us;
      ga += them;
      if (us > them) {
        w++;
        if (isHome) { homeW++; } else { awayW++; }
      } else if (us < them) {
        l++;
        if (isHome) { homeL++; } else { awayL++; }
      } else {
        d++;
        if (isHome) { homeD++; } else { awayD++; }
      }
    }

    // Clean sheets (matches where opponent scored 0)
    int cleanSheets = 0;
    for (final m in played) {
      final hg = m.score.homeGoals ?? 0;
      final ag = m.score.awayGoals ?? 0;
      final conceded = m.homeTeam.tla == tla ? ag : hg;
      if (conceded == 0) cleanSheets++;
    }

    // Current unbeaten streak (from most recent match backwards)
    int streak = 0;
    for (final m in played) {
      final hg = m.score.homeGoals ?? 0;
      final ag = m.score.awayGoals ?? 0;
      final us = m.homeTeam.tla == tla ? hg : ag;
      final them = m.homeTeam.tla == tla ? ag : hg;
      if (us >= them) {
        streak++;
      } else {
        break;
      }
    }

    // Win streak (consecutive wins only)
    int winStreak = 0;
    for (final m in played) {
      final hg = m.score.homeGoals ?? 0;
      final ag = m.score.awayGoals ?? 0;
      final us = m.homeTeam.tla == tla ? hg : ag;
      final them = m.homeTeam.tla == tla ? ag : hg;
      if (us > them) {
        winStreak++;
      } else {
        break;
      }
    }

    final playedCount = w + d + l;
    final gfPerGame = playedCount > 0 ? gf / playedCount : 0.0;
    final gaPerGame = playedCount > 0 ? ga / playedCount : 0.0;

    // Next non-live upcoming match
    final liveNow = upcoming.where((m) => m.isLive).toList();
    final scheduled = upcoming.where((m) => !m.isLive).toList();
    final nextMatch = scheduled.isNotEmpty ? scheduled.first : null;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (_, __) => [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 240,
                  backgroundColor: p.bg,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav ? AppTheme.live : null),
                      onPressed: () =>
                          ref.read(favoritesProvider.notifier).toggle(tla),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded),
                      onPressed: () => Share.share(
                          '⚽ Follow $name in Football Fan Hub 2026!'),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _Hero(
                      name: name,
                      tla: tla,
                      badgeUrl: fdCrest ??
                          sportsTeam?.badgeUrl ??
                          sportsTeam?.logoUrl,
                      coach: coach,
                      country: country ?? sportsTeam?.country,
                      founded: founded?.toString(),
                    ),
                  ),
                ),
              ],
              body: ListView(
                padding: const EdgeInsets.only(bottom: 30),
                children: [
                  if (sportsTeam != null) _IdentityCard(team: sportsTeam),

                  // ── Live matches (highest priority — show immediately) ────
                  if (liveNow.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.live.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.live.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: AppTheme.live),
                          SizedBox(width: 6),
                          Text('LIVE NOW',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.live,
                                  letterSpacing: 1)),
                        ],
                      ),
                    ),
                    ...liveNow.map((m) => MatchCard(
                          match: m,
                          showDate: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => MatchDetailsScreen(match: m)),
                          ),
                        )),
                  ],

                  // ── Next Match spotlight ─────────────────────────────────
                  if (nextMatch != null) ...[
                    const SectionLabel('NEXT MATCH'),
                    _NextMatchCard(match: nextMatch, p: p, onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MatchDetailsScreen(match: nextMatch)))),
                  ],

                  // ── Recent form (last 5) — hidden until matches are played ─
                  if (last5.isNotEmpty) ...[
                  const SectionLabel('RECENT FORM'),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(AppTheme.r),
                        border: Border.all(color: p.stroke),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: last5.map((m) {
                          final hg = m.score.homeGoals ?? 0;
                          final ag = m.score.awayGoals ?? 0;
                          final isHome = m.homeTeam.tla == tla;
                          final us = isHome ? hg : ag;
                          final them = isHome ? ag : hg;
                          final opp = isHome ? m.awayTeam : m.homeTeam;
                          final res = us > them ? 'W' : us < them ? 'L' : 'D';
                          final c = res == 'W'
                              ? AppTheme.good
                              : res == 'L' ? AppTheme.bad : AppTheme.warn;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: c,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(res,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            height: 1)),
                                    Text('$us-$them',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 5),
                              // Opponent crest with H/A badge
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  TeamCrestWidget(crestUrl: opp.crest, tla: opp.tla, size: 20),
                                  Positioned(
                                    top: -4,
                                    right: -5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                                      decoration: BoxDecoration(
                                        color: isHome ? AppTheme.brand : p.surfaceHi,
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: p.stroke, width: 0.5),
                                      ),
                                      child: Text(
                                        isHome ? 'H' : 'A',
                                        style: TextStyle(
                                            fontSize: 7,
                                            fontWeight: FontWeight.w900,
                                            color: isHome ? Colors.white : p.textMid),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ], // end if (last5.isNotEmpty)

                  // ── Recent results (hidden until matches played) ──────────
                  if (played.isNotEmpty) ...[
                    const SectionLabel('RECENT RESULTS'),
                    ...played.take(5).map((m) => MatchCard(
                          match: m,
                          showDate: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => MatchDetailsScreen(match: m)),
                          ),
                        )),
                  ],

                  // ── Stats (only when matches have been played) ───────────
                  if (playedCount > 0) ...[
                    const SectionLabel('STATS'),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(AppTheme.r),
                        border: Border.all(color: p.stroke),
                      ),
                      child: Column(
                        children: [
                          // W / D / L / GF / GA / optional streak
                          // IntrinsicHeight ensures separators match tallest cell
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(child: _stat('W', '$w', AppTheme.good, p)),
                                VerticalDivider(width: 1, color: p.stroke),
                                Expanded(child: _stat('D', '$d', AppTheme.warn, p)),
                                VerticalDivider(width: 1, color: p.stroke),
                                Expanded(child: _stat('L', '$l', AppTheme.bad, p)),
                                VerticalDivider(width: 1, color: p.stroke),
                                Expanded(child: _stat('GF', '$gf', AppTheme.good, p)),
                                VerticalDivider(width: 1, color: p.stroke),
                                Expanded(child: _stat('GA', '$ga', AppTheme.bad, p)),
                                if (winStreak >= 2) ...[
                                  VerticalDivider(width: 1, color: p.stroke),
                                  Expanded(child: _stat('🔥 Wins', '$winStreak', AppTheme.good, p)),
                                ] else if (streak >= 3) ...[
                                  VerticalDivider(width: 1, color: p.stroke),
                                  Expanded(child: _stat('Unbeat.', '$streak', AppTheme.brand, p)),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // W/D/L ratio bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: SizedBox(
                              height: 8,
                              child: Row(children: [
                                Expanded(
                                  flex: w.clamp(1, 999),
                                  child: const ColoredBox(color: AppTheme.good),
                                ),
                                Expanded(
                                  flex: d.clamp(1, 999),
                                  child: const ColoredBox(color: AppTheme.warn),
                                ),
                                Expanded(
                                  flex: l.clamp(1, 999),
                                  child: const ColoredBox(color: AppTheme.bad),
                                ),
                              ]),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Text('${(w * 100 / playedCount).round()}% wins',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.good, fontWeight: FontWeight.w700)),
                              Expanded(
                                child: Text('$playedCount played',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 10, color: p.textLow, fontWeight: FontWeight.w600)),
                              ),
                              Text('${(l * 100 / playedCount).round()}% losses',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.bad, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Per-game and clean sheet stats
                          Divider(height: 1, color: p.stroke),
                          const SizedBox(height: 10),
                          // IntrinsicHeight prevents separator misalignment
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(child: _stat('GF/Game', gfPerGame.toStringAsFixed(2), AppTheme.good, p)),
                                VerticalDivider(width: 1, color: p.stroke),
                                Expanded(child: _stat('GA/Game', gaPerGame.toStringAsFixed(2), AppTheme.bad, p)),
                                VerticalDivider(width: 1, color: p.stroke),
                                Expanded(child: _stat('C. Sheets', '$cleanSheets', AppTheme.brand, p)),
                              ],
                            ),
                          ),
                          // Home / Away breakdown
                          if (homeW + homeD + homeL > 0 && awayW + awayD + awayL > 0) ...[
                            const SizedBox(height: 12),
                            Divider(height: 1, color: p.stroke),
                            const SizedBox(height: 10),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _homeAwayBlock(
                                        'Home', homeW, homeD, homeL, AppTheme.brand, p),
                                  ),
                                  VerticalDivider(width: 1, color: p.stroke),
                                  Expanded(
                                    child: _homeAwayBlock(
                                        'Away', awayW, awayD, awayL,
                                        const Color(0xFF1E88E5), p),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // ── Mini standings table ─────────────────────────────────
                  if (teamGroup != null) ...[
                    const SectionLabel('STANDING'),
                    _MiniStandingsCard(
                      group: teamGroup,
                      teamTla: tla,
                      p: p,
                    ),
                  ],

                  // ── Upcoming matches (excluding the spotlight next match) ─
                  if (scheduled.length > 1) ...[
                    const SectionLabel('UPCOMING MATCHES'),
                    ...scheduled.skip(1).take(5).map((m) => MatchCard(
                          match: m,
                          showDate: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => MatchDetailsScreen(match: m)),
                          ),
                        )),
                  ] else if (liveNow.isEmpty && nextMatch == null)
                    _emptyBlock(p, 'No upcoming matches'),
                  // Squad — show count once loaded
                  Builder(builder: (ctx) {
                    final count = ref.watch(playersForTeamProvider(teamId))
                        .asData?.value.length ?? 0;
                    return SectionLabel(count > 0 ? 'SQUAD ($count)' : 'SQUAD');
                  }),
                  _SquadSection(
                    teamId: teamId,
                    teamHint: name,
                  ),
                  const SectionLabel('CLUB INFO'),
                  if (teamStanding != null) ...[
                    // Derive competition name from the team's matches
                    Builder(builder: (ctx) {
                      final compName = allMatches
                          .where((m) => m.competitionCode == compCode)
                          .map((m) => m.competitionName)
                          .whereType<String>()
                          .firstOrNull;
                      final gd = teamStanding.goalDifference;
                      return _info(
                        p,
                        Icons.format_list_numbered_rounded,
                        compName ?? 'Position',
                        '#${teamStanding.position}  ·  ${teamStanding.points} pts  ·  GD ${gd > 0 ? "+" : ""}$gd',
                      );
                    }),
                  ],
                  if (founded != null)
                    _info(p, Icons.event_rounded, 'Founded', '$founded'),
                  if (coach != null && coach.isNotEmpty)
                    _info(p, Icons.person_rounded, 'Manager', coach),
                  if (venue != null && venue.isNotEmpty)
                    _info(p, Icons.stadium_rounded, 'Venue', venue)
                  else if (sportsTeam?.stadiumName != null)
                    _info(p, Icons.stadium_rounded, 'Venue',
                        sportsTeam!.stadiumName!),
                  if (country != null)
                    _info(p, Icons.public_rounded, 'Country', country)
                  else if (sportsTeam?.country != null)
                    _info(p, Icons.public_rounded, 'Country',
                        sportsTeam!.country!),
                  if (clubColors != null && clubColors.isNotEmpty)
                    _info(p, Icons.palette_rounded, 'Colours', clubColors),
                  if (website != null && website.isNotEmpty)
                    _info(p, Icons.link_rounded, 'Website', website,
                        onTap: () => _open(website)),
                  if (sportsTeam?.description != null &&
                      sportsTeam!.description!.isNotEmpty) ...[
                    const SectionLabel('ABOUT'),
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(AppTheme.r),
                        border: Border.all(color: p.stroke),
                      ),
                      child: Text(sportsTeam.description!,
                          style: TextStyle(
                              fontSize: 13, height: 1.45, color: p.textMid)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // ── Banner ad pinned to bottom ─────────────────────────────
          const AdBannerWidget(),
        ],
      ),
    );
  }

  SportsDbTeam? _validateSportsTeam(
      SportsDbTeam? candidate, String fdName, String fdTla) {
    if (candidate == null) return null;
    final candName = candidate.name.toLowerCase();
    final candCountry = (candidate.country ?? '').toLowerCase();
    final fd = fdName.toLowerCase();
    if (candName.contains(fd) || fd.contains(candName)) return candidate;
    if (candCountry.isNotEmpty &&
        (candCountry.contains(fd) || fd.contains(candCountry))) {
      return candidate;
    }
    if ((fd.contains('czech') && candName.contains('czech')) ||
        (fd.contains('korea') && candName.contains('korea')) ||
        (fd.contains('united states') &&
            (candName.contains('united states') || candName.contains('usa'))) ||
        (fd == 'usa' && candName.contains('united states')) ||
        (fd.contains('ivory') && candName.contains('ivory')) ||
        (fd.contains('cape') && candName.contains('cape'))) {
      return candidate;
    }
    return null;
  }

  Widget _stat(String label, String value, Color c, Palette p) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: c)),
          Text(label,
              style: TextStyle(fontSize: 9, color: p.textLow),
              textAlign: TextAlign.center),
        ],
      );

  Widget _homeAwayBlock(
      String label, int w, int d, int l, Color accentColor, Palette p) {
    final total = w + d + l;
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: p.textLow,
                letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _miniStat('$w', 'W', AppTheme.good, p),
            const SizedBox(width: 10),
            _miniStat('$d', 'D', AppTheme.warn, p),
            const SizedBox(width: 10),
            _miniStat('$l', 'L', AppTheme.bad, p),
          ],
        ),
        if (total > 0) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              child: Row(children: [
                Expanded(
                  flex: w.clamp(1, 99),
                  child: const ColoredBox(color: AppTheme.good),
                ),
                Expanded(
                  flex: d.clamp(1, 99),
                  child: const ColoredBox(color: AppTheme.warn),
                ),
                Expanded(
                  flex: l.clamp(1, 99),
                  child: const ColoredBox(color: AppTheme.bad),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 3),
          Text('${(w * 100 / total).round()}% win rate',
              style: TextStyle(fontSize: 9, color: accentColor, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }

  Widget _miniStat(String value, String label, Color c, Palette p) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: c)),
          Text(label, style: TextStyle(fontSize: 9, color: p.textLow)),
        ],
      );

  Widget _emptyBlock(Palette p, String msg) => Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(msg, style: TextStyle(color: p.textLow)),
        ),
      );

  Widget _info(Palette p, IconData icon, String label, String value,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.stroke),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppTheme.brand),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: p.textLow,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.textHi))),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.open_in_new_rounded, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ─── Next Match spotlight card ────────────────────────────────────────────────

class _NextMatchCard extends StatelessWidget {
  final Match match;
  final Palette p;
  final VoidCallback onTap;
  const _NextMatchCard({required this.match, required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = match.utcDate.toLocal().difference(now);
    final String countdownStr;
    if (diff.isNegative) {
      countdownStr = 'Soon';
    } else if (diff.inDays > 0) {
      countdownStr = 'In ${diff.inDays}d ${diff.inHours % 24}h';
    } else if (diff.inHours > 0) {
      countdownStr = 'In ${diff.inHours}h ${diff.inMinutes % 60}m';
    } else {
      countdownStr = 'In ${diff.inMinutes}m';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(AppTheme.r),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  (match.competitionName ?? match.stage).toUpperCase(),
                  style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(countdownStr,
                      style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TeamCrestWidget(crestUrl: match.homeTeam.crest, tla: match.homeTeam.tla, size: 40),
                      const SizedBox(height: 6),
                      Text(match.homeTeam.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              height: 1.2)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      const Text('VS',
                          style: TextStyle(
                              color: Colors.black45,
                              fontSize: 13,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(DateFormat('d MMM\nHH:mm').format(match.utcDate.toLocal()),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 1.3)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      TeamCrestWidget(crestUrl: match.awayTeam.crest, tla: match.awayTeam.tla, size: 40),
                      const SizedBox(height: 6),
                      Text(match.awayTeam.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              height: 1.2)),
                    ],
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

// ─── Mini standings card ──────────────────────────────────────────────────────

class _MiniStandingsCard extends StatelessWidget {
  final GroupTable group;
  final String teamTla;
  final Palette p;
  const _MiniStandingsCard({
    required this.group,
    required this.teamTla,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    final teams = group.teams;
    if (teams.isEmpty) return const SizedBox.shrink();

    // Show up to 5 rows centered around the team's position.
    final teamIdx = teams.indexWhere((t) => t.tla == teamTla);
    final startIdx = teamIdx < 0
        ? 0
        : (teamIdx - 2).clamp(0, (teams.length - 5).clamp(0, teams.length));
    final visible = teams.skip(startIdx).take(5).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        children: [
          // Column headers
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(children: [
              const SizedBox(width: 22),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
              _hdr('P'),
              _hdr('W'),
              _hdr('D'),
              _hdr('L'),
              _hdr('GD'),
              _hdr('Pts', bold: true),
            ]),
          ),
          Divider(height: 1, color: p.stroke),
          ...visible.map((t) {
            final isMe = t.tla == teamTla;
            final gdSign = t.goalDifference > 0 ? '+' : '';
            return Container(
              color: isMe
                  ? AppTheme.brand.withValues(alpha: 0.08)
                  : Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${t.position}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                          color: isMe ? AppTheme.brand : p.textLow),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TeamCrestWidget(crestUrl: t.crest, tla: t.tla, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                          color: isMe ? p.textHi : p.textMid),
                    ),
                  ),
                  _cell('${t.playedGames}', p),
                  _cell('${t.won}', p, color: t.won > 0 ? AppTheme.good : null),
                  _cell('${t.draw}', p),
                  _cell('${t.lost}', p, color: t.lost > 0 ? AppTheme.bad : null),
                  _cell('$gdSign${t.goalDifference}', p,
                      color: t.goalDifference > 0
                          ? AppTheme.good
                          : t.goalDifference < 0
                              ? AppTheme.bad
                              : null),
                  _cell('${t.points}', p, bold: true),
                ]),
              ),
            );
          }),
          // "View full table" hint if there are more teams
          if (teams.length > 5)
            InkWell(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${teams.length} teams in table',
                  style: TextStyle(
                      fontSize: 11,
                      color: p.textLow,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hdr(String s, {bool bold = false}) => SizedBox(
        width: 30,
        child: Text(s,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: const Color(0xFF9E9E9E),
                letterSpacing: 0.3)),
      );

  Widget _cell(String v, Palette p, {Color? color, bool bold = false}) =>
      SizedBox(
        width: 30,
        child: Text(v,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: color ?? (bold ? p.textHi : p.textMid))),
      );
}

// ─── Hero ──────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final String name;
  final String tla;
  final String? badgeUrl;
  final String? coach;
  final String? country;
  final String? founded;
  const _Hero({
    required this.name,
    required this.tla,
    this.badgeUrl,
    this.coach,
    this.country,
    this.founded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClubBadge(crestUrl: badgeUrl, tla: tla, size: 80),
              const SizedBox(height: 8),
              Text(name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              if (coach != null && coach!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '👤 $coach',
                    style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              if (country != null || founded != null) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (country != null) country!,
                    if (founded != null) 'Est. $founded',
                  ].join(' · '),
                  style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ClubBadge extends StatefulWidget {
  final String? crestUrl;
  final String tla;
  final double size;
  const ClubBadge(
      {super.key, this.crestUrl, required this.tla, this.size = 48});

  @override
  State<ClubBadge> createState() => _ClubBadgeState();
}

class _ClubBadgeState extends State<ClubBadge> {
  bool _failed = false;

  bool get _isSvg =>
      widget.crestUrl != null &&
      widget.crestUrl!.toLowerCase().endsWith('.svg');

  bool get _canTryCrest =>
      widget.crestUrl != null && widget.crestUrl!.isNotEmpty && !_failed;

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    Widget child;
    if (_canTryCrest && _isSvg) {
      child = SvgPicture.network(widget.crestUrl!,
          width: s,
          height: s,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => _placeholder(s));
    } else if (_canTryCrest) {
      child = Image.network(widget.crestUrl!,
          width: s, height: s, fit: BoxFit.contain, errorBuilder: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _failed = true);
        });
        return _fallback(s);
      });
    } else {
      child = _fallback(s);
    }
    return SizedBox(width: s, height: s, child: Center(child: child));
  }

  Widget _placeholder(double s) => Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle));

  Widget _fallback(double s) =>
      FlagWidget(tla: widget.tla, size: s * 0.6, circular: true);
}

// ─── Identity card ─────────────────────────────────────────────────────────

class _IdentityCard extends StatelessWidget {
  final SportsDbTeam team;
  const _IdentityCard({required this.team});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    if (team.stadiumImage == null &&
        team.stadiumName == null &&
        team.anthemUrl == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (team.stadiumImage != null)
            AspectRatio(
              aspectRatio: 16 / 8,
              child: Image.network(team.stadiumImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: p.surfaceHi)),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (team.stadiumName != null) ...[
                  const Icon(Icons.stadium_rounded,
                      size: 16, color: AppTheme.brand),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(team.stadiumName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: p.textHi)),
                  ),
                ],
                if (team.anthemUrl != null)
                  TextButton.icon(
                    onPressed: () => _open(team.anthemUrl!),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Anthem'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ─── Squad ─────────────────────────────────────────────────────────────────

class _SquadSection extends ConsumerWidget {
  final int teamId;
  final String teamHint;
  const _SquadSection({
    required this.teamId,
    required this.teamHint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final squadAsync = ref.watch(playersForTeamProvider(teamId));

    if (squadAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    final players = _buildSquad(squadAsync.value ?? const []);

    if (players.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.groups_outlined, size: 48, color: p.textLow),
            const SizedBox(height: 10),
            Text('Squad not yet announced',
                style:
                    TextStyle(color: p.textMid, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Squads typically appear closer to kick-off.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textLow, fontSize: 12)),
          ],
        ),
      );
    }

    final goalkeepers = players.where((p) => _isGK(p.position)).toList();
    final defenders = players.where((p) => _isDF(p.position)).toList();
    final midfielders = players.where((p) => _isMF(p.position)).toList();
    final forwards = players.where((p) => _isFW(p.position)).toList();
    final other = players
        .where((p) =>
            !_isGK(p.position) &&
            !_isDF(p.position) &&
            !_isMF(p.position) &&
            !_isFW(p.position))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (goalkeepers.isNotEmpty)
          _PositionGroup(
              label: 'Goalkeepers', players: goalkeepers, teamHint: teamHint),
        if (defenders.isNotEmpty)
          _PositionGroup(
              label: 'Defenders', players: defenders, teamHint: teamHint),
        if (midfielders.isNotEmpty)
          _PositionGroup(
              label: 'Midfielders', players: midfielders, teamHint: teamHint),
        if (forwards.isNotEmpty)
          _PositionGroup(
              label: 'Forwards', players: forwards, teamHint: teamHint),
        if (other.isNotEmpty)
          _PositionGroup(label: 'Other', players: other, teamHint: teamHint),
      ],
    );
  }

  List<UnifiedPlayer> _buildSquad(List<Map<String, dynamic>> maps) {
    return maps
        .map((raw) {
          final name = (raw['name'] ?? raw['playerName'] ?? '') as String;
          if (name.isEmpty) return null;
          final dobRaw = raw['dateOfBirth'] ?? raw['dob'];
          return UnifiedPlayer(
            name: name,
            position: raw['position'] as String?,
            nationality: raw['nationality'] as String?,
            shirtNumber: raw['shirtNumber'] as int?,
            dateOfBirth: dobRaw is String ? DateTime.tryParse(dobRaw) : null,
            photoUrl: (raw['photoUrl'] ?? raw['imageUrl']) as String?,
            playerId: raw['id'] as int?,
          );
        })
        .whereType<UnifiedPlayer>()
        .toList();
  }

  bool _isGK(String? pos) {
    if (pos == null) return false;
    final p = pos.toLowerCase();
    return p.contains('goal') || p == 'gk';
  }

  bool _isDF(String? pos) {
    if (pos == null) return false;
    final p = pos.toLowerCase();
    return p.contains('defen') ||
        p.contains('back') ||
        p == 'cb' ||
        p == 'lb' ||
        p == 'rb';
  }

  bool _isMF(String? pos) {
    if (pos == null) return false;
    final p = pos.toLowerCase();
    return p.contains('midf') ||
        p == 'cm' ||
        p == 'dm' ||
        p == 'am' ||
        p == 'lm' ||
        p == 'rm';
  }

  bool _isFW(String? pos) {
    if (pos == null) return false;
    final p = pos.toLowerCase();
    return p.contains('offen') ||
        p.contains('forward') ||
        p.contains('striker') ||
        p.contains('winger') ||
        p.contains('attack') ||
        p == 'cf' ||
        p == 'lw' ||
        p == 'rw' ||
        p == 'st';
  }
}

class _PositionGroup extends StatelessWidget {
  final String label;
  final List<UnifiedPlayer> players;
  final String teamHint;
  const _PositionGroup(
      {required this.label, required this.players, required this.teamHint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.brand)),
                const SizedBox(width: 6),
                Text('(${players.length})',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.brand)),
              ],
            ),
          ),
          SizedBox(
            height: 152,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: players.length,
              itemBuilder: (_, i) =>
                  _PlayerCard(player: players[i], teamHint: teamHint),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends ConsumerWidget {
  final UnifiedPlayer player;
  final String teamHint;
  const _PlayerCard({required this.player, required this.teamHint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final age = player.dateOfBirth != null
        ? DateTime.now().difference(player.dateOfBirth!).inDays ~/ 365
        : null;

    final String? eagerPhoto = player.photoUrl;
    final asyncLazy = eagerPhoto != null
        ? const AsyncValue<String?>.data(null)
        : ref.watch(playerPhotoProvider('${player.name}|$teamHint'));
    final effectivePhoto = eagerPhoto ?? asyncLazy.value;

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlayerDetailScreen(
          name: player.name,
          teamHint: teamHint,
          shirtNumber: player.shirtNumber,
          position: player.position,
          playerId: player.playerId,
        ),
      )),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 104,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.stroke),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _PlayerAvatar(
              photoUrl: effectivePhoto,
              name: player.name,
              shirtNumber: player.shirtNumber,
              size: 56,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(player.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: p.textHi,
                      height: 1.15)),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                [
                  if (player.position != null) player.position,
                  if (age != null) '$age yrs',
                ].whereType<String>().join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: p.textLow),
              ),
            ),
            if (player.nationality != null) ...[
              const SizedBox(height: 4),
              FlagWidget(
                tla: nationalityToTla(player.nationality) ?? '---',
                size: 14,
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final int? shirtNumber;
  final double size;
  const _PlayerAvatar({
    required this.photoUrl,
    required this.name,
    required this.shirtNumber,
    required this.size,
  });

  static const _palette = [
    Color(0xFF4F46E5),
    Color(0xFF0EA5E9),
    Color(0xFF14B8A6),
    Color(0xFF22C55E),
    Color(0xFFEAB308),
    Color(0xFFF97316),
    Color(0xFFEF4444),
    Color(0xFFEC4899),
  ];

  Color get _bgColor {
    var hash = 0;
    for (final cu in name.codeUnits) {
      hash = (hash * 31 + cu) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = ClipOval(
      child: Container(
        width: size,
        height: size,
        color: photoUrl != null ? Colors.transparent : _bgColor,
        alignment: Alignment.center,
        child: photoUrl != null
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (_, __, ___) => _initialsBox(),
                loadingBuilder: (_, child, prog) {
                  if (prog == null) return child;
                  return _initialsBox();
                },
              )
            : _initialsBox(),
      ),
    );

    if (shirtNumber == null) return avatar;
    return Stack(
      alignment: Alignment.center,
      children: [
        avatar,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.brand,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black, width: 0.5),
            ),
            child: Text('$shirtNumber',
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.black)),
          ),
        ),
      ],
    );
  }

  Widget _initialsBox() => Container(
        color: _bgColor,
        alignment: Alignment.center,
        child: Text(_initials,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            )),
      );
}
