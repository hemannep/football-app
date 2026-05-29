// lib/core/services/fan_polls_service.dart
//
// Spec feature #10 — Fan Polls.
//
// Local-only voting (no Firebase). Each poll is stored in Hive box 'fan_polls':
//
//   poll:{id} → { question, options[], votes[], userChoice }
//
// Polls are generated automatically from upcoming matches ("Who wins?",
// "Best player?", etc.) or seeded from a static list of generic polls.
// Votes are local — we show the user their own tally and a simulated
// distribution so the experience feels active (no backend required).

import 'dart:convert';
import 'dart:math';
import 'package:hive/hive.dart';
import '../../shared/models/match.dart';

class FanPoll {
  final String id;
  final String question;
  final List<String> options;
  final List<int> votes; // local + seeded counts
  final int? userChoice;
  const FanPoll({
    required this.id,
    required this.question,
    required this.options,
    required this.votes,
    this.userChoice,
  });

  int get totalVotes => votes.fold(0, (a, b) => a + b);

  /// Percentage of votes for option at [index].
  double percent(int index) {
    if (totalVotes == 0) return 0;
    return votes[index] / totalVotes;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'options': options,
        'votes': votes,
        'userChoice': userChoice,
      };

  factory FanPoll.fromJson(Map<String, dynamic> j) => FanPoll(
        id: j['id'] as String,
        question: j['question'] as String,
        options: List<String>.from(j['options'] ?? []),
        votes: List<int>.from(j['votes'] ?? []),
        userChoice: j['userChoice'] as int?,
      );

  FanPoll copyWith({int? userChoice, List<int>? votes}) => FanPoll(
        id: id,
        question: question,
        options: options,
        votes: votes ?? this.votes,
        userChoice: userChoice ?? this.userChoice,
      );
}

class FanPollsService {
  static const _boxName = 'fan_polls';

  static Box get _box => Hive.box(_boxName);

  /// Builds the poll for a specific match: "Who wins?"
  /// If a poll already exists for this match, returns the stored one so the
  /// user's vote (and the seeded counts) persist across launches.
  static FanPoll forMatch(Match match) {
    final id = 'match:${match.matchKey}';
    final stored = _box.get(id);
    if (stored != null) {
      try {
        return FanPoll.fromJson(
            jsonDecode(stored as String) as Map<String, dynamic>);
      } catch (_) {}
    }
    // Seed with plausible vote counts so the bars look populated.
    final seed = _seedRandom(id);
    final base = 80 + seed.nextInt(220); // 80-300 votes total
    final homeShare = 0.30 + seed.nextDouble() * 0.4; // 30-70%
    final drawShare = 0.10 + seed.nextDouble() * 0.20; // 10-30% of remaining
    final remaining = 1 - homeShare;
    final draw = remaining * drawShare;
    final away = remaining - draw;
    final poll = FanPoll(
      id: id,
      question: 'Who wins this match?',
      options: [
        '${match.homeTeam.name} win',
        'Draw',
        '${match.awayTeam.name} win',
      ],
      votes: [
        (base * homeShare).round(),
        (base * draw).round(),
        (base * away).round(),
      ],
      userChoice: null,
    );
    _persist(poll);
    return poll;
  }

  /// Casts a vote. If the user has already voted, replaces their choice
  /// (subtract the old, add the new). Returns the updated poll.
  static FanPoll vote(String pollId, int optionIndex) {
    final stored = _box.get(pollId);
    if (stored == null) {
      throw StateError('Poll $pollId does not exist');
    }
    final poll =
        FanPoll.fromJson(jsonDecode(stored as String) as Map<String, dynamic>);
    final newVotes = List<int>.from(poll.votes);
    if (poll.userChoice != null && poll.userChoice! < newVotes.length) {
      newVotes[poll.userChoice!] =
          (newVotes[poll.userChoice!] - 1).clamp(0, 1 << 30);
    }
    if (optionIndex < 0 || optionIndex >= newVotes.length) {
      throw RangeError.index(optionIndex, newVotes, 'optionIndex');
    }
    newVotes[optionIndex] += 1;
    final updated = poll.copyWith(userChoice: optionIndex, votes: newVotes);
    _persist(updated);
    return updated;
  }

  static void _persist(FanPoll poll) {
    _box.put(poll.id, jsonEncode(poll.toJson()));
  }

  static Random _seedRandom(String id) {
    var hash = 0;
    for (final cu in id.codeUnits) {
      hash = (hash * 31 + cu) & 0x7fffffff;
    }
    return Random(hash);
  }
}
