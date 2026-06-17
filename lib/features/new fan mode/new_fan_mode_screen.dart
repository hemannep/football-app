// lib/features/new_fan_mode/new_fan_mode_screen.dart
//
// Spec feature #17 — "New Fan Mode". Explains football basics for newcomers
// in a friendly, swipeable format. Pure local content, no APIs.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ad_banner_widget.dart';

class _Lesson {
  final String emoji;
  final String title;
  final String body;
  final List<String> bullets;
  const _Lesson({
    required this.emoji,
    required this.title,
    required this.body,
    this.bullets = const [],
  });
}

const List<_Lesson> _lessons = [
  _Lesson(
    emoji: '⚽',
    title: 'What is a match?',
    body:
        'A football match is 90 minutes long, split into two 45-minute halves with a 15-minute break in between. The team that scores the most goals wins.',
    bullets: [
      '11 players per team on the pitch',
      'One of those is the goalkeeper — the only one allowed to use hands',
      'If the score is tied at the end, the game ends in a draw (in group stage) or goes to extra time + penalties (in knockouts)',
    ],
  ),
  _Lesson(
    emoji: '🚫',
    title: 'Offside, explained',
    body:
        'A player is offside if they are nearer to the opponent\'s goal than both the ball AND the second-last defender when their teammate plays the ball forward.',
    bullets: [
      'You can\'t be offside in your own half',
      'You can\'t be offside from a throw-in, goal kick, or corner',
      'It only matters when the ball is passed to you — being in an offside position alone isn\'t a foul',
    ],
  ),
  _Lesson(
    emoji: '🟨',
    title: 'Yellow & red cards',
    body:
        'A yellow card is a caution. Two yellows in one match = automatic red card. A straight red card means the player leaves immediately AND can\'t be replaced.',
    bullets: [
      'A team playing with 10 men is at a big disadvantage',
      'Red cards usually mean 1-3 match bans depending on the offence',
      'Common reasons: bad tackles, intentional handball, abusive language',
    ],
  ),
  _Lesson(
    emoji: '🔁',
    title: 'Substitutions',
    body:
        'Each team can swap players during the match. Modern rules allow 5 substitutions per team, made in 3 separate "windows" plus half-time.',
    bullets: [
      'Once subbed off, a player cannot return',
      'Some matches allow an extra "concussion sub" for injured players',
      'A "super-sub" is a player famous for scoring after coming off the bench',
    ],
  ),
  _Lesson(
    emoji: '🏟️',
    title: 'The 2026 tournament format',
    body:
        'For the first time, 48 teams play. They\'re divided into 12 groups of 4. Each team plays 3 group games. The top 2 from each group qualify automatically.',
    bullets: [
      'PLUS the 8 best 3rd-placed teams across all 12 groups also qualify',
      '32 teams in total advance to the knockout round',
      'Knockouts: Round of 32 → Round of 16 → Quarter-finals → Semi-finals → Final',
    ],
  ),
  _Lesson(
    emoji: '🏆',
    title: 'Knockouts',
    body:
        'From the Round of 32 onwards, every match is winner-takes-all. If the scores are level after 90 minutes, the match goes to 30 minutes of extra time, then a penalty shootout if still tied.',
    bullets: [
      'Extra time = two 15-minute halves',
      'Penalty shootout = 5 kicks each from the spot, then sudden death',
      'The Final is one match in the host city — no replays',
    ],
  ),
  _Lesson(
    emoji: '📊',
    title: 'How standings work',
    body:
        'In the group stage, teams earn 3 points for a win, 1 point for a draw, and 0 for a loss. Whoever has the most points at the end of 3 games wins the group.',
    bullets: [
      'If two teams are tied on points, goal difference (goals scored minus goals conceded) is the tiebreaker',
      'If still tied: goals scored, then head-to-head result',
      'If STILL tied: drawing of lots (very rare!)',
    ],
  ),
  _Lesson(
    emoji: '⏱️',
    title: 'Stoppage time',
    body:
        'After each half, the referee adds extra minutes ("stoppage time" or "added time") to make up for time lost to injuries, substitutions, and VAR checks.',
    bullets: [
      'Usually 1-5 minutes per half, but can be 10+ at major tournaments',
      'Some of football\'s most dramatic goals come in stoppage time',
      'It\'s the referee\'s decision when to blow the final whistle',
    ],
  ),
  _Lesson(
    emoji: '📺',
    title: 'VAR explained',
    body:
        'VAR (Video Assistant Referee) is a team of officials watching replays. They can advise the main referee to overturn decisions for clear errors on goals, penalties, red cards, and mistaken identity.',
    bullets: [
      'Only the on-pitch referee has the final say',
      'VAR only intervenes for "clear and obvious errors"',
      'You\'ll see the referee draw a rectangle (the VAR sign) to signal a review',
    ],
  ),
  _Lesson(
    emoji: '🎉',
    title: 'You\'re ready!',
    body:
        'That\'s the basics covered. The best way to learn is to watch matches — and every Football Fan Hub feature is built to help you follow along, no matter your level.',
    bullets: [
      'Predict scores and earn points',
      'Take the daily trivia for fun XP',
      'Build your own bracket and share it with friends',
    ],
  ),
];

class NewFanModeScreen extends StatefulWidget {
  const NewFanModeScreen({super.key});

  @override
  State<NewFanModeScreen> createState() => _NewFanModeScreenState();
}

class _NewFanModeScreenState extends State<NewFanModeScreen> {
  final _ctrl = PageController();
  int _index = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text('New Fan Mode',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: p.textHi)),
                  ),
                  Text('${_index + 1} / ${_lessons.length}',
                      style: TextStyle(
                          fontSize: 12,
                          color: p.textLow,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_index + 1) / _lessons.length,
                  minHeight: 6,
                  backgroundColor: p.surfaceHi,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.brand),
                ),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _lessons.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _LessonView(lesson: _lessons[i]),
              ),
            ),
            // Bottom nav
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_index > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _ctrl.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: p.stroke),
                          foregroundColor: p.textMid,
                        ),
                        child: const Text('Back',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  if (_index > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        if (_index < _lessons.length - 1) {
                          _ctrl.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut);
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brand,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                          _index < _lessons.length - 1
                              ? 'Continue'
                              : 'Done — let\'s play!',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
            const AdBannerWidget(),
          ],
        ),
      ),
    );
  }
}

class _LessonView extends StatelessWidget {
  final _Lesson lesson;
  const _LessonView({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(28),
            ),
            alignment: Alignment.center,
            child: Text(lesson.emoji, style: const TextStyle(fontSize: 56)),
          ),
          const SizedBox(height: 22),
          Text(lesson.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: p.textHi,
                  letterSpacing: -0.5)),
          const SizedBox(height: 16),
          Text(lesson.body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: p.textMid, height: 1.5)),
          if (lesson.bullets.isNotEmpty) ...[
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(AppTheme.r),
                border: Border.all(color: p.stroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lesson.bullets
                    .map((b) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 16, color: AppTheme.brand),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(b,
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        color: p.textMid,
                                        height: 1.4)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
