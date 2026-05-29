// lib/core/services/share_card_service.dart
//
// Builds polished share text for WhatsApp / any share target.
// We use share_plus + plain text (no image generation) for maximum compat —
// WhatsApp renders multi-line text + emojis perfectly, no Play Store risks.
//
// All strings carry the app name + Play Store link so shared content drives
// installs. No FIFA / official trademark words.

import 'package:share_plus/share_plus.dart';
import '../../shared/models/match.dart';

class ShareCardService {
  static const _appName = 'Football Fan Hub 2026';
  static const _playUrl =
      'https://play.google.com/store/apps/details?id=com.mangojuice.footballfanhub2026';

  /// Predictor share — match-specific score prediction.
  static Future<void> sharePrediction({
    required Match match,
    required int homeGoals,
    required int awayGoals,
    int? userPoints,
  }) async {
    final lines = [
      '⚽ MY PREDICTION',
      '',
      '${match.homeTeam.name}  $homeGoals – $awayGoals  ${match.awayTeam.name}',
      (match.competitionName ?? ''),
      '',
      'Think you can beat me?',
      if (userPoints != null)
        '🔥 I\'ve scored $userPoints prediction points so far',
      '',
      '$_appName — predict every match free',
      _playUrl,
    ];
    await Share.share(lines.where((l) => l.isNotEmpty || l == '').join('\n'),
        subject:
            'My ${match.homeTeam.tla} vs ${match.awayTeam.tla} prediction');
  }

  /// Bracket share — a champion + summary.
  static Future<void> shareBracket({
    required String champion,
    required String runnerUp,
    required List<String> semifinalists,
    int? confidenceScore,
  }) async {
    final lines = [
      '🏆 MY BRACKET',
      '',
      '🥇 Champion: $champion',
      '🥈 Runner-up: $runnerUp',
      if (semifinalists.isNotEmpty)
        '🥉 Semi-finalists: ${semifinalists.take(2).join(", ")}',
      '',
      if (confidenceScore != null) 'Confidence: $confidenceScore%',
      'Built using the Bracket Simulator on $_appName',
      '',
      'Make your own bracket free:',
      _playUrl,
    ];
    await Share.share(lines.join('\n'),
        subject: 'My 2026 bracket — $champion to win!');
  }

  /// Trivia share — score brag for daily trivia.
  static Future<void> shareTrivia({
    required int score,
    required int correctCount,
    required int totalQuestions,
    required int streak,
  }) async {
    final perfect = correctCount == totalQuestions;
    final lines = [
      perfect ? '🏆 PERFECT TRIVIA ROUND!' : '🧠 DAILY TRIVIA SCORE',
      '',
      '$correctCount / $totalQuestions correct',
      '$score points',
      '🔥 $streak day streak',
      '',
      'Try today\'s 10 questions on $_appName:',
      _playUrl,
    ];
    await Share.share(lines.join('\n'),
        subject: 'I scored $score in today\'s football trivia');
  }

  /// Match details share — current score + scorers.
  static Future<void> shareMatch(Match match) async {
    final scorerLines = <String>[];
    for (final g in match.goals) {
      if (g.scorerName == null) continue;
      final side = g.teamId == match.homeTeam.id
          ? match.homeTeam.tla
          : match.awayTeam.tla;
      final suffix = g.isPenalty
          ? ' (P)'
          : g.isOwnGoal
              ? ' (OG)'
              : '';
      scorerLines.add('$side ${g.minute}\'  ${g.scorerName}$suffix');
    }
    final lines = [
      '⚽ ${match.homeTeam.name}  ${match.score.display}  ${match.awayTeam.name}',
      if (match.competitionName != null) match.competitionName!,
      '',
      ...scorerLines,
      if (scorerLines.isEmpty) '',
      'Follow live on $_appName:',
      _playUrl,
    ];
    await Share.share(lines.join('\n'),
        subject:
            '${match.homeTeam.tla} ${match.score.display} ${match.awayTeam.tla}');
  }

  /// Generic app share.
  static Future<void> shareApp() async {
    await Share.share(
      '$_appName — free scores, predictor, trivia & bracket for football 2026!\n\n$_playUrl',
    );
  }
}
