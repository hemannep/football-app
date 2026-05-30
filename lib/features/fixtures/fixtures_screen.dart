import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/live_score_provider.dart';
import '../../core/services/live_data_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/match_card.dart';
import '../league picker/league_picker.dart';
import '../match details/match_details_screen.dart';

class FixturesScreen extends ConsumerStatefulWidget {
  const FixturesScreen({super.key});
  @override
  ConsumerState<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends ConsumerState<FixturesScreen> {
  String _query = '';
  String _stage = 'ALL';
  String _filter = 'ALL';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final s = ref.watch(liveScoreProvider);
    final freshnessLabel =
        ref.watch(relayMetaProvider).asData?.value.freshnessLabel ?? '';
    final stages = [
      'ALL',
      ...{...s.matches.map((m) => m.stage)}
    ];

    final list = s.matches.where((m) {
      final mq = _query.isEmpty ||
          m.homeTeam.name.toLowerCase().contains(_query.toLowerCase()) ||
          m.awayTeam.name.toLowerCase().contains(_query.toLowerCase()) ||
          m.homeTeam.tla.toLowerCase().contains(_query.toLowerCase()) ||
          m.awayTeam.tla.toLowerCase().contains(_query.toLowerCase());
      final ms = _stage == 'ALL' || m.stage == _stage;
      final mf = switch (_filter) {
        'LIVE' => m.isLive,
        'UPCOMING' => m.isScheduled,
        'FINISHED' => m.isFinished,
        _ => true,
      };
      return mq && ms && mf;
    }).toList()
      ..sort((a, b) => a.utcDate.compareTo(b.utcDate));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Fixtures',
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
            if (freshnessLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(freshnessLabel,
                      style: TextStyle(fontSize: 11, color: p.textLow)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search team or country…',
                  prefixIcon:
                      Icon(Icons.search_rounded, color: p.textLow, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 18, color: p.textLow),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip('All', 'ALL'),
                  _filterChip('🔴 Live', 'LIVE'),
                  _filterChip('Upcoming', 'UPCOMING'),
                  _filterChip('Finished', 'FINISHED'),
                ],
              ),
            ),
            if (stages.length > 2)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: stages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final st = stages[i];
                    return ChoiceChip(
                      label: Text(_prettyStage(st)),
                      selected: st == _stage,
                      onSelected: (_) => setState(() => _stage = st),
                    );
                  },
                ),
              ),
            const SizedBox(height: 4),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.brand,
                onRefresh: () =>
                    ref.read(liveScoreProvider.notifier).forceRefresh(),
                child: list.isEmpty
                    ? _empty(p, s.isLoading)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24, top: 4),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final m = list[i];
                          final showHeader = i == 0 ||
                              !_sameDay(list[i - 1].utcDate, m.utcDate);
                          return Column(
                            children: [
                              if (showHeader) _dateHeader(p, m.utcDate),
                              MatchCard(
                                match: m,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MatchDetailsScreen(match: m),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final sel = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _dateHeader(Palette p, DateTime dt) {
    final isToday = _sameDay(dt, DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: isToday ? AppTheme.brand : p.textLow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isToday
                ? 'TODAY • ${DateFormat('d MMM').format(dt).toUpperCase()}'
                : DateFormat('EEE, d MMM').format(dt).toUpperCase(),
            style: TextStyle(
              color: isToday ? AppTheme.brand : p.textMid,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(Palette p, bool loading) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              loading ? Icons.hourglass_top_rounded : Icons.search_off_rounded,
              size: 48,
              color: p.textLow,
            ),
            const SizedBox(height: 14),
            Text(
              loading ? 'Loading fixtures…' : 'No matches found',
              style: TextStyle(
                color: p.textMid,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _prettyStage(String s) {
    if (s == 'ALL') return 'All stages';
    return s
        .split('_')
        .map((p) => p.isEmpty ? p : p[0] + p.substring(1).toLowerCase())
        .join(' ');
  }
}
