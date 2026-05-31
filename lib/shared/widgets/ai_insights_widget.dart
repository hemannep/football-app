// lib/shared/widgets/ai_insights_widget.dart
//
// Spec feature #20 — AI-style Match Insights.
// Wires MatchInsightsService into a card for the match details Summary tab.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/live_data_service.dart';
import '../../core/services/match_insights_service.dart';
import '../../core/theme/app_theme.dart';
import '../models/match.dart';

final _teamMatchesProvider =
    FutureProvider.family.autoDispose<List<Match>, int>((ref, teamId) async {
  final all = await LiveDataService.instance.getMatches();
  return all
      .where((m) =>
          (m.homeTeam.id != null && m.homeTeam.id == teamId) ||
          (m.awayTeam.id != null && m.awayTeam.id == teamId))
      .toList();
});

class AiInsightsWidget extends ConsumerWidget {
  final Match match;
  const AiInsightsWidget({super.key, required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final homeId = match.homeTeam.id;
    final awayId = match.awayTeam.id;
    if (homeId == null || awayId == null) return const SizedBox.shrink();

    final homeA = ref.watch(_teamMatchesProvider(homeId));
    final awayA = ref.watch(_teamMatchesProvider(awayId));
    final homeMatches = homeA.value ?? const <Match>[];
    final awayMatches = awayA.value ?? const <Match>[];

    final insightsHome = MatchInsightsService.insightsForTeam(
        tla: match.homeTeam.tla, recentMatches: homeMatches);
    final insightsAway = MatchInsightsService.insightsForTeam(
        tla: match.awayTeam.tla, recentMatches: awayMatches);

    if (insightsHome.isEmpty && insightsAway.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 16, color: AppTheme.brand),
              SizedBox(width: 6),
              Text('INSIGHTS',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brand)),
            ],
          ),
          const SizedBox(height: 10),
          if (insightsHome.isNotEmpty) ...[
            _teamBlock(p, match.homeTeam.tla, insightsHome, AppTheme.brand),
            const SizedBox(height: 8),
          ],
          if (insightsAway.isNotEmpty) ...[
            _teamBlock(p, match.awayTeam.tla, insightsAway, AppTheme.live),
          ],
          const SizedBox(height: 6),
          Text('Generated locally from recent match data — not predictions.',
              style: TextStyle(
                  fontSize: 10, color: p.textLow, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _teamBlock(Palette p, String tla, List<String> lines, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(tla,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: 0.5)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...lines.map((line) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(line,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: p.textMid,
                            fontWeight: FontWeight.w600,
                            height: 1.4)),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
