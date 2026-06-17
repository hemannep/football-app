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

    // ── Data sources (in priority order) ───────────────────────────────────
    final rawAsync = ref.watch(_rawMatchProvider(widget.match));
    final lineupCollAsync = ref.watch(lineupProvider(widget.match.id));
    final bsdAsync = ref.watch(_bsdLineupsProvider(widget.match));
    final sdbAsync = ref.watch(_sdbLineupsProvider(widget.match));

    // Show spinner only when ALL sources are still loading (no data yet).
    final anyLoading = rawAsync.isLoading &&
        lineupCollAsync.isLoading &&
        bsdAsync.isLoading &&
        sdbAsync.isLoading;
    if (anyLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final raw = rawAsync.value;
    final lineupColl = lineupCollAsync.value;

    // ── Determine which lineup to use ───────────────────────────────────────
    // Priority:
    //   1. bzzLineups  (relay → Bzzoiro enricher, most complete)
    //   2. confirmedLineup in match doc (relay → API-Football merge)
    //   3. lineups/{matchId} collection (relay fallback)
    //   4. BSD via MatchDetailsResolver (direct API call)
    //   5. TheSportsDB (secondary API fallback)
    //   6. bzzPredictedLineup (pre-match prediction)
    //   7. null → empty pitch / not-available state
    final bzzLineupsList = raw?['bzzLineups'];
    final hasBzzLineups = bzzLineupsList is List && bzzLineupsList.isNotEmpty;

    final confirmedLineupMap = raw?['confirmedLineup'];
    final hasConfirmedLineup = confirmedLineupMap is Map &&
        (confirmedLineupMap['home'] != null ||
            confirmedLineupMap['away'] != null);

    // lineups collection supports two formats:
    //  • relay format: {home: {startXI:[...], substitutes:[...]}, away:{...}}
    //  • client crowd-cache: {flatLineups: [{is_home, is_starter, name,...}]}
    final hasLineupColl = lineupColl != null &&
        (lineupColl['home'] != null ||
            lineupColl['away'] != null ||
            (lineupColl['flatLineups'] is List &&
                (lineupColl['flatLineups'] as List).isNotEmpty));

    final bsdLineups = bsdAsync.value;
    final hasBsd = bsdLineups != null &&
        (bsdLineups.home != null || bsdLineups.away != null);

    final sdbLineups = sdbAsync.value;
    final hasSdb = sdbLineups != null &&
        (sdbLineups.home != null || sdbLineups.away != null);

    final hasAnyActual = hasBzzLineups ||
        hasConfirmedLineup ||
        hasLineupColl ||
        hasBsd ||
        hasSdb;
    final isActual = hasAnyActual &&
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
      // Prefer the flat list written by client crowd-cache; fall back to
      // the relay's startXI/substitutes format if flat isn't present.
      if (lineupColl['flatLineups'] is List &&
          (lineupColl['flatLineups'] as List).isNotEmpty) {
        lineupList = (lineupColl['flatLineups'] as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      } else {
        lineupList =
            _convertConfirmedLineup(Map<String, dynamic>.from(lineupColl));
      }
      isPredicted = false;
    } else if (hasBsd) {
      lineupList = _convertBsdLineups(bsdLineups);
      isPredicted = false;
    } else if (hasSdb) {
      lineupList = _convertSdbLineups(sdbLineups);
      isPredicted = false;
    } else if (raw?['bzzPredictedLineup'] is List) {
      lineupList = raw!['bzzPredictedLineup'] as List;
      isPredicted = !isActual;
    } else {
      lineupList = null;
      isPredicted = false;
    }

    // Show a subtle loading pill while secondary sources are still resolving
    // but we already have something to display.
    final stillResolving =
        lineupList == null && (bsdAsync.isLoading || sdbAsync.isLoading);

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
    if (!hasBzzLineups && hasLineupColl) {
      homeFormation = lineupColl['homeFormation']?.toString() ?? homeFormation;
      awayFormation = lineupColl['awayFormation']?.toString() ?? awayFormation;
      homeCoach ??= lineupColl['homeCoach']?.toString();
      awayCoach ??= lineupColl['awayCoach']?.toString();
    }
    if (!hasBzzLineups && !hasConfirmedLineup && hasBsd) {
      homeFormation = bsdLineups.home?.formation ?? homeFormation;
      awayFormation = bsdLineups.away?.formation ?? awayFormation;
    }
    if (!hasBzzLineups && !hasConfirmedLineup && !hasBsd && hasSdb) {
      homeFormation = sdbLineups.home?.formation ?? homeFormation;
      awayFormation = sdbLineups.away?.formation ?? awayFormation;
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
        homeSubs: homeSubs,
        awaySubs: awaySubs,
        homeFormation: homeFormation,
        awayFormation: awayFormation,
        homeCoach: homeCoach,
        awayCoach: awayCoach,
        isPredicted: isPredicted,
        lineupList: lineupList,
        stillResolving: stillResolving,
      );
    }

    return Column(
      children: [
        // ── Sub-tab selector ──────────────────────────────────────────
        Container(
          color: p.bg,
          child: Row(
            children: [
              _SubTabBtn(
                  label: 'Lineup',
                  idx: 0,
                  sel: _subTab,
                  onTap: () => setState(() => _subTab = 0)),
              _SubTabBtn(
                  label: 'Subs',
                  idx: 1,
                  sel: _subTab,
                  onTap: () => setState(() => _subTab = 1)),
              _SubTabBtn(
                  label: 'Injuries',
                  idx: 2,
                  sel: _subTab,
                  onTap: () => setState(() => _subTab = 2)),
              _SubTabBtn(
                  label: 'Suspensions',
                  idx: 3,
                  sel: _subTab,
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
    required List<Map<String, dynamic>> homeSubs,
    required List<Map<String, dynamic>> awaySubs,
    required String homeFormation,
    required String awayFormation,
    String? homeCoach,
    String? awayCoach,
    required bool isPredicted,
    required List? lineupList,
    bool stillResolving = false,
  }) {
    if (lineupList == null) {
      if (stillResolving) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Fetching lineup data…',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        );
      }
      if (widget.match.isFinished || widget.match.isLive) {
        return const _Unavailable(
          icon: Icons.groups_outlined,
          message: 'Lineups not available for this match.',
          hint: 'No lineup data found from any source for this competition.',
        );
      }
      return _buildEmptyPitch(context);
    }

    final hasCompleteXi =
        homeStarters.length >= 10 && awayStarters.length >= 10;
    if (!hasCompleteXi) {
      return _buildPartialLineupView(
        p: AppTheme.of(context),
        homeStarters: homeStarters,
        awayStarters: awayStarters,
        homeSubs: homeSubs,
        awaySubs: awaySubs,
        isPredicted: isPredicted,
      );
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
                    border:
                        Border.all(color: AppTheme.warn.withValues(alpha: 0.4)),
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
                          teamHint: widget.match.homeTeam.name,
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
                          teamHint: widget.match.awayTeam.name,
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

  Widget _buildPartialLineupView({
    required Palette p,
    required List<Map<String, dynamic>> homeStarters,
    required List<Map<String, dynamic>> awayStarters,
    required List<Map<String, dynamic>> homeSubs,
    required List<Map<String, dynamic>> awaySubs,
    required bool isPredicted,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
      children: [
        _LineupNotice(
          icon: Icons.info_outline_rounded,
          title: isPredicted ? 'Predicted lineup data' : 'Partial lineup data',
          message:
              'The provider only returned ${homeStarters.length} ${widget.match.homeTeam.tla} starter(s) and ${awayStarters.length} ${widget.match.awayTeam.tla} starter(s). Showing verified player rows instead of a misleading full pitch.',
        ),
        const SizedBox(height: 12),
        _LineupTeamList(
          title: widget.match.homeTeam.name,
          tla: widget.match.homeTeam.tla,
          players: homeStarters,
          subs: homeSubs,
          teamHint: widget.match.homeTeam.name,
          color: AppTheme.brand,
          p: p,
        ),
        const SizedBox(height: 12),
        _LineupTeamList(
          title: widget.match.awayTeam.name,
          tla: widget.match.awayTeam.tla,
          players: awayStarters,
          subs: awaySubs,
          teamHint: widget.match.awayTeam.name,
          color: AppTheme.live,
          p: p,
        ),
      ],
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
    final homePos =
        formationPositions(formation: formation, isHome: true, playerCount: 11);
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
                const Icon(Icons.schedule_rounded,
                    size: 13, color: AppTheme.warn),
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
                    for (int i = 0;
                        i < math.min(homePos.length, homeLabels.length);
                        i++)
                      Positioned(
                        left: homePos[i].dx * pw - 18,
                        top: homePos[i].dy * ph - 18,
                        child: _EmptyPositionChip(
                            label: homeLabels[i], color: AppTheme.brand),
                      ),
                    for (int i = 0;
                        i < math.min(awayPos.length, awayLabels.length);
                        i++)
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
        if (count == 1) {
          labels.add('ST');
        } else if (count == 2) {
          labels.addAll(['ST', 'ST']);
        } else if (count == 3) {
          labels.addAll(['LW', 'ST', 'RW']);
        } else {
          labels.addAll(List.generate(count, (_) => 'FW'));
        }
      } else if (ri == 1) {
        if (count == 3) {
          labels.addAll(['LB', 'CB', 'RB']);
        } else if (count == 4) {
          labels.addAll(['LB', 'CB', 'CB', 'RB']);
        } else if (count == 5) {
          labels.addAll(['LWB', 'CB', 'CB', 'CB', 'RWB']);
        } else {
          labels.addAll(List.generate(count, (_) => 'DEF'));
        }
      } else {
        if (count == 1) {
          labels.add('DM');
        } else if (count == 2) {
          labels.addAll(['CM', 'CM']);
        } else if (count == 3) {
          labels.addAll(['CM', 'CM', 'CM']);
        } else {
          labels.addAll(List.generate(count, (_) => 'MID'));
        }
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

  // ── BSD MatchLineups → flat bzzLineups-compatible list ─────────────────────

  static List<Map<String, dynamic>>? _convertBsdLineups(MatchLineups? ml) {
    if (ml == null) return null;
    final out = <Map<String, dynamic>>[];
    void addSide(TeamLineup? side, bool isHome) {
      if (side == null) return;
      for (final p in side.starters) {
        out.add({
          'name': p.name,
          'player_name': p.name,
          'jersey_number': p.shirtNumber,
          'position': p.position,
          'is_home': isHome,
          'is_starter': true,
        });
      }
      for (final p in side.bench) {
        out.add({
          'name': p.name,
          'player_name': p.name,
          'jersey_number': p.shirtNumber,
          'position': p.position,
          'is_home': isHome,
          'is_starter': false,
        });
      }
    }

    addSide(ml.home, true);
    addSide(ml.away, false);
    return out.isEmpty ? null : out;
  }

  // ── TheSportsDB SdbMatchLineups → flat bzzLineups-compatible list ───────────

  static List<Map<String, dynamic>>? _convertSdbLineups(SdbMatchLineups? ml) {
    if (ml == null) return null;
    final out = <Map<String, dynamic>>[];
    void addSide(SdbTeamLineup? side, bool isHome) {
      if (side == null) return;
      for (final p in side.starters) {
        out.add({
          'name': p.name,
          'player_name': p.name,
          'jersey_number': p.shirtNumber,
          'position': p.position,
          'is_home': isHome,
          'is_starter': true,
        });
      }
      for (final p in side.bench) {
        out.add({
          'name': p.name,
          'player_name': p.name,
          'jersey_number': p.shirtNumber,
          'position': p.position,
          'is_home': isHome,
          'is_starter': false,
        });
      }
    }

    addSide(ml.home, true);
    addSide(ml.away, false);
    return out.isEmpty ? null : out;
  }

  // ── Subs list ───────────────────────────────────────────────────────────────

  Widget _buildSubsList(Palette p, List<Map<String, dynamic>> homeSubs,
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
          ...homeSubs.map((pl) => _SubRow(
                player: pl,
                p: p,
                teamHint: widget.match.homeTeam.name,
                color: AppTheme.brand,
              )),
        const SizedBox(height: 12),
        _SectionLabel('${widget.match.awayTeam.tla} — Substitutes'),
        if (awaySubs.isEmpty)
          _emptyRow(p, 'None listed')
        else
          ...awaySubs.map((pl) => _SubRow(
                player: pl,
                p: p,
                teamHint: widget.match.awayTeam.name,
                color: AppTheme.live,
              )),
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

  Widget _buildUnavailList(Palette p, List<Map<String, dynamic>> home,
      List<Map<String, dynamic>> away, String title, IconData icon) {
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
          ...home.map((pl) => _UnavailRow(
                player: pl,
                p: p,
                teamHint: widget.match.homeTeam.name,
                color: AppTheme.brand,
              )),
        const SizedBox(height: 12),
        _SectionLabel('${widget.match.awayTeam.tla} — $title'),
        if (away.isEmpty)
          _emptyRow(p, 'None reported')
        else
          ...away.map((pl) => _UnavailRow(
                player: pl,
                p: p,
                teamHint: widget.match.awayTeam.name,
                color: AppTheme.live,
              )),
      ],
    );
  }

  Widget _emptyRow(Palette p, String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Text(msg,
            style: TextStyle(
                fontSize: 13, color: p.textLow, fontStyle: FontStyle.italic)),
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
    final coachVal = coach;
    if (coachVal != null && coachVal.trim().isNotEmpty) {
      final parts = coachVal.trim().split(' ');
      coachShort =
          parts.length > 1 ? '${parts.first[0]}. ${parts.last}' : coach;
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
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
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
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800)),
      );
}

// ─── Player chip (rendered on the pitch) ─────────────────────────────────────

class _PlayerChip extends StatelessWidget {
  final Map<String, dynamic> player;
  final Color teamColor;
  final String? teamHint;
  const _PlayerChip({
    required this.player,
    required this.teamColor,
    this.teamHint,
  });

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
              GestureDetector(
                onTap: name.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PlayerDetailScreen(
                            name: name,
                            teamHint: teamHint,
                            shirtNumber: jersey is int
                                ? jersey
                                : int.tryParse(jersey?.toString() ?? ''),
                            position: player['position'] as String?,
                          ),
                        )),
                child: _PlayerPhotoAvatar(
                  name: name,
                  teamHint: teamHint,
                  photoUrl: photoUrl,
                  size: 36,
                  fallbackColor: teamColor,
                  jersey: jersey,
                ),
              ),
              if (jersey != null)
                Positioned(
                  top: -2,
                  right: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 0.5),
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

  String _short(String s) => s.length > 8 ? '${s.substring(0, 7)}.' : s;
}

class _LineupNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _LineupNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warn.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: AppTheme.warn.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.warn, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.warn,
                        fontWeight: FontWeight.w900,
                        fontSize: 12)),
                const SizedBox(height: 3),
                Text(message,
                    style: TextStyle(
                        fontSize: 11, height: 1.35, color: p.textMid)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineupTeamList extends StatelessWidget {
  final String title;
  final String tla;
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> subs;
  final String teamHint;
  final Color color;
  final Palette p;
  const _LineupTeamList({
    required this.title,
    required this.tla,
    required this.players,
    required this.subs,
    required this.teamHint,
    required this.color,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: p.textHi,
                        fontWeight: FontWeight.w900,
                        fontSize: 14)),
              ),
              _Pill('${players.length}/11', color.withValues(alpha: 0.9)),
            ],
          ),
          const SizedBox(height: 10),
          if (players.isEmpty)
            Text('No starters returned yet.',
                style: TextStyle(color: p.textLow, fontSize: 12))
          else
            ...players.map((pl) => _LineupPlayerRow(
                  player: pl,
                  p: p,
                  teamHint: teamHint,
                  color: color,
                )),
          if (subs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Substitutes',
                style: TextStyle(
                    color: p.textLow,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2)),
            const SizedBox(height: 6),
            ...subs.take(12).map((pl) => _LineupPlayerRow(
                  player: pl,
                  p: p,
                  teamHint: teamHint,
                  color: color,
                  compact: true,
                )),
          ],
        ],
      ),
    );
  }
}

class _LineupPlayerRow extends StatelessWidget {
  final Map<String, dynamic> player;
  final Palette p;
  final String teamHint;
  final Color color;
  final bool compact;
  const _LineupPlayerRow({
    required this.player,
    required this.p,
    required this.teamHint,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = (player['player_name'] ?? player['name'] ?? '').toString();
    final jersey = player['jersey_number'];
    final pos = player['position']?.toString();
    final photoUrl = player['photo_url'] as String?;
    return InkWell(
      onTap: name.trim().isEmpty
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlayerDetailScreen(
                  name: name,
                  teamHint: teamHint,
                  shirtNumber: jersey is int
                      ? jersey
                      : int.tryParse(jersey?.toString() ?? ''),
                  position: pos,
                ),
              )),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
        child: Row(
          children: [
            _PlayerPhotoAvatar(
              name: name,
              teamHint: teamHint,
              photoUrl: photoUrl,
              size: compact ? 30 : 36,
              fallbackColor: color,
              jersey: jersey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name.isEmpty ? 'Unknown player' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: p.textHi,
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w700)),
            ),
            if (pos != null && pos.isNotEmpty)
              Text(pos,
                  style: TextStyle(
                      color: p.textLow,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ─── Substitutes row ──────────────────────────────────────────────────────────

class _SubRow extends StatelessWidget {
  final Map<String, dynamic> player;
  final Palette p;
  final String teamHint;
  final Color color;
  const _SubRow({
    required this.player,
    required this.p,
    required this.teamHint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final name = (player['player_name'] ?? player['name'] ?? '').toString();
    final jersey = player['jersey_number'];
    final pos = player['position']?.toString();
    final rating = (player['rating'] as num?)?.toDouble();
    final photoUrl =
        (player['photo_url'] ?? player['photoUrl'] ?? player['imageUrl'])
            ?.toString();
    final rColor = _ratingColor(rating);
    return InkWell(
      onTap: name.trim().isEmpty
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlayerDetailScreen(
                  name: name,
                  teamHint: teamHint,
                  shirtNumber: jersey is int
                      ? jersey
                      : int.tryParse(jersey?.toString() ?? ''),
                  position: pos,
                ),
              )),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _PlayerPhotoAvatar(
              name: name,
              teamHint: teamHint,
              photoUrl: photoUrl,
              size: 34,
              fallbackColor: color,
              jersey: jersey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name.isEmpty ? 'Unknown player' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: p.textHi)),
            ),
            if (pos != null && pos.isNotEmpty)
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
      ),
    );
  }
}

// ─── Unavailable player row ───────────────────────────────────────────────────

class _UnavailRow extends StatelessWidget {
  final Map<String, dynamic> player;
  final Palette p;
  final String teamHint;
  final Color color;
  const _UnavailRow({
    required this.player,
    required this.p,
    required this.teamHint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final name = (player['name'] ?? player['player_name'] ?? '').toString();
    final reason = player['reason'] as String?;
    final ret = player['expectedReturn'] as String?;
    final jersey = player['jersey_number'] ?? player['number'];
    final pos = player['position']?.toString();
    final photoUrl =
        (player['photo_url'] ?? player['photoUrl'] ?? player['imageUrl'])
            ?.toString();
    return InkWell(
      onTap: name.trim().isEmpty
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlayerDetailScreen(
                  name: name,
                  teamHint: teamHint,
                  shirtNumber: jersey is int
                      ? jersey
                      : int.tryParse(jersey?.toString() ?? ''),
                  position: pos,
                ),
              )),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _PlayerPhotoAvatar(
                  name: name,
                  teamHint: teamHint,
                  photoUrl: photoUrl,
                  size: 34,
                  fallbackColor: color,
                  jersey: jersey,
                ),
                const Positioned(
                  right: -2,
                  bottom: -2,
                  child: Icon(Icons.person_off_outlined,
                      size: 14, color: AppTheme.bad),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Unknown player' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.textHi)),
                  if (reason != null)
                    Text(reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
