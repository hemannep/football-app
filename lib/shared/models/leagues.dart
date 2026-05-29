import 'package:flutter/material.dart';

/// All competitions available on the football-data.org FREE tier.
/// World Cup is intentionally first — top priority for this app.
class League {
  final String code; // football-data.org competition code
  final String name;
  final String country;
  final IconData icon;
  final bool isKnockout; // true → bracket view makes sense
  final int sortPriority; // lower = shown first

  const League({
    required this.code,
    required this.name,
    required this.country,
    required this.icon,
    this.isKnockout = false,
    this.sortPriority = 100,
  });
}

class Leagues {
  static const wc = League(
    code: 'WC',
    name: 'World Cup 2026',
    country: 'World',
    icon: Icons.emoji_events_rounded,
    isKnockout: true,
    sortPriority: 0,
  );

  static const cl = League(
    code: 'CL',
    name: 'Champions League',
    country: 'Europe',
    icon: Icons.workspace_premium_rounded,
    isKnockout: true,
    sortPriority: 1,
  );

  static const ec = League(
    code: 'EC',
    name: 'European Championship',
    country: 'Europe',
    icon: Icons.public_rounded,
    isKnockout: true,
    sortPriority: 2,
  );

  static const pl = League(
    code: 'PL',
    name: 'Premier League',
    country: 'England',
    icon: Icons.sports_soccer_rounded,
    sortPriority: 10,
  );

  static const pd = League(
    code: 'PD',
    name: 'La Liga',
    country: 'Spain',
    icon: Icons.sports_soccer_rounded,
    sortPriority: 11,
  );

  static const bl1 = League(
    code: 'BL1',
    name: 'Bundesliga',
    country: 'Germany',
    icon: Icons.sports_soccer_rounded,
    sortPriority: 12,
  );

  static const sa = League(
    code: 'SA',
    name: 'Serie A',
    country: 'Italy',
    icon: Icons.sports_soccer_rounded,
    sortPriority: 13,
  );

  static const fl1 = League(
    code: 'FL1',
    name: 'Ligue 1',
    country: 'France',
    icon: Icons.sports_soccer_rounded,
    sortPriority: 14,
  );

  static const dn1 = League(
    code: 'DED',
    name: 'Eredivisie',
    country: 'Netherlands',
    icon: Icons.sports_soccer_rounded,
    sortPriority: 15,
  );

  static const pt1 = League(
    code: 'PPL',
    name: 'Primeira Liga',
    country: 'Portugal',
    icon: Icons.sports_soccer_rounded,
    sortPriority: 16,
  );

  static const elc = League(
    code: 'ELC',
    name: 'Championship',
    country: 'England',
    icon: Icons.sports_soccer_rounded,
    sortPriority: 17,
  );

  static const bsa = League(
    code: 'BSA',
    name: 'Brazil Série A',
    country: 'Brazil',
    icon: Icons.sports_soccer_rounded,
    sortPriority: 18,
  );

  static const all = <League>[
    wc,
    cl,
    ec,
    pl,
    pd,
    bl1,
    sa,
    fl1,
    dn1,
    pt1,
    elc,
    bsa,
  ];

  static League fromCode(String code) =>
      all.firstWhere((l) => l.code == code, orElse: () => wc);
}
