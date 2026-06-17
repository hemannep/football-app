// lib/core/services/trivia_service.dart
//
// Loads day-matched trivia rounds from assets/data/trivia_rounds.json and
// serves the right round for any given day:
//
//   1. Exact-day match (e.g. "2026-06-20")     → returns that round
//   2. No exact match                          → falls back to "default" round
//
// The JSON shape is described in the spec:
//   { matchDay, stage, teamsPlaying, questions: [{q, options, correct, ...}] }
//
// Caches the parsed JSON for the app lifetime so repeated calls don't reparse.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../shared/models/trivia.dart';

class TriviaService {
  static List<TriviaRound>? _cache;

  /// Loads ALL rounds once (cached for the app lifetime).
  static Future<List<TriviaRound>> _loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/trivia_rounds.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final rounds = ((data['rounds'] ?? []) as List)
        .map((e) => TriviaRound.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache = rounds;
    return rounds;
  }

  /// Returns the trivia round for [date], or the default round if no
  /// matching day exists. Date is formatted as YYYY-MM-DD.
  static Future<TriviaRound?> roundForDate(DateTime date) async {
    final all = await _loadAll();
    final key =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    for (final r in all) {
      if (r.matchDay == key) return r;
    }
    for (final r in all) {
      if (r.matchDay == 'default') return r;
    }
    return all.isNotEmpty ? all.first : null;
  }

  /// Returns ALL configured tournament days (excludes "default").
  static Future<List<String>> matchDays() async {
    final all = await _loadAll();
    return all
        .where((r) => r.matchDay != 'default')
        .map((r) => r.matchDay)
        .toList();
  }
}
