class GroupTable {
  final String groupName;
  final List<TeamStanding> teams;
  const GroupTable({required this.groupName, required this.teams});

  factory GroupTable.fromJson(Map<String, dynamic> j) => GroupTable(
        groupName: j['group'] ?? 'GROUP',
        teams: ((j['table'] ?? []) as List)
            .map((e) => TeamStanding.fromJson(e))
            .toList(),
      );
}

class TeamStanding {
  final int position;
  final int? teamId;
  final String teamName;
  final String tla;
  final String? crest;
  final int playedGames;
  final int won;
  final int draw;
  final int lost;
  final int points;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;

  const TeamStanding({
    required this.position,
    this.teamId,
    required this.teamName,
    required this.tla,
    this.crest,
    required this.playedGames,
    required this.won,
    required this.draw,
    required this.lost,
    required this.points,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
  });

  factory TeamStanding.fromJson(Map<String, dynamic> j) {
    final team = j['team'] ?? {};
    return TeamStanding(
      position: j['position'] ?? 0,
      teamId: team['id'],
      teamName: team['name'] ?? 'TBD',
      tla: team['tla'] ?? '???',
      crest: team['crest'],
      playedGames: j['playedGames'] ?? 0,
      won: j['won'] ?? 0,
      draw: j['draw'] ?? 0,
      lost: j['lost'] ?? 0,
      points: j['points'] ?? 0,
      goalsFor: j['goalsFor'] ?? 0,
      goalsAgainst: j['goalsAgainst'] ?? 0,
      goalDifference: j['goalDifference'] ?? 0,
    );
  }
}
