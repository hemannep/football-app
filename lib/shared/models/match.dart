class Match {
  final int id;
  final String status;
  final DateTime utcDate;
  final TeamRef homeTeam;
  final TeamRef awayTeam;
  final Score score;
  final String stage;
  final String? group;
  final String? competitionName;
  final String? competitionCode;
  final String? venue;
  final List<MatchGoal> goals;
  // Actual live match minute stored by the relay (null until relay updates).
  final int? minute;
  // Enrichment fields written by bzzoiro_enricher.js into the Firestore doc.
  final String? referee;
  final int? attendance;
  // BSD event ID cached in Firestore by the enricher so the Flutter client
  // doesn't need to re-resolve it from BSD on every match-detail open.
  final int? bzzoiroId;

  const Match({
    required this.id,
    required this.status,
    required this.utcDate,
    required this.homeTeam,
    required this.awayTeam,
    required this.score,
    required this.stage,
    this.group,
    this.competitionName,
    this.competitionCode,
    this.venue,
    this.goals = const [],
    this.minute,
    this.referee,
    this.attendance,
    this.bzzoiroId,
  });

  factory Match.fromJson(Map<String, dynamic> j) {
    final goalsList = (j['goals'] as List?) ?? [];
    return Match(
      id: j['id'] ?? 0,
      status: j['status'] ?? 'SCHEDULED',
      utcDate: DateTime.parse(j['utcDate']).toLocal(),
      homeTeam: TeamRef.fromJson(j['homeTeam'] ?? {}),
      awayTeam: TeamRef.fromJson(j['awayTeam'] ?? {}),
      score: Score.fromJson(j['score'] ?? {}),
      stage: j['stage'] ?? 'GROUP_STAGE',
      group: j['group'],
      competitionName: j['competition']?['name'],
      competitionCode: j['competition']?['code'],
      venue: j['venue'],
      goals: goalsList.map((e) => MatchGoal.fromJson(e)).toList(),
      minute: j['minute'] as int?,
      referee: j['referee'] as String?,
      attendance: j['attendance'] as int?,
      bzzoiroId: j['bzzoiroId'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'utcDate': utcDate.toUtc().toIso8601String(),
        'homeTeam': homeTeam.toJson(),
        'awayTeam': awayTeam.toJson(),
        'score': score.toJson(),
        'stage': stage,
        'group': group,
        'competition': {'name': competitionName, 'code': competitionCode},
        'venue': venue,
        'goals': goals.map((g) => g.toJson()).toList(),
        if (minute != null) 'minute': minute,
        if (referee != null) 'referee': referee,
        if (attendance != null) 'attendance': attendance,
        if (bzzoiroId != null) 'bzzoiroId': bzzoiroId,
      };

  bool get isLive => status == 'IN_PLAY' || status == 'PAUSED';
  bool get isFinished => status == 'FINISHED';
  bool get isScheduled => status == 'SCHEDULED' || status == 'TIMED';

  String get matchKey =>
      '${utcDate.toIso8601String().substring(0, 10)}-${homeTeam.tla}-${awayTeam.tla}';

  bool sameDay(DateTime d) =>
      utcDate.year == d.year &&
      utcDate.month == d.month &&
      utcDate.day == d.day;
}

class TeamRef {
  final int? id;
  final String name;
  final String tla;
  final String? crest;

  const TeamRef({this.id, required this.name, required this.tla, this.crest});

  factory TeamRef.fromJson(Map<String, dynamic> j) => TeamRef(
        id: j['id'],
        name: j['name'] ?? 'TBD',
        tla: j['tla'] ?? '???',
        crest: j['crest'],
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'tla': tla, 'crest': crest};
}

class Score {
  final int? homeGoals;
  final int? awayGoals;
  final String? winner;
  final String? duration;

  const Score({this.homeGoals, this.awayGoals, this.winner, this.duration});

  factory Score.fromJson(Map<String, dynamic> j) {
    final ft = j['fullTime'] ?? {};
    return Score(
      homeGoals: ft['home'],
      awayGoals: ft['away'],
      winner: j['winner'],
      duration: j['duration'],
    );
  }

  Map<String, dynamic> toJson() => {
        'fullTime': {'home': homeGoals, 'away': awayGoals},
        'winner': winner,
        'duration': duration,
      };

  String get display => homeGoals == null ? 'vs' : '$homeGoals – $awayGoals';
}

class MatchGoal {
  final int minute;
  final String? scorerName;
  final String? scorerTla;
  final int? teamId;
  final String type;
  final String? assistName;

  const MatchGoal({
    required this.minute,
    this.scorerName,
    this.scorerTla,
    this.teamId,
    this.type = 'REGULAR',
    this.assistName,
  });

  factory MatchGoal.fromJson(Map<String, dynamic> j) => MatchGoal(
        minute: j['minute'] ?? 0,
        scorerName: j['scorer']?['name'],
        teamId: j['team']?['id'],
        scorerTla: j['team']?['tla'],
        type: j['type'] ?? 'REGULAR',
        assistName: j['assist']?['name'],
      );

  Map<String, dynamic> toJson() => {
        'minute': minute,
        'scorer': {'name': scorerName},
        'team': {'id': teamId, 'tla': scorerTla},
        'type': type,
        'assist': {'name': assistName},
      };

  bool get isPenalty => type == 'PENALTY';
  bool get isOwnGoal => type == 'OWN';
}
