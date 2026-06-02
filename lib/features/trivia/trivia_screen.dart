import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/ad_service.dart';
import '../../core/theme/app_theme.dart';

// ──────────────────────────────────────────────────────────────────────────
// Built-in 60-question football trivia bank — covers WC, UEFA, EPL, La Liga,
// players, records. Daily quiz picks 10 random questions seeded by date,
// so each day has a consistent set but every day is different.
// ──────────────────────────────────────────────────────────────────────────

class _Q {
  final String q;
  final List<String> options;
  final int correct; // index 0-3
  final String explanation;
  final String category;
  const _Q(this.q, this.options, this.correct, this.explanation, this.category);
}

const List<_Q> _bank = [
  // World Cup history
  _Q('How many World Cups has Brazil won?', ['3', '4', '5', '6'], 2,
      'Brazil has won 5 (1958, 62, 70, 94, 2002).', 'world_cup'),
  _Q(
      'Which country hosted the 1986 World Cup?',
      ['Argentina', 'Mexico', 'Spain', 'USA'],
      1,
      'Mexico hosted in 1986 — also in 1970.',
      'world_cup'),
  _Q(
      'Who won the 2022 World Cup?',
      ['France', 'Argentina', 'Brazil', 'Croatia'],
      1,
      'Argentina beat France on penalties.',
      'world_cup'),
  _Q(
      'Where will the 2030 World Cup be held?',
      ['Spain & Portugal & Morocco', 'USA', 'England', 'Australia'],
      0,
      'Spain, Portugal & Morocco co-host, with games also in South America.',
      'world_cup'),
  _Q(
      'How many teams will play in the 2026 World Cup?',
      ['32', '40', '48', '64'],
      2,
      'The format expanded to 48 teams for 2026.',
      'world_cup'),
  _Q(
      'Who is the all-time top scorer in World Cup history?',
      ['Pelé', 'Miroslav Klose', 'Ronaldo', 'Gerd Müller'],
      1,
      'Klose scored 16 across four World Cups.',
      'world_cup'),
  _Q(
      'Which country has lost the most World Cup finals?',
      ['Germany', 'Argentina', 'Netherlands', 'Italy'],
      2,
      'The Netherlands has lost three finals (1974, 1978, 2010).',
      'world_cup'),
  _Q(
      'What year was the first World Cup held?',
      ['1928', '1930', '1934', '1950'],
      1,
      'Uruguay hosted and won the first World Cup in 1930.',
      'world_cup'),

  // UEFA / Champions League
  _Q(
      'Which club has won the most UEFA Champions League titles?',
      ['Barcelona', 'Bayern Munich', 'Real Madrid', 'AC Milan'],
      2,
      'Real Madrid has the most European Cup / Champions League titles.',
      'uefa'),
  _Q(
      'Which country has won the most European Championships?',
      ['Germany', 'Spain', 'France', 'Italy'],
      1,
      'Spain has won four (1964, 2008, 2012, 2024).',
      'uefa'),
  _Q(
      'In what year was the Champions League renamed from European Cup?',
      ['1990', '1992', '1995', '2000'],
      1,
      'The competition was rebranded in 1992.',
      'uefa'),
  _Q(
      'Which English club first won the European Cup?',
      ['Liverpool', 'Manchester United', 'Nottingham Forest', 'Aston Villa'],
      1,
      "Manchester United won in 1968.",
      'uefa'),

  // Premier League
  _Q(
      'Who is the all-time top scorer in the Premier League?',
      ['Wayne Rooney', 'Alan Shearer', 'Harry Kane', 'Sergio Agüero'],
      1,
      'Alan Shearer with 260 PL goals.',
      'epl'),
  _Q(
      'Which club won the first ever Premier League?',
      ['Manchester United', 'Arsenal', 'Liverpool', 'Blackburn'],
      0,
      'Manchester United won the 1992-93 inaugural PL season.',
      'epl'),
  _Q(
      'Which club went unbeaten in the 2003-04 Premier League?',
      ['Manchester United', 'Chelsea', 'Arsenal', 'Liverpool'],
      2,
      "Arsenal's 'Invincibles' went unbeaten.",
      'epl'),
  _Q(
      'Who scored the fastest hat-trick in Premier League history?',
      ['Sergio Agüero', 'Sadio Mané', 'Robbie Fowler', 'Andy Cole'],
      1,
      'Sadio Mané scored a hat-trick in 2:56 in 2015.',
      'epl'),

  // La Liga
  _Q(
      'Which Spanish club has won the most La Liga titles?',
      ['Barcelona', 'Real Madrid', 'Atlético Madrid', 'Valencia'],
      1,
      'Real Madrid leads the all-time La Liga title count.',
      'la_liga'),
  _Q(
      'Who is the all-time top scorer in La Liga?',
      ['Cristiano Ronaldo', 'Lionel Messi', 'Telmo Zarra', 'Karim Benzema'],
      1,
      'Messi scored 474 La Liga goals.',
      'la_liga'),
  _Q(
      "Which is Spain's oldest football club still in existence?",
      ['Recreativo de Huelva', 'Athletic Bilbao', 'Real Madrid', 'Barcelona'],
      0,
      'Recreativo, founded in 1889.',
      'la_liga'),

  // Bundesliga / Serie A / Ligue 1
  _Q(
      'Which club has won the most Bundesliga titles?',
      ['Borussia Dortmund', 'Bayern Munich', 'Hamburg', 'Schalke'],
      1,
      'Bayern Munich dominates the Bundesliga.',
      'bundesliga'),
  _Q(
      'Which Italian club is nicknamed "The Old Lady"?',
      ['Inter Milan', 'AC Milan', 'Juventus', 'Roma'],
      2,
      "Juventus has been called 'La Vecchia Signora'.",
      'serie_a'),
  _Q(
      'Which French club has won the most Ligue 1 titles in recent years?',
      ['Marseille', 'Monaco', 'PSG', 'Lyon'],
      2,
      'PSG has dominated Ligue 1 since 2013.',
      'ligue_1'),

  // Players
  _Q(
      "Which player has won the most Ballon d'Or awards?",
      ['Cristiano Ronaldo', 'Lionel Messi', 'Johan Cruyff', 'Michel Platini'],
      1,
      "Messi has won 8 Ballon d'Or awards.",
      'players'),
  _Q(
      'Who is known as "The King of Football"?',
      ['Maradona', 'Pelé', 'Zidane', 'Cruyff'],
      1,
      "Pelé is widely called the King.",
      'players'),
  _Q(
      'Which player scored the "Hand of God" goal?',
      ['Maradona', 'Pelé', 'Beckenbauer', 'Müller'],
      0,
      "Maradona vs England in the 1986 World Cup.",
      'players'),
  _Q(
      'Which club did Ronaldinho NOT play for?',
      ['Barcelona', 'PSG', 'Milan', 'Manchester United'],
      3,
      "Ronaldinho never played for Manchester United.",
      'players'),
  _Q(
      'Who won the 2022 Golden Boot at the World Cup?',
      ['Mbappé', 'Messi', 'Giroud', 'Álvarez'],
      0,
      'Kylian Mbappé scored 8 goals.',
      'players'),
  _Q(
      'Who scored the famous "Zidane headbutt" final?',
      ['Materazzi', 'Cannavaro', 'Pirlo', 'Inzaghi'],
      0,
      'Marco Materazzi was headbutted by Zidane in 2006.',
      'players'),

  // Records
  _Q(
      'Highest-scoring World Cup final?',
      ['7-1 (2002)', '5-1 (1970)', '6-3 (1958)', '5-2 (1958)'],
      2,
      'Brazil 5-2 Sweden in 1958, 7 goals total.',
      'records'),
  _Q(
      'Who is the youngest WC goal scorer?',
      ['Pelé', 'Mbappé', 'Owen', 'Rooney'],
      0,
      'Pelé at 17 years 239 days in 1958.',
      'records'),
  _Q(
      'Which is the largest football stadium in the world?',
      ['Camp Nou', 'Maracanã', 'Rungrado', 'Wembley'],
      2,
      "North Korea's Rungrado, 114K capacity.",
      'records'),
  _Q(
      'Most goals in a single PL season by one player?',
      ['32', '34', '36', '38'],
      2,
      'Mohamed Salah scored 32 in 2017-18; Haaland scored 36 in 2022-23.',
      'records'),

  // General rules
  _Q(
      'How long is a normal football match?',
      ['80 minutes', '90 minutes', '100 minutes', '120 minutes'],
      1,
      '90 minutes plus stoppage time.',
      'rules'),
  _Q(
      'How many substitutions are now allowed in a match?',
      ['3', '5', '7', 'Unlimited'],
      1,
      "Five substitutions are now standard post-2020.",
      'rules'),
  _Q(
      'What is the diameter of the centre circle?',
      ['8m', '9.15m', '10m', '11m'],
      1,
      "The centre circle has a 9.15m (10 yards) radius.",
      'rules'),
  _Q('How many players are on the pitch per side?', ['10', '11', '12', '9'], 1,
      'Eleven players per side including the goalkeeper.', 'rules'),
  _Q(
      'How long does a player have to take a corner?',
      ['No specific time', '10 seconds', '30 seconds', '1 minute'],
      0,
      "No specific limit, but the referee can enforce delay rules.",
      'rules'),

  // Stadiums / venues
  _Q(
      'Which is the home stadium of Liverpool FC?',
      ['Old Trafford', 'Anfield', 'Stamford Bridge', 'Etihad'],
      1,
      "Anfield has been Liverpool's home since 1892.",
      'stadiums'),
  _Q(
      'Which iconic stadium is in Madrid?',
      ['Camp Nou', 'Wanda Metropolitano', 'Santiago Bernabéu', 'Mestalla'],
      2,
      "The Bernabéu is Real Madrid's home.",
      'stadiums'),
  _Q(
      'Which 2026 host city is in Canada?',
      ['Vancouver', 'Toronto', 'Both', 'Neither'],
      2,
      'Both Vancouver and Toronto host games.',
      'stadiums'),

  // Tactics & terms
  _Q(
      'What does "tiki-taka" refer to?',
      [
        'A defensive formation',
        'A short-passing style',
        'A counter-attack',
        'A free-kick'
      ],
      1,
      'Short, possession-based passing made famous by Barcelona and Spain.',
      'tactics'),
  _Q(
      'What does VAR stand for?',
      [
        'Video Assistant Referee',
        'Visual Action Review',
        'Verified Action Replay',
        'Variable Action Ref'
      ],
      0,
      'Video Assistant Referee — introduced widely from 2018.',
      'tactics'),
  _Q(
      'A 4-3-3 formation has how many midfielders?',
      ['2', '3', '4', '5'],
      1,
      "Three midfielders between four defenders and three forwards.",
      'tactics'),

  // Random fun
  _Q('What colour is a yellow card?', ['Yellow', 'Red', 'Orange', 'Blue'], 0,
      'It really is yellow.', 'fun'),
  _Q('How many points for a win in league football?', ['1', '2', '3', '4'], 2,
      'Three points for a win since the 1990s.', 'fun'),
  _Q(
      'Which trophy does the Premier League winner lift?',
      ['UEFA Cup', 'Premier League Trophy', 'FA Cup', 'Charity Shield'],
      1,
      'The Premier League Trophy.',
      'fun'),
  _Q(
      'What does "clean sheet" mean?',
      ['No goals conceded', 'No fouls', 'No cards', 'No subs used'],
      0,
      'A goalkeeper kept the opposition from scoring.',
      'fun'),
  _Q('How long is half-time?', ['5 min', '10 min', '15 min', '20 min'], 2,
      '15 minutes per Laws of the Game.', 'fun'),

  // Africa / CONCACAF / Asia
  _Q(
      'Which African country reached the WC semi-finals in 2022?',
      ['Morocco', 'Senegal', 'Cameroon', 'Ghana'],
      0,
      'Morocco became the first African semi-finalist.',
      'global'),
  _Q(
      'Which Asian nation has hosted the WC?',
      ['China', 'South Korea & Japan', 'India', 'Thailand'],
      1,
      'Co-hosted in 2002.',
      'global'),
  _Q(
      'What is the top US club football competition called?',
      ['MLS', 'NASL', 'USL', 'NPSL'],
      0,
      'Major League Soccer (MLS).',
      'global'),
  _Q(
      'Which country won the first AFCON?',
      ['Egypt', 'Ghana', 'Cameroon', 'Nigeria'],
      0,
      'Egypt won the inaugural Africa Cup of Nations in 1957.',
      'global'),

  // Misc
  _Q(
      'What is the maximum extra-time before penalties in knockout matches?',
      ['10 min', '20 min', '30 min', '45 min'],
      2,
      'Two 15-minute halves = 30 minutes of extra time.',
      'rules'),
  _Q(
      'Which colour is the home jersey of Argentina?',
      ['White & sky blue stripes', 'Yellow', 'Red & white', 'All blue'],
      0,
      'Argentina wears white and sky blue vertical stripes.',
      'global'),
];

class TriviaScreen extends ConsumerStatefulWidget {
  const TriviaScreen({super.key});
  @override
  ConsumerState<TriviaScreen> createState() => _TriviaScreenState();
}

class _TriviaScreenState extends ConsumerState<TriviaScreen> {
  List<_Q> _questions = [];
  int _qIndex = 0, _score = 0, _correctCount = 0, _timer = 15;
  Timer? _ticker;
  int? _selected;
  bool _showAnswer = false, _completed = false, _started = false;
  Set<int> _eliminated = {};

  @override
  void initState() {
    super.initState();
    _selectDaily();
  }

  void _selectDaily() {
    // Use the day-of-year as a seed so everyone gets the same 10 questions today.
    final today = DateTime.now();
    final seed = today.year * 1000 + today.month * 31 + today.day;
    final rnd = Random(seed);
    final indices = List.generate(_bank.length, (i) => i)..shuffle(rnd);
    _questions = indices.take(10).map((i) => _bank[i]).toList();
  }

  void _start() {
    setState(() => _started = true);
    _startTimer();
  }

  void _startTimer() {
    _ticker?.cancel();
    setState(() => _timer = 15);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timer--);
      if (_timer <= 0) {
        t.cancel();
        _reveal();
      }
    });
  }

  void _reveal() {
    if (_showAnswer) return;
    setState(() => _showAnswer = true);
    Future.delayed(const Duration(milliseconds: 1800), _next);
  }

  void _select(int i) {
    if (_showAnswer) return;
    _ticker?.cancel();
    final correct = _questions[_qIndex].correct;
    final bonus = _timer > 10 ? 5 : 0;
    if (i == correct) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _selected = i;
      _showAnswer = true;
      if (i == correct) {
        _score += 10 + bonus;
        _correctCount++;
      }
    });
    Future.delayed(const Duration(milliseconds: 1800), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_qIndex + 1 >= _questions.length) {
      _finish();
      return;
    }
    setState(() {
      _qIndex++;
      _selected = null;
      _showAnswer = false;
      _eliminated = {};
    });
    _startTimer();
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    final perfect = _correctCount == _questions.length ? 50 : 0;
    final total = _score + perfect;
    final box = Hive.box('trivia_progress');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));
    final lastDay = box.get('last_day') as String?;
    int streak = box.get('streak', defaultValue: 0) as int;
    if (lastDay == yesterday) {
      streak++;
    } else if (lastDay != today) {
      streak = 1;
    }
    await box.put('streak', streak);
    await box.put('last_day', today);
    await box.put('score_$today', total);
    final highest = box.get('highest_score', defaultValue: 0) as int;
    if (total > highest) await box.put('highest_score', total);
    if (!mounted) return;
    setState(() {
      _score = total;
      _completed = true;
    });
  }

  void _useHint() {
    if (_showAnswer || _eliminated.isNotEmpty) return;
    AdService.showRewarded(() {
      final q = _questions[_qIndex];
      final wrong = <int>[];
      for (var i = 0; i < q.options.length; i++) {
        if (i != q.correct) wrong.add(i);
      }
      wrong.shuffle();
      if (!mounted) return;
      setState(() => _eliminated.addAll(wrong.take(2)));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('trivia_progress');
    final streak = box.get('streak', defaultValue: 0) as int;
    final highest = box.get('highest_score', defaultValue: 0) as int;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _completed
            ? _result(streak)
            : !_started
                ? _intro(streak, highest)
                : _question(),
      ),
    );
  }

  Widget _intro(int streak, int highest) {
    final p = AppTheme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.black, size: 44),
          ),
          const SizedBox(height: 20),
          Text('Daily Football Trivia',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: p.textHi)),
          const SizedBox(height: 6),
          Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
              style: TextStyle(color: p.textMid, fontSize: 14)),
          const SizedBox(height: 4),
          Text('10 questions • 15s per question',
              style: TextStyle(color: p.textLow, fontSize: 12)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: p.heroGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.brand.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(child: _stat('🔥', '$streak', 'Streak', p)),
                Container(width: 1, height: 36, color: p.stroke),
                Expanded(child: _stat('🏆', '$highest', 'Best', p)),
                Container(width: 1, height: 36, color: p.stroke),
                Expanded(child: _stat('❓', '10', 'Qs', p)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('START QUIZ'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18)),
              onPressed: _start,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String e, String v, String l, Palette p) => Column(
        children: [
          Text(e, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(v,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: p.textHi)),
          Text(l, style: TextStyle(fontSize: 10, color: p.textLow)),
        ],
      );

  Widget _question() {
    final p = AppTheme.of(context);
    final q = _questions[_qIndex];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _ticker?.cancel();
                  setState(() {
                    _started = false;
                    _qIndex = 0;
                    _score = 0;
                    _correctCount = 0;
                    _selected = null;
                    _showAnswer = false;
                    _eliminated = {};
                  });
                },
                color: p.textMid,
                padding: EdgeInsets.zero,
              ),
              const Spacer(),
              Text('${_qIndex + 1}/${_questions.length}',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, color: p.textHi)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: AppTheme.brand, size: 14),
                    const SizedBox(width: 4),
                    Text('$_score',
                        style: const TextStyle(
                            color: AppTheme.brand,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_qIndex + 1) / _questions.length,
              minHeight: 6,
              backgroundColor: AppTheme.of(context).surfaceHi,
              valueColor: const AlwaysStoppedAnimation(AppTheme.brand),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            q.category.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: AppTheme.accent),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (_timer / 15).clamp(0.0, 1.0),
                  strokeWidth: 5,
                  backgroundColor: p.stroke,
                  valueColor: AlwaysStoppedAnimation(
                      _timer <= 5 ? AppTheme.bad : AppTheme.brand),
                ),
                Text('$_timer',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _timer <= 5 ? AppTheme.bad : p.textHi)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(q.q,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: p.textHi)),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: q.options.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (_, i) {
              final eliminated = _eliminated.contains(i);
              final isCorrect = _showAnswer && i == q.correct;
              final isWrong = _showAnswer && _selected == i && i != q.correct;
              Color bg = p.surface;
              Color bd = p.stroke;
              if (isCorrect) {
                bg = AppTheme.brand.withValues(alpha: 0.15);
                bd = AppTheme.brand;
              } else if (isWrong) {
                bg = AppTheme.bad.withValues(alpha: 0.15);
                bd = AppTheme.bad;
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: InkWell(
                  onTap: eliminated || _showAnswer ? null : () => _select(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: bd, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? AppTheme.brand
                                : isWrong
                                    ? AppTheme.bad
                                    : p.surfaceHi,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(String.fromCharCode(65 + i),
                              style: TextStyle(
                                  color: isCorrect
                                      ? Colors.black
                                      : isWrong
                                          ? Colors.white
                                          : p.textMid,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(q.options[i],
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: eliminated ? p.textLow : p.textHi,
                                  decoration: eliminated
                                      ? TextDecoration.lineThrough
                                      : null)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_showAnswer)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(q.explanation,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textMid, fontSize: 12, height: 1.4)),
          ),
        if (!_showAnswer)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: OutlinedButton.icon(
              onPressed: _eliminated.isNotEmpty ? null : _useHint,
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
              label: const Text('Watch ad → Eliminate 2 wrong'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.4)),
                foregroundColor: AppTheme.accent,
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _result(int streak) {
    final p = AppTheme.of(context);
    final perfect = _correctCount == _questions.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(perfect ? '🏆' : '🎉', style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 12),
          Text(perfect ? 'PERFECT ROUND!' : 'Great job!',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, color: p.textHi)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: p.heroGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.brand.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text('$_score',
                    style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.brand)),
                const Text('POINTS EARNED',
                    style: TextStyle(
                        color: AppTheme.brand,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: Column(children: [
                      Text('$_correctCount/${_questions.length}',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: p.textHi)),
                      Text('Correct',
                          style: TextStyle(fontSize: 11, color: p.textLow)),
                    ])),
                    Container(width: 1, height: 30, color: p.stroke),
                    Expanded(
                        child: Column(children: [
                      Text('🔥 $streak',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: p.textHi)),
                      Text('Day streak',
                          style: TextStyle(fontSize: 11, color: p.textLow)),
                    ])),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Share my score'),
              onPressed: () => Share.share(
                '🧠 I scored $_score pts on Football Fan Hub Daily Trivia!\n'
                '✅ $_correctCount/${_questions.length} correct · 🔥 $streak day streak\n'
                'Can you beat me?',
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Back to intro'),
              onPressed: () {
                setState(() {
                  _completed = false;
                  _started = false;
                  _qIndex = 0;
                  _score = 0;
                  _correctCount = 0;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
