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
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  const _DetailCard({required this.child, this.padding, this.margin});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 0),
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: child,
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

List<MatchIncident> _incidentsFromRaw(Map<String, dynamic> raw) {
  final list = raw['incidents'];
  if (list is! List || list.isEmpty) return const [];
  final out = <MatchIncident>[];
  for (final item in list) {
    if (item is! Map) continue;
    final j = item.cast<String, dynamic>();
    final type = (j['type'] ?? '') as String;
    final minute =
        ((j['minute'] ?? j['time'] ?? 0) as num).toInt();
    final isHome = j['is_home'] as bool? ?? false;
    String mapped;
    String? sub;
    switch (type) {
      case 'goal':
        mapped = 'goal';
        if (j['is_penalty'] == true || j['subtype'] == 'penalty') { sub = 'penalty'; }
        if (j['is_own_goal'] == true || j['subtype'] == 'ownGoal') { sub = 'ownGoal'; }
      case 'card':
        final ct = (j['card_type'] ?? j['cardType'] ?? '') as String;
        mapped = ct.toLowerCase() == 'red' ? 'redCard' : 'yellowCard';
      case 'substitution':
        mapped = 'substitution';
      default:
        mapped = type;
    }
    out.add(MatchIncident(
      minute: minute,
      type: mapped,
      player: j['player_name'] as String?,
      assistOrOff: (j['assist'] ?? j['player_out'] ?? j['playerOut'])
          as String?,
      isHome: isHome,
      subtype: sub,
    ));
  }
  out.sort((a, b) => a.minute.compareTo(b.minute));
  return out;
}

List<MatchStat> _statsFromRaw(Map<String, dynamic> raw) {
  final ls = raw['liveStats'];
  if (ls is! Map) return const [];
  final hm = ls['home'];
  final am = ls['away'];
  if (hm is! Map || am is! Map) return const [];
  final h = hm.cast<String, dynamic>();
  final a = am.cast<String, dynamic>();
  final out = <MatchStat>[];
  void add(String label, String key) {
    final hv = h[key];
    final av = a[key];
    if (hv != null || av != null) {
      out.add(MatchStat(
          name: label, homeValue: '$hv', awayValue: '$av'));
    }
  }
  add('Possession', 'possession');
  add('Shots', 'shots');
  add('Shots on Target', 'shotsOnTarget');
  add('Corners', 'corners');
  add('Fouls', 'fouls');
  add('Yellow Cards', 'yellowCards');
  add('Offsides', 'offsides');
  add('Passes', 'passes');
  add('Pass Accuracy', 'passAccuracy');
  return out;
}

// ─── Public re-export so other files can use SectionLabel ────────────────────
// (kept for backward-compat with any existing usage)
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => _SectionLabel(text);
}
