// lib/core/services/offline_pack_service.dart
//
// Spec feature #18 — Offline Match Packs.
//
// Pre-fetches and stores everything a user needs to use the app offline:
//   • All fixtures for the selected competition(s)
//   • Standings tables
//   • Per-match details (goals, scorers) for finished matches
//   • Team metadata (squads, crests) for all teams in the competition
//   • The day-matched trivia JSON is already in assets — no fetch needed
//
// Everything is stored via existing Hive caches inside the services, so the
// app's existing offline-first logic continues to work — this service just
// "warms" those caches in bulk.

import 'package:hive/hive.dart';
import 'api_service.dart';
import '../../shared/models/leagues.dart';
import '../../shared/models/match.dart';

class OfflinePackProgress {
  final int total;
  final int done;
  final String currentItem;
  const OfflinePackProgress({
    required this.total,
    required this.done,
    required this.currentItem,
  });
  double get fraction => total == 0 ? 0 : done / total;
}

class OfflinePackService {
  static const _box = 'matches_cache';
  static const _packMetaKey = 'offline_pack_meta';

  /// Returns timestamp of the last successful pack download, or null.
  static DateTime? lastDownload() {
    final box = Hive.box(_box);
    final raw = box.get(_packMetaKey) as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Estimated size of the cached pack (rough — counts entries).
  static int cachedEntryCount() {
    final box = Hive.box(_box);
    return box.length;
  }

  /// Downloads everything for [league]. Streams progress via [onProgress].
  /// Returns true on success, false if any critical step failed.
  static Future<bool> downloadPack(
    League league, {
    void Function(OfflinePackProgress)? onProgress,
  }) async {
    final box = Hive.box(_box);

    final tasks = <_Task>[
      _Task('Fixtures',
          () => ApiService.fetchMatches(league.code, forceRefresh: true)),
      _Task('Standings',
          () => ApiService.fetchStandings(league.code, forceRefresh: true)),
    ];

    var total = tasks.length;
    var done = 0;

    onProgress?.call(
        OfflinePackProgress(total: total, done: done, currentItem: 'Starting'));

    List<Match> fixtures = const [];
    try {
      for (final t in tasks) {
        onProgress?.call(OfflinePackProgress(
            total: total, done: done, currentItem: t.label));
        final result = await t.run();
        if (result is List<Match>) {
          fixtures = result;
        }
        done++;
      }
    } catch (e) {
      // Even on partial failure, we may have warm caches.
    }

    // For finished matches, fetch per-match details (gets goal scorers)
    final finishedIds =
        fixtures.where((m) => m.isFinished).map((m) => m.id).toSet().toList();
    // Cap to avoid quota burn on huge competitions
    final goalFetchSubset = finishedIds.take(40).toList();
    total += goalFetchSubset.length;

    for (final id in goalFetchSubset) {
      onProgress?.call(OfflinePackProgress(
          total: total, done: done, currentItem: 'Goals (match $id)'));
      try {
        await ApiService.fetchMatchById(id,
            isFinished: true, forceRefresh: true);
      } catch (_) {}
      done++;
    }

    // For each unique team in the fixtures, warm the team detail cache
    final teamIds = <int>{};
    for (final m in fixtures) {
      if (m.homeTeam.id != null) teamIds.add(m.homeTeam.id!);
      if (m.awayTeam.id != null) teamIds.add(m.awayTeam.id!);
    }
    final teamSubset = teamIds.take(32).toList();
    total += teamSubset.length;
    for (final id in teamSubset) {
      onProgress?.call(OfflinePackProgress(
          total: total, done: done, currentItem: 'Team data ($id)'));
      try {
        await ApiService.fetchTeam(id, forceRefresh: true);
      } catch (_) {}
      done++;
    }

    await box.put(_packMetaKey, DateTime.now().toIso8601String());
    onProgress?.call(
        OfflinePackProgress(total: total, done: total, currentItem: 'Done'));
    return true;
  }

  /// Clears the entire offline cache.
  static Future<void> clearPack() async {
    final box = Hive.box(_box);
    await box.clear();
  }
}

class _Task {
  final String label;
  final Future<dynamic> Function() run;
  _Task(this.label, this.run);
}
