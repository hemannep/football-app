// lib/features/team details/team_details_screen.dart
//
// Updates:
//   • Player cards are now tappable → PlayerDetailScreen
//   • Banner ad pinned at the bottom of the screen
//   • Photo coverage improved via Wikipedia fallback in SportsDbService

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers/favorites_provider.dart';
import '../../core/services/live_data_service.dart';
import '../../core/services/sportsdb_service.dart';
import '../../core/theme/app_theme.dart' hide SectionLabel;
import '../../shared/models/match.dart';
import '../../shared/widgets/ad_banner_widget.dart';
import '../../shared/widgets/flag_widget.dart';
import '../../shared/widgets/match_card.dart';
import '../match details/match_details_screen.dart'
    show MatchDetailsScreen, SectionLabel;
import '../player screen/player_details_screen.dart';

// ─── Providers ──────────────────────────────────────────────────────────────

// Team matches: filter the full Firestore match list by team id.
final _teamMatchesProvider =
    FutureProvider.family<List<Match>, int>((ref, teamId) async {
  return LiveDataService.instance
      .watchMatches()
      .map((all) => all
          .where((m) =>
              (m.homeTeam.id != null && m.homeTeam.id == teamId) ||
              (m.awayTeam.id != null && m.awayTeam.id == teamId))
          .toList())
      .first;
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

    int w = 0, d = 0, l = 0, gf = 0, ga = 0;
    for (final m in played) {
      final hg = m.score.homeGoals ?? 0;
      final ag = m.score.awayGoals ?? 0;
      final us = m.homeTeam.tla == tla ? hg : ag;
      final them = m.homeTeam.tla == tla ? ag : hg;
      gf += us;
      ga += them;
      if (us > them) {
        w++;
      } else if (us < them) {
        l++;
      } else {
        d++;
      }
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (_, __) => [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 220,
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
                    ),
                  ),
                ),
              ],
              body: ListView(
                padding: const EdgeInsets.only(bottom: 30),
                children: [
                  if (sportsTeam != null) _IdentityCard(team: sportsTeam),
                  const SectionLabel('RECENT FORM'),
                  if (last5.isEmpty)
                    _emptyBlock(p, 'No played matches yet')
                  else
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.all(14),
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
                          final us = m.homeTeam.tla == tla ? hg : ag;
                          final them = m.homeTeam.tla == tla ? ag : hg;
                          final res = us > them
                              ? 'W'
                              : us < them
                                  ? 'L'
                                  : 'D';
                          final c = res == 'W'
                              ? AppTheme.good
                              : res == 'L'
                                  ? AppTheme.bad
                                  : AppTheme.warn;
                          return Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration:
                                BoxDecoration(color: c, shape: BoxShape.circle),
                            child: Text(res,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900)),
                          );
                        }).toList(),
                      ),
                    ),
                  const SectionLabel('STATS'),
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(AppTheme.r),
                      border: Border.all(color: p.stroke),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _stat('W', '$w', AppTheme.good, p)),
                        Container(width: 1, height: 36, color: p.stroke),
                        Expanded(child: _stat('D', '$d', AppTheme.warn, p)),
                        Container(width: 1, height: 36, color: p.stroke),
                        Expanded(child: _stat('L', '$l', AppTheme.bad, p)),
                        Container(width: 1, height: 36, color: p.stroke),
                        Expanded(child: _stat('GF', '$gf', p.textHi, p)),
                        Container(width: 1, height: 36, color: p.stroke),
                        Expanded(child: _stat('GA', '$ga', p.textHi, p)),
                      ],
                    ),
                  ),
                  const SectionLabel('UPCOMING MATCHES'),
                  if (upcoming.isEmpty)
                    _emptyBlock(p, 'No upcoming matches')
                  else
                    ...upcoming.take(8).map((m) => MatchCard(
                          match: m,
                          showDate: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => MatchDetailsScreen(match: m)),
                          ),
                        )),
                  const SectionLabel('SQUAD'),
                  _SquadSection(
                    teamId: teamId,
                    teamHint: name,
                  ),
                  const SectionLabel('CLUB INFO'),
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
          Text(label, style: TextStyle(fontSize: 10, color: p.textLow)),
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

// ─── Hero ──────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final String name;
  final String tla;
  final String? badgeUrl;
  const _Hero({required this.name, required this.tla, this.badgeUrl});

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
                  const Icon(Icons.stadium_rounded, size: 16, color: AppTheme.brand),
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
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
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
            dateOfBirth:
                dobRaw is String ? DateTime.tryParse(dobRaw) : null,
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
            child: Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.brand)),
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
