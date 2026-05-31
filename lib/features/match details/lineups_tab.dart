// tabs/lineups_tab.dart
//
// Lineup tab — pitch view with player chips, ratings, formation headers,
// plus Subs / Injuries / Suspensions sub-tabs.
// Part of the match_details library — see match_details_screen.dart.

part of 'match_details_screen.dart';

// ─── Lineup tab ───────────────────────────────────────────────────────────────

class _LineupsTab extends ConsumerStatefulWidget {
  final Match match;
  const _LineupsTab({required this.match});

  @override
  ConsumerState<_LineupsTab> createState() => _LineupsTabState();
}

class _LineupsTabState extends ConsumerState<_LineupsTab> {
  int _subTab = 0; // 0=Lineup 1=Subs 2=Injuries 3=Suspensions

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final rawAsync = ref.watch(_rawMatchProvider(widget.match.id));

    if (rawAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final raw = rawAsync.value;

    // lineups/{matchId} collection — best-effort fallback from relay/API-Football.
    // Watched here so the tab auto-updates if relay writes the lineup while open.
    final lineupCollAsync = ref.watch(lineupProvider(widget.match.id));
    final lineupColl = lineupCollAsync.value;

    // ── Determine which lineup to use ───────────────────────────────────────
    // Priority:
    //   1. bzzLineups  (Bzzoiro enricher — flat player list, most complete)
    //   2. confirmedLineup in match doc (relay → API-Football merge, same doc)
    //   3. lineups/{matchId} collection (relay writes this separately; may have
    //      data when the match-doc field wasn't merged in time)
    //   4. bzzPredictedLineup (Bzzoiro pre-match prediction)
    //   5. null → empty pitch / not-available state
    final bzzLineupsList = raw?['bzzLineups'];
    final hasBzzLineups = bzzLineupsList is List && bzzLineupsList.isNotEmpty;

    final confirmedLineupMap = raw?['confirmedLineup'];
    final hasConfirmedLineup = confirmedLineupMap is Map &&
        (confirmedLineupMap['home'] != null || confirmedLineupMap['away'] != null);

    // lineups collection fallback: has useful data when home/away are non-null.
    final hasLineupColl = lineupColl != null &&
        (lineupColl['home'] != null || lineupColl['away'] != null);

    final isActual = (hasBzzLineups || hasConfirmedLineup || hasLineupColl) &&
        (widget.match.isLive ||
            widget.match.isFinished ||
            widget.match.status == 'PAUSED');

    final List? lineupList;
    final bool isPredicted;

    if (hasBzzLineups) {
      lineupList = bzzLineupsList;
      isPredicted = !isActual;
    } else if (hasConfirmedLineup) {
      lineupList = _convertConfirmedLineup(
          Map<String, dynamic>.from(confirmedLineupMap));
      isPredicted = false;
    } else if (hasLineupColl) {
      // Convert the lineups-collection format {home: {players:[...]}, away:{...}}
      // into the same flat bzzLineups structure the pitch view expects.
      lineupList = _convertConfirmedLineup(
          Map<String, dynamic>.from(lineupColl));
      isPredicted = false;
    } else if (raw?['bzzPredictedLineup'] is List) {
      lineupList = raw!['bzzPredictedLineup'] as List;
      isPredicted = !isActual;
    } else {
      lineupList = null;
      isPredicted = false;
    }

    // Formation: Bzzoiro predicted → confirmedLineup actual → default.
    String homeFormation =
        (raw?['bzzPredictedFormation']?['home'] as String?) ?? '4-3-3';
    String awayFormation =
        (raw?['bzzPredictedFormation']?['away'] as String?) ?? '4-3-3';

    // Coach names from confirmedLineup (API-Football) or bzzLineups metadata.
    String? homeCoach = (raw?['bzzCoach']?['home']) as String?;
    String? awayCoach = (raw?['bzzCoach']?['away']) as String?;

    if (!hasBzzLineups && hasConfirmedLineup) {
      if (confirmedLineupMap['home'] is Map) {
        final home = confirmedLineupMap['home'] as Map;
        homeFormation = home['formation'] as String? ?? homeFormation;
        if (homeCoach == null && home['coach'] is Map) {
          homeCoach = (home['coach'] as Map)['name'] as String?;
        }
      }
      if (confirmedLineupMap['away'] is Map) {
        final away = confirmedLineupMap['away'] as Map;
        awayFormation = away['formation'] as String? ?? awayFormation;
        if (awayCoach == null && away['coach'] is Map) {
          awayCoach = (away['coach'] as Map)['name'] as String?;
        }
      }
    }

    final allPlayers = lineupList == null
        ? <Map<String, dynamic>>[]
        : lineupList
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();

    final homePlayers =
        allPlayers.where((pl) => pl['is_home'] == true).toList();
    final awayPlayers =
        allPlayers.where((pl) => pl['is_home'] != true).toList();

    final homeStarters =
        homePlayers.where((pl) => pl['is_starter'] != false).toList();
    final awayStarters =
        awayPlayers.where((pl) => pl['is_starter'] != false).toList();
    final homeSubs =
        homePlayers.where((pl) => pl['is_starter'] == false).toList();
    final awaySubs =
        awayPlayers.where((pl) => pl['is_starter'] == false).toList();

    final unavail = raw?['unavailablePlayers'] as Map?;
    final homeInjured = _unavailList(unavail?['home'], 'injured');
    final awayInjured = _unavailList(unavail?['away'], 'injured');
    final homeSuspended = _unavailList(unavail?['home'], 'suspended');
    final awaySuspended = _unavailList(unavail?['away'], 'suspended');

    Widget content;
    if (_subTab == 1) {
      content = _buildSubsList(p, homeSubs, awaySubs);
    } else if (_subTab == 2) {
      content = _buildUnavailList(p, homeInjured, awayInjured, 'Injuries',
          Icons.medical_services_outlined);
    } else if (_subTab == 3) {
      content = _buildUnavailList(p, homeSuspended, awaySuspended,
          'Suspensions', Icons.warning_amber_rounded);
    } else {
      content = _buildPitchView(
        context,
        homeStarters: homeStarters,
        awayStarters: awayStarters,
        homeFormation: homeFormation,
        awayFormation: awayFormation,
        homeCoach: homeCoach,
        awayCoach: awayCoach,
        isPredicted: isPredicted,
        lineupList: lineupList,
      );
    }

    return Column(
      children: [
        // ── Sub-tab selector ──────────────────────────────────────────
        Container(
          color: p.bg,
          child: Row(
            children: [
              _SubTabBtn(label: 'Lineup', idx: 0, sel: _subTab,
                  onTap: () => setState(() => _subTab = 0)),
              _SubTabBtn(label: 'Subs', idx: 1, sel: _subTab,
                  onTap: () => setState(() => _subTab = 1)),
              _SubTabBtn(label: 'Injuries', idx: 2, sel: _subTab,
                  onTap: () => setState(() => _subTab = 2)),
              _SubTabBtn(label: 'Suspensions', idx: 3, sel: _subTab,
                  onTap: () => setState(() => _subTab = 3)),
            ],
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  // ── Pitch view ─────────────────────────────────────────────────────────────

  Widget _buildPitchView(
    BuildContext context, {
    required List<Map<String, dynamic>> homeStarters,
    required List<Map<String, dynamic>> awayStarters,
    required String homeFormation,
    required String awayFormation,
    String? homeCoach,
    String? awayCoach,
    required bool isPredicted,
    required List? lineupList,
  }) {
    if (lineupList == null) {
      if (widget.match.isFinished || widget.match.isLive) {
        return const _Unavailable(
          icon: Icons.groups_outlined,
          message: 'Lineups not available for this match.',
          hint: 'Detailed lineup data isn\'t available for every competition.',
        );
      }
      return _buildEmptyPitch(context);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
      child: Column(
        children: [
          if (isPredicted)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warn.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.warn.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 13, color: AppTheme.warn),
                      SizedBox(width: 5),
                      Text('Predicted XI',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.warn)),
                    ],
                  ),
                ),
              ),
            ),

          // ── Pitch ────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.r),
            child: AspectRatio(
              aspectRatio: 0.62,
              child: LayoutBuilder(builder: (context, box) {
                final pw = box.maxWidth;
                final ph = box.maxHeight;

                final homePos = formationPositions(
                  formation: homeFormation,
                  isHome: true,
                  playerCount: homeStarters.length,
                );
                final awayPos = formationPositions(
                  formation: awayFormation,
                  isHome: false,
                  playerCount: awayStarters.length,
                );

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const PitchBackground(),

                    // Home team label (top)
                    Positioned(
                      top: 6,
                      left: 10,
                      right: 10,
                      child: _TeamStrip(
                          match: widget.match,
                          isHome: true,
                          formation: homeFormation,
                          players: homeStarters,
                          coach: homeCoach),
                    ),

                    // Home players
                    for (int i = 0;
                        i < math.min(homePos.length, homeStarters.length);
                        i++)
                      Positioned(
                        left: homePos[i].dx * pw - 22,
                        top: homePos[i].dy * ph - 22,
                        child: _PlayerChip(
                          player: homeStarters[i],
                          teamColor: AppTheme.brand,
                        ),
                      ),

                    // Away players
                    for (int i = 0;
                        i < math.min(awayPos.length, awayStarters.length);
                        i++)
                      Positioned(
                        left: awayPos[i].dx * pw - 22,
                        top: awayPos[i].dy * ph - 22,
                        child: _PlayerChip(
                          player: awayStarters[i],
                          teamColor: AppTheme.live,
                        ),
                      ),

                    // Away team label (bottom)
                    Positioned(
                      bottom: 6,
                      left: 10,
                      right: 10,
                      child: _TeamStrip(
                          match: widget.match,
                          isHome: false,
                          formation: awayFormation,
                          players: awayStarters,
                          coach: awayCoach,
                          alignRight: true),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty pitch (upcoming match, no lineup yet) ─────────────────────────────

  String _lineupEtaLabel() {
    final ko = widget.match.utcDate;
    final now = DateTime.now();
    final diff = ko.difference(now);
    if (diff.isNegative || diff.inMinutes < 60) {
      return 'Lineup expected before kick-off';
    }
    final hoursUntil = diff.inHours;
    if (hoursUntil < 24) {
      return 'Lineup arrives ~1h before kick-off (in ${hoursUntil}h)';
    }
    final d = diff.inDays;
    return 'Lineup arrives ~1h before kick-off (in ${d}d)';
  }

  Widget _buildEmptyPitch(BuildContext context) {
    const formation = '4-3-3';
    final homePos = formationPositions(
        formation: formation, isHome: true, playerCount: 11);
    final awayPos = formationPositions(
        formation: formation, isHome: false, playerCount: 11);
    final homeLabels = _posLabels(formation, true);
    final awayLabels = _posLabels(formation, false);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.warn.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.warn.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded, size: 13, color: AppTheme.warn),
                const SizedBox(width: 5),
                Text(_lineupEtaLabel(),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warn)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.r),
            child: AspectRatio(
              aspectRatio: 0.62,
              child: LayoutBuilder(builder: (context, box) {
                final pw = box.maxWidth;
                final ph = box.maxHeight;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const PitchBackground(),
                    for (int i = 0; i < math.min(homePos.length, homeLabels.length); i++)
                      Positioned(
                        left: homePos[i].dx * pw - 18,
                        top: homePos[i].dy * ph - 18,
                        child: _EmptyPositionChip(
                            label: homeLabels[i], color: AppTheme.brand),
                      ),
                    for (int i = 0; i < math.min(awayPos.length, awayLabels.length); i++)
                      Positioned(
                        left: awayPos[i].dx * pw - 18,
                        top: awayPos[i].dy * ph - 18,
                        child: _EmptyPositionChip(
                            label: awayLabels[i], color: AppTheme.live),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  static List<String> _posLabels(String formation, bool isHome) {
    final rows = parseFormation(formation);
    final labels = <String>[];
    for (int ri = 0; ri < rows.length; ri++) {
      final count = rows[ri];
      if (ri == 0) {
        labels.add('GK');
      } else if (ri == rows.length - 1) {
        if (count == 1) { labels.add('ST'); }
        else if (count == 2) { labels.addAll(['ST', 'ST']); }
        else if (count == 3) { labels.addAll(['LW', 'ST', 'RW']); }
        else { labels.addAll(List.generate(count, (_) => 'FW')); }
      } else if (ri == 1) {
        if (count == 3) { labels.addAll(['LB', 'CB', 'RB']); }
        else if (count == 4) { labels.addAll(['LB', 'CB', 'CB', 'RB']); }
        else if (count == 5) { labels.addAll(['LWB', 'CB', 'CB', 'CB', 'RWB']); }
        else { labels.addAll(List.generate(count, (_) => 'DEF')); }
      } else {
        if (count == 1) { labels.add('DM'); }
        else if (count == 2) { labels.addAll(['CM', 'CM']); }
        else if (count == 3) { labels.addAll(['CM', 'CM', 'CM']); }
        else { labels.addAll(List.generate(count, (_) => 'MID')); }
      }
    }
    return labels;
  }

  // ── Convert API-Football confirmedLineup → flat bzzLineups-compatible list ──

  static List<Map<String, dynamic>>? _convertConfirmedLineup(
      Map<String, dynamic> confirmedLineup) {
    final out = <Map<String, dynamic>>[];

    void processTeam(dynamic team, bool isHome) {
      if (team is! Map) return;
      for (final item in (team['startXI'] as List? ?? [])) {
        final p = item is Map ? item['player'] as Map? : null;
        if (p == null) continue;
        out.add({
          'player_name': p['name'],
          'name': p['name'],
          'jersey_number': p['number'],
          'position': p['pos'],
          'is_home': isHome,
          'is_starter': true,
        });
      }
      for (final item in (team['substitutes'] as List? ?? [])) {
        final p = item is Map ? item['player'] as Map? : null;
        if (p == null) continue;
        out.add({
          'player_name': p['name'],
          'name': p['name'],
          'jersey_number': p['number'],
          'position': p['pos'],
          'is_home': isHome,
          'is_starter': false,
        });
      }
    }

    processTeam(confirmedLineup['home'], true);
    processTeam(confirmedLineup['away'], false);
    return out.isEmpty ? null : out;
  }

  // ── Subs list ───────────────────────────────────────────────────────────────

  Widget _buildSubsList(Palette p,
      List<Map<String, dynamic>> homeSubs,
      List<Map<String, dynamic>> awaySubs) {
    if (homeSubs.isEmpty && awaySubs.isEmpty) {
      return const _Unavailable(
          icon: Icons.swap_horiz_rounded,
          message: 'Substitutes not available yet.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
      children: [
        _SectionLabel('${widget.match.homeTeam.tla} — Substitutes'),
        if (homeSubs.isEmpty)
          _emptyRow(p, 'None listed')
        else
          ...homeSubs.map((pl) => _SubRow(player: pl, p: p)),
        const SizedBox(height: 12),
        _SectionLabel('${widget.match.awayTeam.tla} — Substitutes'),
        if (awaySubs.isEmpty)
          _emptyRow(p, 'None listed')
        else
          ...awaySubs.map((pl) => _SubRow(player: pl, p: p)),
      ],
    );
  }

  // ── Unavailable list ────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _unavailList(dynamic side, String key) {
    if (side is! List) return const [];
    return side
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .where((m) => m[key] == true)
        .toList();
  }

  Widget _buildUnavailList(
      Palette p,
      List<Map<String, dynamic>> home,
      List<Map<String, dynamic>> away,
      String title,
      IconData icon) {
    if (home.isEmpty && away.isEmpty) {
      return _Unavailable(icon: icon, message: 'No $title reported.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
      children: [
        _SectionLabel('${widget.match.homeTeam.tla} — $title'),
        if (home.isEmpty)
          _emptyRow(p, 'None reported')
        else
          ...home.map((pl) => _UnavailRow(player: pl, p: p)),
        const SizedBox(height: 12),
        _SectionLabel('${widget.match.awayTeam.tla} — $title'),
        if (away.isEmpty)
          _emptyRow(p, 'None reported')
        else
          ...away.map((pl) => _UnavailRow(player: pl, p: p)),
      ],
    );
  }

  Widget _emptyRow(Palette p, String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Text(msg,
            style: TextStyle(
                fontSize: 13,
                color: p.textLow,
                fontStyle: FontStyle.italic)),
      );
}

// ─── Sub-tab button ───────────────────────────────────────────────────────────

class _SubTabBtn extends StatelessWidget {
  final String label;
  final int idx;
  final int sel;
  final VoidCallback onTap;
  const _SubTabBtn(
      {required this.label,
      required this.idx,
      required this.sel,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final active = idx == sel;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppTheme.brand : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? AppTheme.brand : p.textMid,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Team label strip shown at the top / bottom of the pitch half ─────────────

class _TeamStrip extends StatelessWidget {
  final Match match;
  final bool isHome;
  final String formation;
  final List<Map<String, dynamic>> players;
  final String? coach;
  final bool alignRight;
  const _TeamStrip({
    required this.match,
    required this.isHome,
    required this.formation,
    required this.players,
    this.coach,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final team = isHome ? match.homeTeam : match.awayTeam;
    final ratings = players
        .map((pl) => (pl['rating'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    final avg = ratings.isEmpty
        ? null
        : ratings.reduce((a, b) => a + b) / ratings.length;

    // Shorten coach name to "F. Surname" style to save space.
    String? coachShort;
    if (coach != null && coach!.trim().isNotEmpty) {
      final parts = coach!.trim().split(' ');
      coachShort = parts.length > 1
          ? '${parts.first[0]}. ${parts.last}'
          : coach;
    }

    final pills = <Widget>[
      _Pill(formation, Colors.black.withValues(alpha: 0.45)),
      if (avg != null) ...[
        const SizedBox(width: 5),
        _Pill(avg.toStringAsFixed(1), _ratingColor(avg).withValues(alpha: 0.9)),
      ],
      const SizedBox(width: 5),
      Text(team.tla,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
      if (coachShort != null) ...[
        const SizedBox(width: 5),
        Text(coachShort,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 3)])),
      ],
    ];

    return Row(
      mainAxisAlignment:
          alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignRight ? pills.reversed.toList() : pills,
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(4)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}

// ─── Player chip (rendered on the pitch) ─────────────────────────────────────

class _PlayerChip extends StatelessWidget {
  final Map<String, dynamic> player;
  final Color teamColor;
  const _PlayerChip({required this.player, required this.teamColor});

  @override
  Widget build(BuildContext context) {
    final name = (player['player_name'] ?? player['name'] ?? '') as String;
    final jersey = player['jersey_number'];
    final rating = (player['rating'] as num?)?.toDouble();
    final photoUrl = player['photo_url'] as String?;
    final lastName = name.trim().isEmpty ? '?' : name.trim().split(' ').last;
    final rColor = _ratingColor(rating);

    return SizedBox(
      width: 44,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: Container(
                  width: 36,
                  height: 36,
                  color: teamColor.withValues(alpha: 0.85),
                  child: (photoUrl != null && photoUrl.isNotEmpty)
                      ? Image.network(photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _initialsWidget(name, jersey))
                      : _initialsWidget(name, jersey),
                ),
              ),
              if (jersey != null)
                Positioned(
                  top: -2,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 0.5),
                    ),
                    child: Text(
                      '$jersey',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              if (rating != null)
                Positioned(
                  bottom: -2,
                  left: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: rColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.black.withValues(alpha: 0.4),
                          width: 0.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      rating >= 10 ? '10' : rating.toStringAsFixed(1),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 6,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            _short(lastName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black54, blurRadius: 3)]),
          ),
        ],
      ),
    );
  }

  Widget _initialsWidget(String name, dynamic jersey) {
    final text = jersey?.toString() ??
        (name.trim().isEmpty
            ? '?'
            : name
                .trim()
                .split(' ')
                .map((w) => w.isEmpty ? '' : w[0])
                .join()
                .substring(0, math.min(2,
                    name.trim().split(' ').map((w) => w.isEmpty ? '' : w[0]).join().length)));
    return Center(
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900)),
    );
  }

  String _short(String s) => s.length > 8 ? '${s.substring(0, 7)}.' : s;
}

// ─── Substitutes row ──────────────────────────────────────────────────────────

class _SubRow extends StatelessWidget {
  final Map<String, dynamic> player;
  final Palette p;
  const _SubRow({required this.player, required this.p});

  @override
  Widget build(BuildContext context) {
    final name = (player['player_name'] ?? player['name'] ?? '') as String;
    final jersey = player['jersey_number'];
    final pos = player['position'] as String?;
    final rating = (player['rating'] as num?)?.toDouble();
    final rColor = _ratingColor(rating);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: p.surfaceHi,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('${jersey ?? '—'}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: p.textMid)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.textHi)),
          ),
          if (pos != null)
            Text(pos, style: TextStyle(fontSize: 11, color: p.textLow)),
          if (rating != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: rColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Unavailable player row ───────────────────────────────────────────────────

class _UnavailRow extends StatelessWidget {
  final Map<String, dynamic> player;
  final Palette p;
  const _UnavailRow({required this.player, required this.p});

  @override
  Widget build(BuildContext context) {
    final name = (player['name'] ?? player['player_name'] ?? '') as String;
    final reason = player['reason'] as String?;
    final ret = player['expectedReturn'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.person_off_outlined, size: 18, color: AppTheme.bad),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.textHi)),
                if (reason != null)
                  Text(reason,
                      style: TextStyle(fontSize: 11, color: p.textLow)),
              ],
            ),
          ),
          if (ret != null)
            Text(ret,
                style: TextStyle(
                    fontSize: 11,
                    color: p.textLow,
                    fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

// ─── Empty position chip (used on the no-lineup pitch) ───────────────────────

class _EmptyPositionChip extends StatelessWidget {
  final String label;
  final Color color;
  const _EmptyPositionChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4), width: 1),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.black54, blurRadius: 2)]),
          ),
        ],
      ),
    );
  }
}

// ─── Rating color helper ──────────────────────────────────────────────────────

Color _ratingColor(double? rating) {
  if (rating == null) return Colors.grey.shade600;
  if (rating < 6.0) return Colors.red.shade400;
  if (rating < 7.0) return Colors.orange.shade400;
  if (rating < 8.0) return Colors.amber.shade400;
  return Colors.green.shade400;
}
