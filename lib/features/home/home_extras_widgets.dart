// lib/features/home/home_extras_widgets.dart
//
// Drop-in home screen widgets built on local services (no Firebase).
//
//   • DailyFactCard      — fun football fact (spec #8)
//   • OnThisDayCard      — historical events on today's date (spec #9)
//   • XpProgressBar      — XP + level + daily login (spec #11)
//   • WelcomeBackRecap   — "What Happened While You Were Away?" (spec #7)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers/live_score_provider.dart';
import '../../core/services/daily_facts_service.dart';
import '../../core/services/fan_xp_service.dart';
import '../../core/services/on_this_day_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/match.dart';

class DailyFactCard extends StatelessWidget {
  const DailyFactCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final fact = DailyFactsService.factForToday();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.warn.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Center(child: Text('💡', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('DID YOU KNOW?',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brand)),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Share.share(
                          '⚽ Did you know? $fact\n\n— from Football Fan Hub 2026'),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.share_rounded, size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(fact,
                    style: TextStyle(
                        fontSize: 13, color: p.textMid, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnThisDayCard extends StatelessWidget {
  const OnThisDayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final facts = OnThisDayService.factsFor(DateTime.now());
    if (facts.isEmpty) return const SizedBox.shrink();
    final today = DateFormat('d MMMM').format(DateTime.now());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: p.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: AppTheme.brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📅', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('ON THIS DAY • $today',
                  style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brand)),
            ],
          ),
          const SizedBox(height: 10),
          ...facts.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.brand,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${f.year}',
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(f.text,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: p.textMid,
                              height: 1.4,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class XpProgressBar extends StatefulWidget {
  const XpProgressBar({super.key});

  @override
  State<XpProgressBar> createState() => _XpProgressBarState();
}

class _XpProgressBarState extends State<XpProgressBar> {
  bool _checked = false;
  bool _awarded = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final awarded = await FanXpService.awardDailyLoginIfNeeded();
    if (mounted) {
      setState(() {
        _checked = true;
        _awarded = awarded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    if (!_checked) return const SizedBox.shrink();
    final xp = FanXpService.xp;
    final level = FanXpService.level;
    final progress = FanXpService.progressToNextLevel;
    final toNext = FanXpService.xpToNextLevel;
    final streak = FanXpService.streak;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text('$level',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LEVEL $level',
                        style: const TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brand)),
                    Text('$xp XP • $toNext to next',
                        style: TextStyle(
                            fontSize: 13,
                            color: p.textHi,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('🔥 $streak',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: p.textHi)),
                  Text('streak',
                      style: TextStyle(fontSize: 10, color: p.textLow)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: p.surfaceHi,
              valueColor: const AlwaysStoppedAnimation(AppTheme.brand),
            ),
          ),
          if (_awarded) ...[
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✨', style: TextStyle(fontSize: 12)),
                SizedBox(width: 4),
                Text('+10 XP daily login bonus',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.brand,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class WelcomeBackRecap extends ConsumerStatefulWidget {
  const WelcomeBackRecap({super.key});

  @override
  ConsumerState<WelcomeBackRecap> createState() => _WelcomeBackRecapState();
}

class _WelcomeBackRecapState extends ConsumerState<WelcomeBackRecap> {
  DateTime? _lastVisit;
  bool _dismissed = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final box = Hive.box('fan_xp');
    final raw = box.get('last_visit') as String?;
    DateTime? prev;
    if (raw != null) prev = DateTime.tryParse(raw);
    await box.put('last_visit', DateTime.now().toIso8601String());
    if (!mounted) return;
    setState(() {
      _lastVisit = prev;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _dismissed) return const SizedBox.shrink();
    if (_lastVisit == null) return const SizedBox.shrink();
    final hoursAgo = DateTime.now().difference(_lastVisit!).inHours;
    if (hoursAgo < 6) return const SizedBox.shrink();

    final p = AppTheme.of(context);
    final allMatches = ref.watch(liveScoreProvider).matches;
    final since = _lastVisit!;
    final finished = allMatches
        .where((m) => m.isFinished && m.utcDate.isAfter(since))
        .toList()
      ..sort((a, b) => b.utcDate.compareTo(a.utcDate));
    final liveNow = allMatches.where((m) => m.isLive).toList();
    if (finished.isEmpty && liveNow.isEmpty) return const SizedBox.shrink();

    final timeLabel = hoursAgo < 24
        ? '${hoursAgo}h ago'
        : '${hoursAgo ~/ 24} day${hoursAgo ~/ 24 == 1 ? '' : 's'} ago';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: AppTheme.brand.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('👋', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Welcome back — last seen $timeLabel',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: p.textHi)),
              ),
              InkWell(
                onTap: () => setState(() => _dismissed = true),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 18, color: p.textLow),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (liveNow.isNotEmpty) ...[
            _liveRow(liveNow),
            const SizedBox(height: 6),
          ],
          if (finished.isNotEmpty) ...[
            Text(
                '${finished.length} match${finished.length == 1 ? '' : 'es'} finished while you were away:',
                style: TextStyle(
                    fontSize: 11,
                    color: p.textLow,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            ...finished.take(4).map((m) {
                final hg = m.score.homeGoals ?? 0;
                final ag = m.score.awayGoals ?? 0;
                final winner = m.score.winner;
                Color homeCol = p.textMid;
                Color awayCol = p.textMid;
                if (winner == 'HOME_TEAM') {
                  homeCol = AppTheme.good;
                  awayCol = p.textLow;
                } else if (winner == 'AWAY_TEAM') {
                  homeCol = p.textLow;
                  awayCol = AppTheme.good;
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.homeTeam.tla,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: homeCol),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: p.surfaceHi,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$hg – $ag',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: p.textHi),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.awayTeam.tla,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: awayCol),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            if (finished.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('+ ${finished.length - 4} more',
                    style: TextStyle(fontSize: 11, color: p.textLow)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _liveRow(List<Match> live) {
    final p = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.live.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: AppTheme.live, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                '${live.length} LIVE now',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.live,
                    fontWeight: FontWeight.w900),
              ),
            ],
          ),
          ...live.take(3).map((m) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Expanded(
                  child: Text(m.homeTeam.tla,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.textMid)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.live.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(m.score.display,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.live)),
                ),
                Expanded(
                  child: Text(m.awayTeam.tla,
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.textMid)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
