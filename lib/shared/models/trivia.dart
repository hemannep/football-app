class TriviaQuestion {
  final String id;
  final String category;
  final String difficulty;
  final String q;
  final List<String> options;
  final int correct;
  final String? explanation;

  const TriviaQuestion({
    required this.id,
    required this.category,
    required this.difficulty,
    required this.q,
    required this.options,
    required this.correct,
    this.explanation,
  });

  factory TriviaQuestion.fromJson(Map<String, dynamic> j) => TriviaQuestion(
        id: j['id'] ?? '',
        category: j['category'] ?? 'general_football',
        difficulty: j['difficulty'] ?? 'medium',
        q: j['q'] ?? '',
        options: List<String>.from(j['options'] ?? []),
        correct: j['correct'] ?? 0,
        explanation: j['explanation'],
      );
}

class TriviaRound {
  final String matchDay;
  final String stage;
  final List<String> teamsPlaying;
  final List<TriviaQuestion> questions;

  const TriviaRound({
    required this.matchDay,
    required this.stage,
    required this.teamsPlaying,
    required this.questions,
  });

  factory TriviaRound.fromJson(Map<String, dynamic> j) => TriviaRound(
        matchDay: j['matchDay'] ?? '',
        stage: j['stage'] ?? 'group',
        teamsPlaying: List<String>.from(j['teamsPlaying'] ?? []),
        questions: ((j['questions'] ?? []) as List)
            .map((e) => TriviaQuestion.fromJson(e))
            .toList(),
      );
}
