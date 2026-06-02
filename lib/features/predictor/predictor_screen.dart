// lib/features/predictor/predictor_screen.dart
//
// Firestore-backed predictor with:
//   • First-time name prompt (bottom sheet) so leaderboard shows real names
//   • Edit name button on leaderboard header
//   • "You" row highlighted in leaderboard
//   • Community prediction bar per match
//   • AdMob interstitial after each submission

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/live_score_provider.dart';
import '../../core/providers/prediction_provider.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/prediction_service.dart';
import '../../core/services/user_profile_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/match.dart';
import '../../shared/widgets/display_name_sheet.dart';
import '../../shared/widgets/team_crest_widget.dart';
import '../league picker/league_picker.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class PredictorScreen extends ConsumerStatefulWidget {
  const PredictorScreen({super.key});
  @override
  ConsumerState<PredictorScreen> createState() => _PredictorScreenState();
}

class _PredictorScreenState extends ConsumerState<PredictorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    AdService.loadInterstitial();

    // Show name prompt after first frame if user has never set a name
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!UserProfileService.instance.hasSetName && mounted) {
        showDisplayNameSheet(context, ref, isFirstTime: true);
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final stats = ref.watch(myStatsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Predictor',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: p.textHi)),
                  ),
                  const LeaguePickerChip(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Exact score = 5 pts  •  Correct result = 3 pts',
                style: TextStyle(color: p.textMid, fontSize: 12),
              ),
            ),

            // ── Stats card ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _StatsCard(
                points: stats.points,
                submitted: stats.submitted,
                settled: stats.settled,
                exactScores: stats.exactScores,
                correctResults: stats.correctResults,
              ),
            ),
            const SizedBox(height: 12),

            // ── Tabs ─────────────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: p.surfaceHi,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tab,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: p.isDark ? Colors.black : Colors.white,
                unselectedLabelColor: p.textMid,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '⚽  Predict'),
                  Tab(text: '🏆  Leaderboard'),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // ── Tab views ────────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _PredictTab(onSubmitted: () {
                    // Every prediction = one "action". The ad service will
                    // only actually show an interstitial when the cooldown
                    // has elapsed AND enough actions have accumulated, so
                    // the user typically sees an ad after every ~3 picks,
                    // never two back-to-back, never during their first 10 s.
                    AdService.recordAction();
                    AdService.showInterstitialIfReady();
                  }),
                  const _LeaderboardTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Predict tab ─────────────────────────────────────────────────────────────

class _PredictTab extends ConsumerWidget {
  final VoidCallback onSubmitted;
  const _PredictTab({required this.onSubmitted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final s = ref.watch(liveScoreProvider);
    final myPreds = ref.watch(myPredictionsProvider).value ?? [];

    final upcoming = s.matches
        .where((m) => m.isScheduled && m.utcDate.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.utcDate.compareTo(b.utcDate));

    if (upcoming.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.online_prediction_rounded, size: 56, color: p.textLow),
              const SizedBox(height: 14),
              Text('No upcoming matches',
                  style:
                      TextStyle(color: p.textMid, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Switch competition to predict other matches.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textLow, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: upcoming.length,
      itemBuilder: (_, i) {
        final m = upcoming[i];
        final myPred =
            myPreds.where((p) => p.matchKey == m.matchKey).firstOrNull;
        return _PredictionTile(
          match: m,
          myPrediction: myPred,
          onSubmit: (h, a) async {
            await PredictionService.instance.submitPrediction(
              match: m,
              homeGoals: h,
              awayGoals: a,
            );
            onSubmitted();
          },
        );
      },
    );
  }
}

// ─── Prediction tile ─────────────────────────────────────────────────────────

class _PredictionTile extends ConsumerStatefulWidget {
  final Match match;
  final UserPrediction? myPrediction;
  final Future<void> Function(int home, int away) onSubmit;

  const _PredictionTile({
    required this.match,
    required this.myPrediction,
    required this.onSubmit,
  });

  @override
  ConsumerState<_PredictionTile> createState() => _PredictionTileState();
}

class _PredictionTileState extends ConsumerState<_PredictionTile> {
  late int _home;
  late int _away;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _home = widget.myPrediction?.homeGoals ?? 1;
    _away = widget.myPrediction?.awayGoals ?? 1;
  }

  @override
  void didUpdateWidget(_PredictionTile old) {
    super.didUpdateWidget(old);
    if (old.myPrediction == null && widget.myPrediction != null) {
      _home = widget.myPrediction!.homeGoals;
      _away = widget.myPrediction!.awayGoals;
    }
  }

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();
    // If user hasn't set a name yet, prompt them first
    if (!UserProfileService.instance.hasSetName && mounted) {
      await showDisplayNameSheet(context, ref, isFirstTime: true);
    }

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_home, _away);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '✅ Saved — ${widget.match.homeTeam.tla} $_home–$_away ${widget.match.awayTeam.tla}'),
          backgroundColor: AppTheme.good,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save — check your connection.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final locked = widget.myPrediction != null;
    final passed = widget.match.utcDate.isBefore(DateTime.now());
    final communityAsync =
        ref.watch(communityStatsProvider(widget.match.matchKey));
    final community = communityAsync.value ?? CommunityStats.empty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(
          color: locked ? AppTheme.brand.withValues(alpha: 0.35) : p.stroke,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Match header
            Row(
              children: [
                if (widget.match.competitionName != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(widget.match.competitionName!,
                        style: const TextStyle(
                            color: AppTheme.brand,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                const Spacer(),
                Text(
                  DateFormat('EEE d MMM • HH:mm').format(widget.match.utcDate),
                  style: TextStyle(
                      color: p.textLow,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Score picker
            Row(
              children: [
                Expanded(child: _teamCol(widget.match.homeTeam, p)),
                _Counter(
                    value: _home,
                    onChanged: locked || passed
                        ? null
                        : (v) => setState(() => _home = v)),
                Container(
                  width: 14,
                  alignment: Alignment.center,
                  child: Text(':',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: p.textLow)),
                ),
                _Counter(
                    value: _away,
                    onChanged: locked || passed
                        ? null
                        : (v) => setState(() => _away = v)),
                Expanded(child: _teamCol(widget.match.awayTeam, p)),
              ],
            ),
            const SizedBox(height: 14),

            // Community bar
            if (community.totalPredictions > 0) ...[
              _CommunityBar(match: widget.match, stats: community, palette: p),
              const SizedBox(height: 12),
            ],

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(locked
                            ? Icons.refresh_rounded
                            : Icons.check_circle_rounded),
                    label: Text(locked ? 'Update' : 'Submit prediction'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: locked ? p.surfaceHi : AppTheme.brand,
                      foregroundColor: locked
                          ? p.textHi
                          : (p.isDark ? Colors.black : Colors.white),
                    ),
                    onPressed: (passed || _submitting) ? null : _submit,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  style: IconButton.styleFrom(
                    backgroundColor: p.surfaceHi,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.rSm)),
                    padding: const EdgeInsets.all(14),
                  ),
                  onPressed: () => Share.share(
                    '⚽ I predict ${widget.match.homeTeam.name} $_home–$_away '
                    '${widget.match.awayTeam.name}!\n\nJoin me on Football Fan Hub 2026 🏆',
                  ),
                ),
              ],
            ),

            // Locked badge
            if (locked)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 11, color: AppTheme.brand.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      'Your pick: ${widget.match.homeTeam.tla} '
                      '${widget.myPrediction!.homeGoals}–'
                      '${widget.myPrediction!.awayGoals} '
                      '${widget.match.awayTeam.tla}',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.brand.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _teamCol(TeamRef t, Palette p) => Column(
        children: [
          TeamCrestWidget(crestUrl: t.crest, tla: t.tla, size: 36),
          const SizedBox(height: 8),
          Text(t.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 12, color: p.textHi)),
        ],
      );
}

// ─── Community bar ────────────────────────────────────────────────────────────

class _CommunityBar extends StatelessWidget {
  final Match match;
  final CommunityStats stats;
  final Palette palette;
  const _CommunityBar(
      {required this.match, required this.stats, required this.palette});

  @override
  Widget build(BuildContext context) {
    final homePct = (stats.homePct * 100).round();
    final drawPct = (stats.drawPct * 100).round();
    final awayPct = (stats.awayPct * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people_rounded, size: 12, color: palette.textLow),
            const SizedBox(width: 4),
            Text('${stats.totalPredictions} fans predicted',
                style: TextStyle(fontSize: 11, color: palette.textLow)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              if (stats.homePct > 0)
                Expanded(
                  flex: homePct.clamp(1, 98),
                  child: Container(height: 8, color: AppTheme.brand),
                ),
              if (stats.drawPct > 0)
                Expanded(
                  flex: drawPct.clamp(1, 98),
                  child: Container(
                      height: 8, color: palette.textMid.withValues(alpha: 0.5)),
                ),
              if (stats.awayPct > 0)
                Expanded(
                  flex: awayPct.clamp(1, 98),
                  child: Container(height: 8, color: AppTheme.live),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${match.homeTeam.tla} $homePct%',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brand)),
            Text('Draw $drawPct%',
                style: TextStyle(fontSize: 10, color: palette.textLow)),
            Text('$awayPct% ${match.awayTeam.tla}',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.live)),
          ],
        ),
      ],
    );
  }
}

// ─── Leaderboard tab ─────────────────────────────────────────────────────────

class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final lbAsync = ref.watch(leaderboardProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final myName = ref.watch(displayNameProvider);

    return lbAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text('Could not load leaderboard',
            style: TextStyle(color: p.textMid)),
      ),
      data: (entries) {
        // Find my rank
        final myRankIdx = entries.indexWhere((e) => e.uid == myUid);
        final myRank = myRankIdx == -1 ? null : myRankIdx + 1;
        final myEntry = myRankIdx == -1 ? null : entries[myRankIdx];

        // Empty state — WC26 just started, no one has predictions settled yet.
        if (entries.isEmpty) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _MyCard(myUid: myUid, myName: myName, myRank: null, myEntry: null, ref: ref),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.leaderboard_outlined, size: 48,
                        color: p.textLow.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('No rankings yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.textHi)),
                    const SizedBox(height: 6),
                    Text('Submit predictions on finished matches\nto earn points and appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: p.textMid)),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          // +1 for the "You" header card, +1 for section label
          itemCount: entries.length + 2,
          itemBuilder: (_, i) {
            // ── My card at top ─────────────────────────────────────────
            if (i == 0) {
              return _MyCard(
                myUid: myUid,
                myName: myName,
                myRank: myRank,
                myEntry: myEntry,
                ref: ref,
              );
            }

            // ── Section label ──────────────────────────────────────────
            if (i == 1) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text('TOP FANS',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                        color: p.textLow)),
              );
            }

            // ── Leaderboard rows ───────────────────────────────────────
            final idx = i - 2;
            final e = entries[idx];
            final isMe = e.uid == myUid;
            final isTop3 = idx < 3;
            final medals = ['🥇', '🥈', '🥉'];

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.brand.withValues(alpha: 0.1)
                    : isTop3
                        ? AppTheme.brand.withValues(alpha: 0.05)
                        : p.surface,
                borderRadius: BorderRadius.circular(AppTheme.r),
                border: Border.all(
                  color: isMe
                      ? AppTheme.brand.withValues(alpha: 0.4)
                      : isTop3
                          ? AppTheme.brand.withValues(alpha: 0.2)
                          : p.stroke,
                  width: isMe ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Rank
                  SizedBox(
                    width: 32,
                    child: Text(
                      isTop3 ? medals[idx] : '#${idx + 1}',
                      style: TextStyle(
                          fontSize: isTop3 ? 20 : 13,
                          fontWeight: FontWeight.w800,
                          color: p.textMid),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Flag avatar
                  _FlagAvatar(
                    countryCode: e.countryCode,
                    displayName: e.displayName,
                    isMe: isMe,
                    size: 36,
                  ),
                  const SizedBox(width: 10),

                  // Name + stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                e.displayName.isEmpty
                                    ? fanLabel(e.uid)
                                    : e.displayName,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: p.textHi),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.brand,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('YOU',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black)),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${e.predictionsCount} predicted  •  ${e.correctScores} exact ⭐',
                          style: TextStyle(fontSize: 11, color: p.textLow),
                        ),
                      ],
                    ),
                  ),

                  // Points
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${e.totalPoints}',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: p.textHi,
                              height: 1.0)),
                      Text('pts',
                          style: TextStyle(fontSize: 11, color: p.textLow)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── My card (top of leaderboard) ────────────────────────────────────────────

class _MyCard extends StatelessWidget {
  final String myUid;
  final String myName;
  final int? myRank;
  final Object? myEntry;
  final WidgetRef ref;

  const _MyCard({
    required this.myUid,
    required this.myName,
    required this.myRank,
    required this.myEntry,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final hasName = UserProfileService.instance.hasSetName;
    final displayName =
        hasName && myName.isNotEmpty ? myName : 'Tap to set your name';
    final countryCode = UserProfileService.instance.localCountryCode;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: p.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: AppTheme.brand.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Flag / Avatar
          _FlagAvatar(
            countryCode: countryCode,
            displayName: myName,
            isMe: true,
            size: 44,
          ),
          const SizedBox(width: 12),

          // Name + rank
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: hasName ? p.textHi : p.textLow),
                ),
                Text(
                  myRank != null
                      ? 'You are ranked #$myRank'
                      : 'Not on the leaderboard yet',
                  style: TextStyle(fontSize: 12, color: p.textLow),
                ),
              ],
            ),
          ),

          // Edit / Set name button
          ElevatedButton.icon(
            icon: Icon(
              hasName ? Icons.edit_rounded : Icons.person_add_rounded,
              size: 15,
            ),
            label: Text(hasName ? 'Edit' : 'Set name'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brand,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () =>
                showDisplayNameSheet(context, ref, isFirstTime: !hasName),
          ),
        ],
      ),
    );
  }
}

// ─── Stats card ───────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final int points, submitted, settled, exactScores, correctResults;
  const _StatsCard(
      {required this.points,
      required this.submitted,
      required this.settled,
      required this.exactScores,
      required this.correctResults});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final accuracy = settled > 0
        ? ((exactScores + correctResults) / settled * 100).round()
        : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: p.heroGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.brand.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YOUR POINTS',
                    style: TextStyle(
                        color: AppTheme.brand,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$points',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: p.textHi,
                            height: 1.0)),
                    const SizedBox(width: 4),
                    Text('pts',
                        style: TextStyle(
                            color: p.textLow, fontWeight: FontWeight.w700)),
                  ],
                ),
                if (accuracy != null)
                  Text('$accuracy% accuracy',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.brand)),
              ],
            ),
          ),
          _Div(),
          Expanded(child: _Stat(label: 'Predicted', value: '$submitted', p: p)),
          _Div(),
          Expanded(child: _Stat(label: 'Settled', value: '$settled', p: p)),
          _Div(),
          Expanded(child: _Stat(label: 'Exact ⭐', value: '$exactScores', p: p)),
        ],
      ),
    );
  }
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 50, color: AppTheme.of(context).stroke);
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Palette p;
  const _Stat({required this.label, required this.value, required this.p});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: p.textHi)),
          Text(label, style: TextStyle(color: p.textLow, fontSize: 10)),
        ],
      );
}

// ─── Counter ──────────────────────────────────────────────────────────────────

class _Counter extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;
  const _Counter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final enabled = onChanged != null;
    return Column(
      children: [
        InkWell(
          onTap: enabled ? () { HapticFeedback.selectionClick(); onChanged!((value + 1).clamp(0, 20)); } : null,
          customBorder: const CircleBorder(),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: enabled
                    ? AppTheme.brand.withValues(alpha: 0.15)
                    : p.surfaceHi,
                shape: BoxShape.circle),
            child: Icon(Icons.keyboard_arrow_up_rounded,
                color: enabled ? AppTheme.brand : p.textLow, size: 20),
          ),
        ),
        Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: p.surfaceHi,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.stroke),
          ),
          alignment: Alignment.center,
          child: Text('$value',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: p.textHi,
                  height: 1.0)),
        ),
        InkWell(
          onTap: enabled ? () { HapticFeedback.selectionClick(); onChanged!((value - 1).clamp(0, 20)); } : null,
          customBorder: const CircleBorder(),
          child: Container(
            width: 28,
            height: 28,
            decoration:
                BoxDecoration(color: p.surfaceHi, shape: BoxShape.circle),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: enabled ? p.textMid : p.textLow, size: 20),
          ),
        ),
      ],
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const SectionLabel(this.text,
      {this.padding = const EdgeInsets.fromLTRB(0, 18, 0, 6)});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Padding(
      padding: padding,
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
              color: p.textLow)),
    );
  }
}

// ─── Flag avatar widget ───────────────────────────────────────────────────────
// Shows country flag if available, falls back to initial letter circle

class _FlagAvatar extends StatelessWidget {
  final String countryCode;
  final String displayName;
  final bool isMe;
  final double size;

  const _FlagAvatar({
    required this.countryCode,
    required this.displayName,
    required this.isMe,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    if (countryCode.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isMe ? AppTheme.brand : p.stroke,
            width: isMe ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          UserProfileService.flagUrl(countryCode),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _letterAvatar(p),
        ),
      );
    }

    return _letterAvatar(p);
  }

  Widget _letterAvatar(Palette p) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: isMe
              ? AppTheme.brandGradient
              : LinearGradient(
                  colors: [p.surfaceHi, p.stroke],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isMe ? Colors.black : p.textMid,
                fontSize: size * 0.44),
          ),
        ),
      );
}
