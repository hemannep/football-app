// lib/core/services/country_pages_service.dart
//
// Spec feature #15 — Country Fan Pages.
//
// Static catalogue of WC26-relevant facts for each nation: star players,
// qualification journey, achievements. Surfaced via the team detail screen
// as additional sections beneath the standard squad/info.
//
// Designed as a one-off static map (no API). The team detail screen looks
// up by TLA; if a TLA isn\'t in the map (e.g. club teams in Premier League
// mode), the new sections simply don\'t render.

class CountryProfile {
  final String tla;
  final String name;
  final String confederation;
  final List<String>
      achievements; // e.g. "5x World Cup winners (1958, 62, 70, 94, 02)"
  final List<String> starPlayers; // current star names
  final String qualificationJourney; // 1-2 sentences
  final String? legendaryPlayer; // historic icon
  final String? coach; // current coach
  final int? bestWcFinish; // 1=winner, 2=runner-up, etc.
  final String? bestWcYear;
  final bool isDebutant; // first-ever WC appearance in 2026
  final String? funFact;
  const CountryProfile({
    required this.tla,
    required this.name,
    required this.confederation,
    required this.achievements,
    required this.starPlayers,
    required this.qualificationJourney,
    this.legendaryPlayer,
    this.coach,
    this.bestWcFinish,
    this.bestWcYear,
    this.isDebutant = false,
    this.funFact,
  });
}

class CountryPagesService {
  static CountryProfile? find(String tla) => _profiles[tla.toUpperCase()];

  static List<CountryProfile> all() => _profiles.values.toList(growable: false);

  static List<CountryProfile> debutants() =>
      _profiles.values.where((p) => p.isDebutant).toList(growable: false);

  static const Map<String, CountryProfile> _profiles = {
    'BRA': CountryProfile(
      tla: 'BRA',
      name: 'Brazil',
      confederation: 'CONMEBOL',
      achievements: [
        '5x World Cup winners (1958, 1962, 1970, 1994, 2002)',
        '9x Copa América winners',
        '4x Confederations Cup winners',
        'Only nation to play every World Cup since 1930',
      ],
      starPlayers: ['Vinícius Jr', 'Rodrygo', 'Raphinha', 'Alisson'],
      legendaryPlayer: 'Pelé',
      qualificationJourney:
          'Qualified through CONMEBOL after a turbulent campaign, finishing in the automatic places.',
      bestWcFinish: 1,
      bestWcYear: '2002',
      funFact:
          'Brazil are the only nation never to have missed a World Cup since the tournament began in 1930.',
    ),
    'ARG': CountryProfile(
      tla: 'ARG',
      name: 'Argentina',
      confederation: 'CONMEBOL',
      achievements: [
        '3x World Cup winners (1978, 1986, 2022)',
        '16x Copa América winners (joint-most with Uruguay)',
        '2x Olympic gold (2004, 2008)',
      ],
      starPlayers: [
        'Lionel Messi',
        'Julián Álvarez',
        'Lautaro Martínez',
        'Emiliano Martínez'
      ],
      legendaryPlayer: 'Diego Maradona',
      qualificationJourney:
          'Defending champions; qualified emphatically as one of CONMEBOL\'s top sides.',
      bestWcFinish: 1,
      bestWcYear: '2022',
      funFact:
          'Argentina\'s 2022 win ended a 36-year wait — Lionel Messi finally won the trophy.',
    ),
    'FRA': CountryProfile(
      tla: 'FRA',
      name: 'France',
      confederation: 'UEFA',
      achievements: [
        '2x World Cup winners (1998, 2018)',
        '2x EURO winners (1984, 2000)',
        '2x Confederations Cup winners',
      ],
      starPlayers: [
        'Kylian Mbappé',
        'Antoine Griezmann',
        'Aurélien Tchouaméni',
        'Eduardo Camavinga'
      ],
      legendaryPlayer: 'Zinedine Zidane',
      qualificationJourney:
          'Dominant UEFA qualifying campaign; one of the tournament favourites.',
      bestWcFinish: 1,
      bestWcYear: '2018',
      funFact:
          'Mbappé is the first man since Pelé to score a hat-trick in a World Cup final (2022).',
    ),
    'GER': CountryProfile(
      tla: 'GER',
      name: 'Germany',
      confederation: 'UEFA',
      achievements: [
        '4x World Cup winners (1954, 1974, 1990, 2014)',
        '3x EURO winners (1972, 1980, 1996)',
        '1x Confederations Cup (2017)',
      ],
      starPlayers: [
        'Jamal Musiala',
        'Florian Wirtz',
        'Joshua Kimmich',
        'Kai Havertz'
      ],
      legendaryPlayer: 'Franz Beckenbauer',
      qualificationJourney:
          'Cruised through UEFA qualifying with their new generation.',
      bestWcFinish: 1,
      bestWcYear: '2014',
      funFact:
          'Germany has reached more World Cup semi-finals (13) than any other nation.',
    ),
    'ENG': CountryProfile(
      tla: 'ENG',
      name: 'England',
      confederation: 'UEFA',
      achievements: [
        '1x World Cup winners (1966)',
        '1x UEFA Nations League runners-up',
        '2x EURO finalists (2020, 2024)',
      ],
      starPlayers: [
        'Harry Kane',
        'Jude Bellingham',
        'Bukayo Saka',
        'Phil Foden'
      ],
      legendaryPlayer: 'Bobby Moore',
      qualificationJourney:
          'Topped their UEFA qualifying group with games to spare.',
      bestWcFinish: 1,
      bestWcYear: '1966',
      funFact:
          'England\'s only World Cup title came at home in 1966 — Geoff Hurst is still the only player to score a hat-trick in a final.',
    ),
    'ESP': CountryProfile(
      tla: 'ESP',
      name: 'Spain',
      confederation: 'UEFA',
      achievements: [
        '1x World Cup winners (2010)',
        '4x EURO winners (1964, 2008, 2012, 2024)',
        'First nation to win 3 consecutive major tournaments (2008-2012)',
      ],
      starPlayers: ['Lamine Yamal', 'Rodri', 'Pedri', 'Nico Williams'],
      legendaryPlayer: 'Andrés Iniesta',
      qualificationJourney:
          'Reigning EURO champions arrived as one of the most balanced sides in the tournament.',
      bestWcFinish: 1,
      bestWcYear: '2010',
      funFact:
          'Spain are unbeaten in their last 25+ matches at the time of writing.',
    ),
    'POR': CountryProfile(
      tla: 'POR',
      name: 'Portugal',
      confederation: 'UEFA',
      achievements: [
        '1x EURO winners (2016)',
        '1x UEFA Nations League winners (2019, 2025)',
        'World Cup best: 3rd (1966)',
      ],
      starPlayers: [
        'Cristiano Ronaldo',
        'Bruno Fernandes',
        'Bernardo Silva',
        'Vitinha'
      ],
      legendaryPlayer: 'Eusébio',
      qualificationJourney:
          'Dominant UEFA qualifying with strong attacking depth.',
      bestWcFinish: 3,
      bestWcYear: '1966',
      funFact:
          'Cristiano Ronaldo is the first male player to score in five different World Cups.',
    ),
    'NED': CountryProfile(
      tla: 'NED',
      name: 'Netherlands',
      confederation: 'UEFA',
      achievements: [
        'World Cup runners-up 3x (1974, 1978, 2010)',
        '1x EURO winners (1988)',
      ],
      starPlayers: [
        'Cody Gakpo',
        'Virgil van Dijk',
        'Frenkie de Jong',
        'Memphis Depay'
      ],
      legendaryPlayer: 'Johan Cruyff',
      qualificationJourney:
          'Strong UEFA qualifying campaign powered by their veteran defence and young attack.',
      bestWcFinish: 2,
      bestWcYear: '2010',
      funFact:
          'The Netherlands have lost more World Cup finals (3) than any nation that has never won one.',
    ),
    'MEX': CountryProfile(
      tla: 'MEX',
      name: 'Mexico',
      confederation: 'CONCACAF',
      achievements: [
        'CONCACAF\'s most successful nation',
        '12x CONCACAF Gold Cup winners',
        '1x Confederations Cup (1999)',
        'Co-host nation 2026',
      ],
      starPlayers: [
        'Edson Álvarez',
        'Hirving Lozano',
        'Santiago Giménez',
        'Raúl Jiménez'
      ],
      legendaryPlayer: 'Hugo Sánchez',
      qualificationJourney:
          'Automatic qualifier as co-host. First nation to host three World Cups (1970, 1986, 2026).',
      bestWcFinish: 6,
      bestWcYear: '1970 & 1986',
      funFact:
          'Mexico has reached the World Cup R16 in 7 consecutive tournaments (1994-2018) — a record streak.',
    ),
    'USA': CountryProfile(
      tla: 'USA',
      name: 'United States',
      confederation: 'CONCACAF',
      achievements: [
        '7x CONCACAF Gold Cup winners',
        'WC best: 3rd place (1930)',
        'Co-host 2026',
      ],
      starPlayers: [
        'Christian Pulisic',
        'Weston McKennie',
        'Tyler Adams',
        'Gio Reyna'
      ],
      legendaryPlayer: 'Landon Donovan',
      qualificationJourney:
          'Automatic qualifier as co-host. A new golden generation hopes to make a deep run.',
      bestWcFinish: 3,
      bestWcYear: '1930',
      funFact:
          'USA hosts the most 2026 matches — including the final at MetLife Stadium, New Jersey.',
    ),
    'CAN': CountryProfile(
      tla: 'CAN',
      name: 'Canada',
      confederation: 'CONCACAF',
      achievements: [
        '1x CONCACAF Gold Cup winners (2000)',
        'Co-host 2026',
      ],
      starPlayers: [
        'Alphonso Davies',
        'Jonathan David',
        'Stephen Eustáquio',
        'Tajon Buchanan'
      ],
      legendaryPlayer: 'Atiba Hutchinson',
      qualificationJourney:
          'Automatic qualifier as co-host. Returned to the World Cup in 2022 after a 36-year absence.',
      bestWcFinish: null,
      bestWcYear: null,
      funFact:
          'Canada\'s only previous World Cup was 1986 — they didn\'t score a single goal.',
    ),
    'CRO': CountryProfile(
      tla: 'CRO',
      name: 'Croatia',
      confederation: 'UEFA',
      achievements: [
        'World Cup runners-up (2018)',
        'World Cup 3rd place (1998, 2022)',
      ],
      starPlayers: [
        'Luka Modrić',
        'Joško Gvardiol',
        'Mateo Kovačić',
        'Andrej Kramarić'
      ],
      legendaryPlayer: 'Davor Šuker',
      qualificationJourney:
          'Qualified comfortably through UEFA on the back of consistent tournament football.',
      bestWcFinish: 2,
      bestWcYear: '2018',
      funFact:
          'Croatia (pop ~4M) is the smallest nation to reach a modern World Cup final.',
    ),
    'URU': CountryProfile(
      tla: 'URU',
      name: 'Uruguay',
      confederation: 'CONMEBOL',
      achievements: [
        '2x World Cup winners (1930, 1950)',
        '16x Copa América winners (joint-most)',
        '2x Olympic gold (1924, 1928)',
      ],
      starPlayers: [
        'Federico Valverde',
        'Darwin Núñez',
        'Ronald Araújo',
        'Maxi Araújo'
      ],
      legendaryPlayer: 'Luis Suárez (modern), Obdulio Varela (historic)',
      qualificationJourney:
          'Hosted the very first World Cup in 1930. Qualified through CONMEBOL.',
      bestWcFinish: 1,
      bestWcYear: '1950',
      funFact:
          'Uruguay are the smallest nation by population to win the World Cup.',
    ),
    'BEL': CountryProfile(
      tla: 'BEL',
      name: 'Belgium',
      confederation: 'UEFA',
      achievements: [
        'World Cup 3rd place (1986, 2018)',
        '14x at the World Cup',
      ],
      starPlayers: [
        'Kevin De Bruyne',
        'Romelu Lukaku',
        'Jérémy Doku',
        'Youri Tielemans'
      ],
      legendaryPlayer: 'Eden Hazard',
      qualificationJourney:
          'Talented but transitioning generation arrived through UEFA.',
      bestWcFinish: 3,
      bestWcYear: '2018',
      funFact:
          'Belgium\'s "golden generation" never won a major trophy despite being the world #1 for years.',
    ),
    'ITA': CountryProfile(
      tla: 'ITA',
      name: 'Italy',
      confederation: 'UEFA',
      achievements: [
        '4x World Cup winners (1934, 1938, 1982, 2006)',
        '2x EURO winners (1968, 2020)',
      ],
      starPlayers: [
        'Federico Chiesa',
        'Nicolò Barella',
        'Gianluigi Donnarumma',
        'Mateo Retegui'
      ],
      legendaryPlayer: 'Paolo Maldini',
      qualificationJourney:
          'Italy must navigate UEFA qualifying carefully after missing 2018 and 2022.',
      bestWcFinish: 1,
      bestWcYear: '2006',
      funFact: 'Italy\'s 4 World Cup titles are second only to Brazil.',
    ),
    'JPN': CountryProfile(
      tla: 'JPN',
      name: 'Japan',
      confederation: 'AFC',
      achievements: [
        '4x AFC Asian Cup winners',
        'Most successful Asian footballing nation of the modern era',
      ],
      starPlayers: [
        'Takefusa Kubo',
        'Wataru Endo',
        'Kaoru Mitoma',
        'Daichi Kamada'
      ],
      legendaryPlayer: 'Hidetoshi Nakata',
      qualificationJourney:
          'First nation outside the host countries to qualify for 2026.',
      bestWcFinish: 9,
      bestWcYear: '2002, 2010, 2018, 2022',
      funFact:
          'Japan stunned Spain and Germany at the 2022 World Cup, topping their group.',
    ),
    'KOR': CountryProfile(
      tla: 'KOR',
      name: 'Korea Republic',
      confederation: 'AFC',
      achievements: [
        '2x AFC Asian Cup winners',
        'World Cup 4th place (2002)',
      ],
      starPlayers: [
        'Son Heung-min',
        'Kim Min-jae',
        'Lee Kang-in',
        'Hwang Hee-chan'
      ],
      legendaryPlayer: 'Park Ji-sung',
      qualificationJourney: 'Strong AFC qualifying performance.',
      bestWcFinish: 4,
      bestWcYear: '2002',
      funFact:
          'Korea Republic\'s 2002 semi-final run — co-hosting with Japan — remains the best by any Asian nation.',
    ),
    'AUS': CountryProfile(
      tla: 'AUS',
      name: 'Australia',
      confederation: 'AFC',
      achievements: [
        '1x AFC Asian Cup winners (2015)',
        '4x OFC Nations Cup winners',
      ],
      starPlayers: ['Mat Ryan', 'Jackson Irvine', 'Mitch Duke', 'Riley McGree'],
      legendaryPlayer: 'Tim Cahill',
      qualificationJourney: 'Solid AFC qualifying campaign by the Socceroos.',
      bestWcFinish: 16,
      bestWcYear: '2006, 2022',
      funFact:
          'Australia switched from the OFC to the AFC in 2006 to face stronger qualifying competition.',
    ),
    'SEN': CountryProfile(
      tla: 'SEN',
      name: 'Senegal',
      confederation: 'CAF',
      achievements: [
        '1x AFCON winners (2021)',
        'World Cup QF (2002)',
      ],
      starPlayers: [
        'Sadio Mané',
        'Édouard Mendy',
        'Kalidou Koulibaly',
        'Ismaïla Sarr'
      ],
      legendaryPlayer: 'El Hadji Diouf',
      qualificationJourney:
          'Top African qualifier; aiming for another quarter-final run.',
      bestWcFinish: 8,
      bestWcYear: '2002',
      funFact:
          'Senegal stunned defending champs France at their first WC in 2002.',
    ),
    'MAR': CountryProfile(
      tla: 'MAR',
      name: 'Morocco',
      confederation: 'CAF',
      achievements: [
        'World Cup 4th place (2022) — first African semi-finalist',
        'AFCON winners (1976)',
      ],
      starPlayers: [
        'Achraf Hakimi',
        'Hakim Ziyech',
        'Yassine Bounou',
        'Brahim Díaz'
      ],
      legendaryPlayer: 'Ahmed Faras',
      qualificationJourney:
          'Africa\'s standout side of the 2020s arrived in form.',
      bestWcFinish: 4,
      bestWcYear: '2022',
      funFact:
          'Morocco became the first African and first Arab nation to reach a World Cup semi-final in 2022.',
    ),
    'QAT': CountryProfile(
      tla: 'QAT',
      name: 'Qatar',
      confederation: 'AFC',
      achievements: [
        '2x AFC Asian Cup winners (2019, 2023)',
        'Hosted the 2022 World Cup',
      ],
      starPlayers: [
        'Akram Afif',
        'Almoez Ali',
        'Boualem Khoukhi',
        'Hassan Al-Haydos'
      ],
      qualificationJourney:
          'Qualified through AFC pathway as 2023 Asian champions.',
      bestWcFinish: null,
      bestWcYear: null,
      funFact:
          'Qatar are the only host nation to lose every group game at their own World Cup (2022).',
    ),
    'JOR': CountryProfile(
      tla: 'JOR',
      name: 'Jordan',
      confederation: 'AFC',
      achievements: [
        'AFC Asian Cup runners-up (2023)',
      ],
      starPlayers: [
        'Mousa Al-Tamari',
        'Yazan Al-Naimat',
        'Nizar Al-Rashdan',
        'Ehsan Haddad'
      ],
      qualificationJourney:
          'First-ever World Cup qualification — surged through AFC qualifying after their breakout 2023 Asian Cup run.',
      isDebutant: true,
      funFact: '2026 is Jordan\'s first-ever appearance at a senior World Cup.',
    ),
    'UZB': CountryProfile(
      tla: 'UZB',
      name: 'Uzbekistan',
      confederation: 'AFC',
      achievements: [
        '4x AFC Asian Cup quarter-finalists',
      ],
      starPlayers: [
        'Eldor Shomurodov',
        'Khusniddin Alikulov',
        'Abbosbek Fayzullaev',
        'Jaloliddin Masharipov'
      ],
      qualificationJourney:
          'First-ever World Cup qualification after a strong AFC campaign.',
      isDebutant: true,
      funFact:
          'Uzbekistan became an independent international football member in 1994 — 2026 is their first World Cup.',
    ),
    'CPV': CountryProfile(
      tla: 'CPV',
      name: 'Cape Verde',
      confederation: 'CAF',
      achievements: [
        'AFCON QF (2013, 2023)',
      ],
      starPlayers: ['Ryan Mendes', 'Garry Rodrigues', 'Stopira', 'Vozinha'],
      qualificationJourney:
          'Historic first-ever World Cup qualification from CAF.',
      isDebutant: true,
      funFact:
          'Cape Verde (pop ~500,000) is among the smallest nations ever to qualify for a World Cup.',
    ),
    'CUW': CountryProfile(
      tla: 'CUW',
      name: 'Curaçao',
      confederation: 'CONCACAF',
      achievements: [
        '1x CONCACAF Caribbean Cup (2017)',
      ],
      starPlayers: [
        'Leandro Bacuna',
        'Juninho Bacuna',
        'Cuco Martina',
        'Eloy Room'
      ],
      qualificationJourney:
          'Historic first World Cup appearance from CONCACAF qualifying.',
      isDebutant: true,
      funFact:
          'Curaçao (pop ~150,000) is the smallest country EVER to qualify for a World Cup.',
    ),
  };
}
