// lib/core/services/rivalries_service.dart
//
// Spec feature #13 — Rivalry Explainers.
//
// Static rivalry catalogue. Each rivalry stores the two TLAs, a name, the
// historical context, and a few memorable encounters. The matchups are
// keyed by an unordered TLA pair so the lookup works regardless of which
// team is "home".

class Rivalry {
  final String name;
  final String tla1;
  final String tla2;
  final String region; // 'South America', 'Europe', 'CONCACAF' …
  final String origin; // 1-2 sentence backstory
  final List<String> moments; // bullet-point memorable encounters
  final String? nickname; // e.g. "El Clásico", "Superclásico"
  const Rivalry({
    required this.name,
    required this.tla1,
    required this.tla2,
    required this.region,
    required this.origin,
    required this.moments,
    this.nickname,
  });

  bool involves(String a, String b) {
    final aa = a.toUpperCase();
    final bb = b.toUpperCase();
    return (tla1 == aa && tla2 == bb) || (tla1 == bb && tla2 == aa);
  }
}

class RivalriesService {
  /// Returns the rivalry for these two team TLAs, or null if not a
  /// recognised rivalry.
  static Rivalry? find(String tlaA, String tlaB) {
    for (final r in _all) {
      if (r.involves(tlaA, tlaB)) return r;
    }
    return null;
  }

  /// Returns all rivalries (for a future "Rivalries" hub screen).
  static List<Rivalry> all() => List.unmodifiable(_all);

  // ─── National-team rivalries ─────────────────────────────────────────────

  static const _all = <Rivalry>[
    Rivalry(
      name: 'Brazil vs Argentina',
      tla1: 'BRA',
      tla2: 'ARG',
      region: 'South America',
      nickname: 'Superclásico de las Américas',
      origin:
          'The greatest national rivalry in football. The two CONMEBOL giants have produced legends from Pelé to Maradona to Messi, contested every Copa América since 1916, and met in countless World Cup qualifiers.',
      moments: [
        '1990 WC R16: Argentina 1-0 Brazil — Maradona\'s assist for Caniggia knocked the favourites out',
        '2005 Confed Cup final: Brazil 4-1 Argentina — Adriano destroyed his rivals',
        '2007 Copa América final: Brazil 3-0 Argentina',
        '2019 Copa América semi: Brazil 2-0 Argentina',
        '2021 Copa América final: Argentina 1-0 Brazil — Messi finally won his first major trophy',
      ],
    ),
    Rivalry(
      name: 'England vs Germany',
      tla1: 'ENG',
      tla2: 'GER',
      region: 'Europe',
      origin:
          'A century of rivalry shaped by two World Wars and dramatic football encounters. Germany has historically dominated since 1970, but English wins are remembered forever.',
      moments: [
        '1966 WC final: England 4-2 West Germany — Geoff Hurst\'s controversial hat-trick won the trophy',
        '1970 WC QF: West Germany 3-2 England (AET) — revenge after extra-time',
        '1990 WC SF: West Germany 1-1 England (4-3 pens) — Gascoigne\'s tears',
        '1996 EURO SF: Germany 1-1 England (6-5 pens) at Wembley',
        '2010 WC R16: Germany 4-1 England — Lampard\'s "ghost goal" famously disallowed',
        '2021 EURO R16: England 2-0 Germany — Sterling and Kane ended decades of pain',
      ],
    ),
    Rivalry(
      name: 'Germany vs Netherlands',
      tla1: 'GER',
      tla2: 'NED',
      region: 'Europe',
      origin:
          'Born from the 1974 World Cup final, this is one of football\'s most bitter rivalries, fueled by historical and footballing grievances.',
      moments: [
        '1974 WC final: West Germany 2-1 Netherlands — ending Total Football\'s dream',
        '1988 EURO SF: Netherlands 2-1 West Germany — Marco van Basten\'s revenge',
        '1990 WC R16: West Germany 2-1 Netherlands — Rijkaard spit on Völler (both sent off)',
        '2014 WC 3rd-place: Netherlands 3-0 Germany — small consolation for the Dutch',
      ],
    ),
    Rivalry(
      name: 'France vs Germany',
      tla1: 'FRA',
      tla2: 'GER',
      region: 'Europe',
      origin:
          'Defined by two brutal World Cup semi-finals in the 1980s and a modern revival around Euros.',
      moments: [
        '1982 WC SF: West Germany 3-3 France (5-4 pens) — the infamous Schumacher foul on Battiston',
        '1986 WC SF: West Germany 2-0 France — another semi-final heartbreak',
        '2014 WC QF: Germany 1-0 France',
        '2016 EURO SF: France 2-0 Germany — Griezmann brace at home',
      ],
    ),
    Rivalry(
      name: 'Spain vs Portugal',
      tla1: 'ESP',
      tla2: 'POR',
      region: 'Europe',
      nickname: 'Iberian Derby',
      origin:
          'Iberian neighbours with deep cultural ties and a fiercely contested football tradition stretching back to 1921.',
      moments: [
        '2004 EURO group stage: Portugal 1-0 Spain — Portugal advanced as hosts',
        '2010 WC R16: Spain 1-0 Portugal — Villa\'s goal sent eventual champs through',
        '2012 EURO SF: Spain 0-0 Portugal (4-2 pens)',
        '2018 WC group: Spain 3-3 Portugal — Ronaldo hat-trick incl. iconic free-kick',
      ],
    ),
    Rivalry(
      name: 'Mexico vs USA',
      tla1: 'MEX',
      tla2: 'USA',
      region: 'CONCACAF',
      nickname: 'CONCACAF Clásico',
      origin:
          'CONCACAF\'s biggest rivalry. Mexico historically dominated, but the US closed the gap in the 2000s, making this one of football\'s most heated derbies.',
      moments: [
        '2002 WC R16: USA 2-0 Mexico — the biggest upset in their head-to-head history',
        '2009 WCQ at Azteca: Mexico 2-1 USA',
        '2011 Gold Cup final: Mexico 4-2 USA — Dos Santos\' lob to seal it',
        '2021 Nations League final: USA 3-2 Mexico (AET)',
        '2021 Gold Cup final: USA 1-0 Mexico (AET)',
      ],
    ),
    Rivalry(
      name: 'Brazil vs Uruguay',
      tla1: 'BRA',
      tla2: 'URU',
      region: 'South America',
      nickname: 'Clásico del Río de la Plata',
      origin:
          'Defined by the 1950 Maracanazo — when tiny Uruguay shocked hosts Brazil in front of 200,000 to win the World Cup.',
      moments: [
        '1950 WC final: Uruguay 2-1 Brazil — the Maracanazo, still scarring Brazilian football',
        '2010 WC QF: Uruguay 2-1 Ghana (not vs BRA but defining for URU\'s WC return)',
        '2011 Copa América QF: Uruguay 1-1 Brazil (5-4 pens)',
      ],
    ),
    Rivalry(
      name: 'England vs Argentina',
      tla1: 'ENG',
      tla2: 'ARG',
      region: 'Global',
      origin:
          'Shaped by the 1982 Falklands War, this rivalry is loaded with political tension. The football moments are some of the most controversial in history.',
      moments: [
        '1986 WC QF: Argentina 2-1 England — Maradona\'s "Hand of God" AND "Goal of the Century"',
        '1998 WC R16: Argentina 2-2 England (4-3 pens) — Owen\'s goal, Beckham\'s red card',
        '2002 WC group: England 1-0 Argentina — Beckham\'s redemption penalty',
      ],
    ),
    Rivalry(
      name: 'Italy vs France',
      tla1: 'ITA',
      tla2: 'FRA',
      region: 'Europe',
      origin:
          'Latin neighbours with two World Cup final showdowns and an Olympic gold game that defined a generation.',
      moments: [
        '2000 EURO final: France 2-1 Italy (AET) — Trezeguet\'s golden goal',
        '2006 WC final: Italy 1-1 France (5-3 pens) — Zidane\'s headbutt sent off in his final match',
        '2008 EURO group: Netherlands 3-0 France', // (left in for context)
      ],
    ),
    Rivalry(
      name: 'Korea Republic vs Japan',
      tla1: 'KOR',
      tla2: 'JPN',
      region: 'Asia',
      origin:
          'The biggest rivalry in Asian football, rooted in deep historical conflict and a fierce regional competition.',
      moments: [
        '2002 WC: both nations co-hosted; Korea reached the semis, Japan the R16',
        '2011 Asian Cup SF: Japan 2-2 Korea Republic (3-0 pens)',
        '2019 EAFF E-1: Korea Republic 1-0 Japan',
      ],
    ),
    Rivalry(
      name: 'Spain vs Italy',
      tla1: 'ESP',
      tla2: 'ITA',
      region: 'Europe',
      origin:
          'A modern European super-rivalry born of multiple knockout meetings at EUROs.',
      moments: [
        '2008 EURO QF: Spain 0-0 Italy (4-2 pens) — start of Spain\'s golden era',
        '2012 EURO final: Spain 4-0 Italy — Spain\'s dominance peaked',
        '2016 EURO R16: Italy 2-0 Spain',
        '2020 EURO SF: Italy 1-1 Spain (4-2 pens)',
      ],
    ),
    Rivalry(
      name: 'Argentina vs Germany',
      tla1: 'ARG',
      tla2: 'GER',
      region: 'Global',
      origin:
          'They\'ve met in 3 World Cup finals — more than any other pairing.',
      moments: [
        '1986 WC final: Argentina 3-2 West Germany — Maradona\'s World Cup',
        '1990 WC final: West Germany 1-0 Argentina — Brehme\'s late penalty',
        '2014 WC final: Germany 1-0 Argentina (AET) — Götze\'s winning volley',
      ],
    ),
    Rivalry(
      name: 'Brazil vs Italy',
      tla1: 'BRA',
      tla2: 'ITA',
      region: 'Global',
      origin:
          'Football aristocracy. Two of the most successful nations in World Cup history meeting in classic matches.',
      moments: [
        '1970 WC final: Brazil 4-1 Italy — widely considered the greatest team performance ever',
        '1982 WC group of death: Italy 3-2 Brazil — Paolo Rossi\'s hat-trick',
        '1994 WC final: Brazil 0-0 Italy (3-2 pens) — Baggio\'s missed penalty',
      ],
    ),
    Rivalry(
      name: 'Croatia vs Serbia',
      tla1: 'CRO',
      tla2: 'SRB',
      region: 'Europe',
      origin:
          'Born from the Yugoslav Wars. Highly political and emotionally charged whenever the two meet.',
      moments: [
        '2014 WCQ: Croatia 2-0 Serbia',
        '2013 WCQ: Serbia 1-1 Croatia',
      ],
    ),
    Rivalry(
      name: 'Egypt vs Algeria',
      tla1: 'EGY',
      tla2: 'ALG',
      region: 'Africa',
      origin:
          'The fiercest North African rivalry, with bitter recent encounters in qualifiers and AFCON.',
      moments: [
        '2009 WCQ playoff: Algeria 1-0 Egypt — Algeria qualified for 2010 WC',
        '2010 AFCON SF: Algeria 0-4 Egypt — Egypt\'s revenge',
      ],
    ),
    Rivalry(
      name: 'Senegal vs Morocco',
      tla1: 'SEN',
      tla2: 'MAR',
      region: 'Africa',
      origin:
          'Modern North vs West African rivalry — two of Africa\'s rising powers vying for continental supremacy.',
      moments: [
        '2022 AFCON QF: Morocco 1-2 Senegal',
        '2023 AFCON R16: Senegal eliminated; Morocco a force globally',
      ],
    ),
    Rivalry(
      name: 'Ghana vs Nigeria',
      tla1: 'GHA',
      tla2: 'NGA',
      region: 'Africa',
      nickname: 'Jollof Derby',
      origin:
          'West African neighbours with a fiercely competitive football and culinary rivalry (yes, the jollof rice debate).',
      moments: [
        '2022 WCQ playoff: Ghana 1-1 Nigeria (Ghana through on away goals)',
        '2008 AFCON QF: Ghana 2-1 Nigeria',
      ],
    ),
    Rivalry(
      name: 'Australia vs New Zealand',
      tla1: 'AUS',
      tla2: 'NZL',
      region: 'Oceania',
      nickname: 'Trans-Tasman Derby',
      origin:
          'Oceania\'s biggest football rivalry, played frequently before Australia joined the AFC in 2006.',
      moments: [
        '2005 WC qualifying playoff (era): Australia dominated OFC qualifying',
        'Multiple OFC Nations Cup finals contested between them',
      ],
    ),
    Rivalry(
      name: 'Belgium vs Netherlands',
      tla1: 'BEL',
      tla2: 'NED',
      region: 'Europe',
      nickname: 'Low Countries Derby',
      origin:
          'Neighbours and rivals — frequent friendly opponents but with serious sting in qualifiers.',
      moments: [
        '1994 WCQ: rare drama',
        'Modern Nations League encounters from 2018+',
      ],
    ),
  ];
}
