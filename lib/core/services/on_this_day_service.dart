// lib/core/services/on_this_day_service.dart
//
// "On This Day" football history — returns notable football events that
// happened on a given calendar date (ignores year). Local data, no API.

class OnThisDayFact {
  final int year;
  final String text;
  final String category; // 'final', 'match', 'birth', 'record', 'misc'
  const OnThisDayFact(
      {required this.year, required this.text, required this.category});
}

class OnThisDayService {
  /// Returns 0..N facts for the given month + day (year-agnostic).
  static List<OnThisDayFact> factsFor(DateTime date) {
    final key =
        '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _facts[key] ?? const [];
  }

  // Curated history bank. Add more dates as needed.
  static const Map<String, List<OnThisDayFact>> _facts = {
    '06-11': [
      OnThisDayFact(
          year: 2010,
          text:
              'The 2010 global football tournament kicked off in South Africa — the first global football tournament hosted on African soil.',
          category: 'misc'),
    ],
    '06-12': [
      OnThisDayFact(
          year: 1934,
          text:
              'Italy won their first global football tournament, beating Czechoslovakia 2-1 in extra time.',
          category: 'final'),
    ],
    '06-13': [
      OnThisDayFact(
          year: 2018,
          text:
              'Hosting was awarded for the 2026 global football tournament to USA, Canada and Mexico — the first three-country hosting.',
          category: 'misc'),
    ],
    '06-14': [
      OnThisDayFact(
          year: 2014,
          text:
              'The 2014 global football tournament began in Brazil with hosts Brazil beating Croatia 3-1.',
          category: 'match'),
    ],
    '06-15': [
      OnThisDayFact(
          year: 1958,
          text:
              '17-year-old Pelé scored his first global football tournament goal vs Wales.',
          category: 'record'),
    ],
    '06-16': [
      OnThisDayFact(
          year: 2018,
          text:
              'Iceland held Argentina to a 1-1 draw at their first global football tournament.',
          category: 'match'),
    ],
    '06-17': [
      OnThisDayFact(
          year: 1970,
          text:
              'Brazil 4-1 Italy in the 1970 global football tournament final — widely considered one of the greatest teams ever.',
          category: 'final'),
    ],
    '06-18': [
      OnThisDayFact(
          year: 2006,
          text:
              'England beat Trinidad & Tobago 2-0 with two late goals from Crouch and Gerrard.',
          category: 'match'),
    ],
    '06-19': [
      OnThisDayFact(
          year: 2014,
          text:
              'Costa Rica shocked Italy 1-0 at the global football tournament, sealing their qualification from the Group of Death.',
          category: 'match'),
    ],
    '06-20': [
      OnThisDayFact(
          year: 1998,
          text:
              'England beat Colombia 2-0 in France 1998, with Beckham scoring his famous free kick.',
          category: 'match'),
    ],
    '06-21': [
      OnThisDayFact(
          year: 1970,
          text:
              'Brazil beat Italy 4-1 in the global football tournament final, becoming the first nation to win three global tournaments.',
          category: 'final'),
      OnThisDayFact(
          year: 1986,
          text:
              'Brazil 0-1 France in Mexico — Platini-led France knocked out the favourites.',
          category: 'match'),
    ],
    '06-22': [
      OnThisDayFact(
          year: 1986,
          text:
              'Maradona scored both the "Hand of God" and "Goal of the Century" against England.',
          category: 'record'),
    ],
    '06-23': [
      OnThisDayFact(
          year: 2014,
          text:
              'Suárez bit Chiellini — the Uruguay striker received a 4-month international ban.',
          category: 'misc'),
    ],
    '06-24': [
      OnThisDayFact(
          year: 1987,
          text: 'Lionel Messi was born in Rosario, Argentina.',
          category: 'birth'),
    ],
    '06-25': [
      OnThisDayFact(
          year: 1978,
          text:
              'Argentina won their first global football tournament, beating Netherlands 3-1 in Buenos Aires.',
          category: 'final'),
    ],
    '06-26': [
      OnThisDayFact(
          year: 2010,
          text:
              'Lampard\'s "ghost goal" against Germany — the ball clearly crossed the line but was disallowed. Sparked VAR development.',
          category: 'match'),
    ],
    '06-27': [
      OnThisDayFact(
          year: 1982,
          text:
              'Brazil 4-1 Scotland — one of the greatest global football tournament performances; Sócrates, Zico, Falcão dazzled.',
          category: 'match'),
    ],
    '06-28': [
      OnThisDayFact(
          year: 2009,
          text:
              'Brazil won the Confederations Cup in South Africa, 3-2 over USA.',
          category: 'misc'),
    ],
    '06-29': [
      OnThisDayFact(
          year: 1958,
          text:
              'Brazil won their first global football tournament, beating Sweden 5-2 with two goals from 17-year-old Pelé.',
          category: 'final'),
    ],
    '06-30': [
      OnThisDayFact(
          year: 1974,
          text:
              'West Germany won the global football tournament 2-1 over the Netherlands, ending Total Football\'s dream.',
          category: 'final'),
    ],
    '07-01': [
      OnThisDayFact(
          year: 1990,
          text:
              'England beat Cameroon 3-2 in extra time in the global football tournament quarter-finals.',
          category: 'match'),
    ],
    '07-02': [
      OnThisDayFact(
          year: 1994,
          text:
              'Colombian defender Andrés Escobar was murdered in Medellín, days after scoring an own goal at the global football tournament.',
          category: 'misc'),
    ],
    '07-03': [
      OnThisDayFact(
          year: 2010,
          text:
              'Germany dismantled Argentina 4-0 in the global football tournament quarter-finals.',
          category: 'match'),
    ],
    '07-04': [
      OnThisDayFact(
          year: 1990,
          text:
              'England lost the global football tournament semi-final to West Germany on penalties — Gascoigne\'s tears became iconic.',
          category: 'match'),
    ],
    '07-05': [
      OnThisDayFact(
          year: 1994,
          text:
              'Diego Maradona was banned from the global football tournament after failing a drug test for ephedrine.',
          category: 'misc'),
    ],
    '07-06': [
      OnThisDayFact(
          year: 2002,
          text:
              'Brazil 2-0 Germany — Ronaldo scored twice to win the global football tournament final, completing his redemption from 1998.',
          category: 'final'),
    ],
    '07-07': [
      OnThisDayFact(
          year: 1990,
          text:
              'Italy 2-1 England — the Three Lions earned third place at Italia \'90.',
          category: 'match'),
    ],
    '07-08': [
      OnThisDayFact(
          year: 2014,
          text:
              'Germany 7-1 Brazil in the semi-final — Brazil\'s worst-ever global football tournament defeat, at home.',
          category: 'match'),
    ],
    '07-09': [
      OnThisDayFact(
          year: 2006,
          text:
              'Italy won the global football tournament on penalties vs France; Zidane was sent off for headbutting Materazzi.',
          category: 'final'),
    ],
    '07-10': [
      OnThisDayFact(
          year: 2016,
          text:
              'Portugal won EURO 2016 — Ronaldo limped off injured, but Éder scored in extra time vs France.',
          category: 'final'),
    ],
    '07-11': [
      OnThisDayFact(
          year: 1982,
          text:
              'Italy won the global football tournament 3-1 over West Germany — Paolo Rossi top-scored after returning from a betting ban.',
          category: 'final'),
      OnThisDayFact(
          year: 2018,
          text:
              'Croatia beat England 2-1 in extra time to reach the global football tournament final.',
          category: 'match'),
    ],
    '07-12': [
      OnThisDayFact(
          year: 2020,
          text:
              'Bayern Munich won the Bundesliga title in an unprecedented locked-down season.',
          category: 'misc'),
    ],
    '07-13': [
      OnThisDayFact(
          year: 1930,
          text:
              'The very first global football tournament match was played: France 4-1 Mexico in Uruguay.',
          category: 'record'),
      OnThisDayFact(
          year: 2014,
          text:
              'Germany 1-0 Argentina in the global football tournament final — Mario Götze\'s extra-time winner sealed it.',
          category: 'final'),
    ],
    '07-14': [
      OnThisDayFact(
          year: 2024,
          text:
              'Spain beat England 2-1 in the EURO 2024 final to win their fourth European title.',
          category: 'final'),
    ],
    '07-15': [
      OnThisDayFact(
          year: 2018,
          text:
              'France won the global football tournament 4-2 over Croatia in Russia — Mbappé became the first teen since Pelé to score in a final.',
          category: 'final'),
    ],
    '07-16': [
      OnThisDayFact(
          year: 1950,
          text:
              'The "Maracanazo": Uruguay shocked Brazil 2-1 to win the global football tournament in front of 200,000 fans.',
          category: 'final'),
    ],
    '07-17': [
      OnThisDayFact(
          year: 1994,
          text:
              'Brazil beat Italy on penalties at USA \'94 — Baggio missed the decisive kick.',
          category: 'final'),
    ],
    '07-18': [
      OnThisDayFact(
          year: 1976,
          text: 'East Germany won the Olympic football gold in Montreal.',
          category: 'misc'),
    ],
    '07-19': [
      OnThisDayFact(
          year: 2026,
          text:
              'The 2026 global football tournament final is scheduled to be played today.',
          category: 'final'),
    ],
    '02-05': [
      OnThisDayFact(
          year: 1985,
          text: 'Cristiano Ronaldo was born in Funchal, Madeira.',
          category: 'birth'),
    ],
    '12-21': [
      OnThisDayFact(
          year: 1989,
          text:
              'A 12-year-old Cristiano Ronaldo signed his first contract with Andorinha.',
          category: 'birth'),
    ],
  };
}
