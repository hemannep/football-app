import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/live_data_service.dart';
import '../../shared/models/match.dart';
import 'selected_leagues_provider.dart';

class LiveScoreState {
  final List<Match> matches;
  final bool isLive;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;
  final String competitionCode;

  const LiveScoreState({
    this.matches = const [],
    this.isLive = false,
    this.isLoading = false,
    this.error,
    this.lastUpdated,
    this.competitionCode = 'WC',
  });

  LiveScoreState copyWith({
    List<Match>? matches,
    bool? isLive,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
    String? competitionCode,
  }) =>
      LiveScoreState(
        matches: matches ?? this.matches,
        isLive: isLive ?? this.isLive,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        competitionCode: competitionCode ?? this.competitionCode,
      );
}

class LiveScoreNotifier extends StateNotifier<LiveScoreState> {
  final Ref _ref;
  StreamSubscription<List<Match>>? _sub;

  LiveScoreNotifier(this._ref) : super(const LiveScoreState()) {
    _ref.listen<dynamic>(selectedLeagueProvider, (prev, next) {
      if (prev?.code != next.code) _subscribe();
    });
    _subscribe();
  }

  void _subscribe() {
    _sub?.cancel();
    final code = _ref.read(selectedLeagueProvider).code;
    state = state.copyWith(
      isLoading: true,
      error: null,
      competitionCode: code,
    );

    _sub = LiveDataService.instance.watchMatches().listen(
      (allMatches) {
        if (!mounted) return;
        // Filter by competition code. Accept matches where the relay omitted
        // the competition object (competitionCode == null) so a mis-configured
        // relay still shows data rather than a blank screen.
        final matches = allMatches
            .where((m) => m.competitionCode == null || m.competitionCode == code)
            .toList();
        state = state.copyWith(
          matches: matches,
          isLive: matches.any((m) => m.isLive),
          isLoading: false,
          error: null,
          lastUpdated: DateTime.now(),
          competitionCode: code,
        );
      },
      onError: (_) {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          error: 'Offline — showing cached data',
        );
      },
    );
  }

  Future<void> forceRefresh() async {
    // Evict the in-memory + Hive match cache so the next getMatches() call
    // goes straight to Firestore instead of serving stale cached data.
    LiveDataService.instance.evict('matches_all');
    _subscribe();
  }

  void pausePolling() => _sub?.pause();

  void resumePolling() {
    if (_sub?.isPaused ?? false) {
      _sub?.resume();
    } else {
      _subscribe();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final liveScoreProvider =
    StateNotifierProvider<LiveScoreNotifier, LiveScoreState>(
        (ref) => LiveScoreNotifier(ref));

