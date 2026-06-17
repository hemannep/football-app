// match_details_shared.dart
//
// Shared building blocks: SectionLabel, DetailCard, Unavailable, and the
// public SectionLabel re-export. Part of the match_details library.

part of 'match_details_screen.dart';

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
            color: AppTheme.of(context).textLow),
      ),
    );
  }
}

/// A standardised card wrapper used throughout the detail tabs.
class _DetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  const _DetailCard({required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: child,
    );
  }
}

class _PlayerPhotoAvatar extends ConsumerWidget {
  final String name;
  final String? teamHint;
  final String? photoUrl;
  final double size;
  final Color fallbackColor;
  final dynamic jersey;
  const _PlayerPhotoAvatar({
    required this.name,
    this.teamHint,
    this.photoUrl,
    this.size = 36,
    this.fallbackColor = AppTheme.brand,
    this.jersey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direct = photoUrl?.trim();
    final async = (direct == null || direct.isEmpty)
        ? ref.watch(_playerPhotoProvider('$name\u001f${teamHint ?? ''}'))
        : null;
    final resolved = (direct != null && direct.isNotEmpty)
        ? direct
        : async?.maybeWhen(data: (v) => v, orElse: () => null);

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: fallbackColor.withValues(alpha: 0.9),
        child: resolved != null && resolved.isNotEmpty
            ? Image.network(
                resolved,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    final trimmed = name.trim();
    final initials = trimmed.isEmpty
        ? '?'
        : trimmed
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .map((p) => p[0])
            .take(2)
            .join()
            .toUpperCase();
    return Center(
      child: Text(
        jersey?.toString() ?? initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Centred "no data" placeholder with icon, message and optional hint.
class _Unavailable extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;
  const _Unavailable({required this.icon, required this.message, this.hint});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    // Use LayoutBuilder so we size to whatever the parent gives us:
    //   • As a full-screen tab body: parent provides finite constraints,
    //     we fill them.
    //   • As a child inside a ListView: parent provides 0..∞ height,
    //     we shrink to content and add some breathing-room padding.
    return LayoutBuilder(
      builder: (context, constraints) {
        final fillsSpace = constraints.maxHeight.isFinite;
        final content = Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: p.surfaceHi,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: p.textLow),
              ),
              const SizedBox(height: 14),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p.textMid)),
              if (hint != null) ...[
                const SizedBox(height: 5),
                Text(hint!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: p.textLow)),
              ],
            ],
          ),
        );

        if (fillsSpace) {
          // Tab body — fill the space + paint background.
          return Container(
            color: p.bg,
            width: double.infinity,
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          );
        }
        // Inside a ListView or other unbounded parent — render compactly.
        return Container(
          color: p.bg,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(child: content),
        );
      },
    );
  }
}

// ─── Bzzoiro / relay field converters (used by all tab part files) ────────────
//
// Each helper reads a field from the raw Firestore doc and converts it into
// the strongly-typed model the existing tab widgets already know how to render.
// All helpers are null-safe: missing / wrong-typed fields produce empty output.

// Extracts a name from either a plain string or a {"name": "..."} map.
String? _extractName(dynamic v) {
  if (v == null) return null;
  if (v is String) return v.trim().isEmpty ? null : v.trim();
  if (v is Map) {
    final n = v['name'];
    if (n is String && n.trim().isNotEmpty) return n.trim();
  }
  return null;
}

List<MatchIncident> _incidentsFromRaw(Map<String, dynamic> raw) {
  final out = <MatchIncident>[];

  // ── Helper: determine if an event belongs to the home team ──────────────────
  final homeTeamId = (raw['homeTeam'] as Map?)?['id'];
  final homeTeamTla = (raw['homeTeam'] as Map?)?['tla'] as String?;

  bool isHomeFor(Map<String, dynamic> j, {dynamic teamId, String? teamTla}) {
    // Explicit boolean flag wins.
    if (j['is_home'] is bool) return j['is_home'] as bool;
    final side = (j['side'] ?? j['team_side'] ?? '').toString().toLowerCase();
    if (side == 'home') return true;
    if (side == 'away') return false;
    // Match by numeric team id.
    if (homeTeamId != null && teamId != null && teamId == homeTeamId) {
      return true;
    }
    if (homeTeamId != null && teamId != null) return false;
    // Match by TLA string.
    if (homeTeamTla != null && teamTla != null && teamTla.isNotEmpty) {
      return teamTla == homeTeamTla;
    }
    return false;
  }

  // ── Source 1: unified incidents array (Bzzoiro / API-Football events) ───────
  final incidentsList = raw['incidents'];
  if (incidentsList is List && incidentsList.isNotEmpty) {
    for (final item in incidentsList) {
      if (item is! Map) continue;
      final j = item.cast<String, dynamic>();

      final rawType =
          (j['type'] ?? j['incident_type'] ?? '').toString().toLowerCase();
      final minuteRaw = j['minute'] ??
          j['time'] ??
          (j['time'] is Map ? (j['time'] as Map)['elapsed'] : null) ??
          0;
      final minute = (minuteRaw as num).toInt();

      // Team identification for isHome
      final teamId = j['team'] is Map ? (j['team'] as Map)['id'] : null;
      final teamTla = j['team'] is Map
          ? (j['team'] as Map)['tla'] as String?
          : j['team'] as String?;
      final isHome = isHomeFor(j, teamId: teamId, teamTla: teamTla);

      String mapped;
      String? sub;

      if (rawType.contains('goal')) {
        mapped = 'goal';
        if (rawType.contains('own') ||
            j['is_own_goal'] == true ||
            j['subtype'] == 'ownGoal') {
          sub = 'ownGoal';
        }
        if (rawType.contains('pen') ||
            j['is_penalty'] == true ||
            j['subtype'] == 'penalty') {
          sub = 'penalty';
        }
      } else if (rawType.contains('red') || rawType.contains('yellowred')) {
        mapped = 'redCard';
      } else if (rawType.contains('yellow') || rawType.contains('card')) {
        final ct =
            (j['card_type'] ?? j['cardType'] ?? j['card'] ?? j['detail'] ?? '')
                .toString()
                .toLowerCase();
        mapped = ct.contains('red') ? 'redCard' : 'yellowCard';
      } else if (rawType.contains('sub')) {
        mapped = 'substitution';
      } else {
        continue;
      }

      out.add(MatchIncident(
        minute: minute,
        type: mapped,
        player: _extractName(
            j['player_name'] ?? j['player'] ?? j['scorer'] ?? j['player_in']),
        assistOrOff: _extractName(
            j['assist'] ?? j['assistant'] ?? j['player_out'] ?? j['playerOut']),
        isHome: isHome,
        subtype: sub,
      ));
    }
    if (out.isNotEmpty) {
      out.sort((a, b) => a.minute.compareTo(b.minute));
      return out;
    }
  }

  // ── Source 2: relay.js format — separate goals / bookings / substitutions ───
  // goals: [{ minute, type, scorer: {name}, assist: {name}, team: {id, tla} }]
  final goals = raw['goals'];
  if (goals is List) {
    for (final item in goals) {
      if (item is! Map) continue;
      final j = item.cast<String, dynamic>();
      final minute = ((j['minute'] ?? 0) as num).toInt();
      final teamId = (j['team'] as Map?)?['id'];
      final teamTla = (j['team'] as Map?)?['tla'] as String?;
      final type = (j['type'] ?? 'REGULAR').toString().toUpperCase();
      out.add(MatchIncident(
        minute: minute,
        type: 'goal',
        player: _extractName(j['scorer'] ?? j['player_name'] ?? j['player']),
        assistOrOff: _extractName(j['assist'] ?? j['assistant']),
        isHome: isHomeFor(j, teamId: teamId, teamTla: teamTla),
        subtype: type == 'OWN'
            ? 'ownGoal'
            : type == 'PENALTY'
                ? 'penalty'
                : null,
      ));
    }
  }

  // bookings: [{ minute, player: string, team: string (TLA), card: 'YELLOW'/'RED' }]
  final bookings = raw['bookings'];
  if (bookings is List) {
    for (final item in bookings) {
      if (item is! Map) continue;
      final j = item.cast<String, dynamic>();
      final minute = ((j['minute'] ?? 0) as num).toInt();
      final card = (j['card'] ?? 'YELLOW').toString().toUpperCase();
      final teamTla = j['team'] as String?;
      out.add(MatchIncident(
        minute: minute,
        type: card.contains('RED') ? 'redCard' : 'yellowCard',
        player: _extractName(j['player'] ?? j['player_name']),
        assistOrOff: null,
        isHome: isHomeFor(j, teamTla: teamTla),
        subtype: null,
      ));
    }
  }

  // substitutions: [{ minute, playerIn: string, playerOut: string, team: string (TLA) }]
  final subs = raw['substitutions'];
  if (subs is List) {
    for (final item in subs) {
      if (item is! Map) continue;
      final j = item.cast<String, dynamic>();
      final minute = ((j['minute'] ?? 0) as num).toInt();
      final teamTla = j['team'] as String?;
      out.add(MatchIncident(
        minute: minute,
        type: 'substitution',
        player: _extractName(j['playerIn'] ?? j['player_in'] ?? j['player']),
        assistOrOff: _extractName(j['playerOut'] ?? j['player_out']),
        isHome: isHomeFor(j, teamTla: teamTla),
        subtype: null,
      ));
    }
  }

  out.sort((a, b) => a.minute.compareTo(b.minute));
  return out;
}

// Normalize an API-Football "type" string to a camelCase key.
String _apifbTypeToKey(String type) {
  switch (type.toLowerCase().trim()) {
    case 'shots on goal':
      return 'shotsOnGoal';
    case 'shots on target':
      return 'shotsOnGoal';
    case 'shots off goal':
      return 'shotsOffGoal';
    case 'shots off target':
      return 'shotsOffGoal';
    case 'total shots':
      return 'totalShots';
    case 'blocked shots':
      return 'blockedShots';
    case 'shots insidebox':
      return 'shotsInsideBox';
    case 'shots outsidebox':
      return 'shotsOutsideBox';
    case 'fouls':
      return 'fouls';
    case 'corner kicks':
      return 'cornerKicks';
    case 'offsides':
      return 'offsides';
    case 'ball possession':
      return 'ballPossession';
    case 'yellow cards':
      return 'yellowCards';
    case 'red cards':
      return 'redCards';
    case 'goalkeeper saves':
      return 'saves';
    case 'total passes':
      return 'passes';
    case 'passes accurate':
      return 'passAccurate';
    case 'passes %':
      return 'passAccuracy';
    case 'expected_goals':
      return 'xg';
    default:
      return '';
  }
}

List<MatchStat> _statsFromRaw(Map<String, dynamic> raw) {
  final ls = raw['liveStats'];
  if (ls is! Map) return const [];
  final hm = ls['home'];
  final am = ls['away'];
  if (hm is! Map || am is! Map) return const [];
  // Use mutable maps so we can inject flattened API-Football array data.
  final h = Map<String, dynamic>.from(hm.cast<String, dynamic>());
  final a = Map<String, dynamic>.from(am.cast<String, dynamic>());

  // If liveStats stores API-Football statistics arrays, flatten them into h/a.
  void flattenStatsList(Map<String, dynamic> target, dynamic statsList) {
    if (statsList is! List) return;
    for (final s in statsList) {
      if (s is! Map) continue;
      final type = (s['type'] ?? '').toString();
      final key = _apifbTypeToKey(type);
      if (key.isNotEmpty) target.putIfAbsent(key, () => s['value']);
    }
  }

  flattenStatsList(h, h['statistics']);
  flattenStatsList(a, a['statistics']);

  final out = <MatchStat>[];

  String fmt(dynamic v, {bool pct = false}) {
    if (v == null) return '—';
    final s = '$v';
    if (s == 'null') return '—';
    if (pct && !s.contains('%')) return '$s%';
    return s;
  }

  // Try multiple key names for the same stat (different relay normalizations).
  void add(String label, List<String> keys, {bool pct = false}) {
    dynamic hv, av;
    for (final key in keys) {
      hv ??= h[key];
      av ??= a[key];
      if (hv != null && av != null) break;
    }
    if (hv != null || av != null) {
      out.add(MatchStat(
          name: label,
          homeValue: fmt(hv, pct: pct),
          awayValue: fmt(av, pct: pct)));
    }
  }

  add('Shots on Goal', ['shotsOnGoal', 'shotsOnTarget', 'onTarget']);
  add('Shots off Goal', ['shotsOffGoal', 'shotsOff', 'offTarget']);
  add('Total Shots', ['totalShots', 'shots']);
  add('Blocked Shots', ['blockedShots']);
  add('Shots inside Box', ['shotsInsideBox', 'shotsInBox']);
  add('Shots outside Box', ['shotsOutsideBox', 'shotsOutBox']);
  add('Ball Possession', ['ballPossession', 'possession'], pct: true);
  add('Passes', ['passes', 'totalPasses']);
  add('Pass Accuracy', ['passAccuracy', 'passesPercentage'], pct: true);
  add('Corner Kicks', ['cornerKicks', 'corners']);
  add('Fouls', ['fouls']);
  add('Yellow Cards', ['yellowCards']);
  add('Red Cards', ['redCards']);
  add('Offsides', ['offsides']);
  add('Saves', ['saves', 'goalkeeperSaves']);
  add('Tackles', ['tackles']);
  // Remove rows where both sides are "—"
  return out.where((s) => s.homeValue != '—' || s.awayValue != '—').toList();
}

// ─── Public re-export so other files can use SectionLabel ────────────────────
// (kept for backward-compat with any existing usage)
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => _SectionLabel(text);
}
