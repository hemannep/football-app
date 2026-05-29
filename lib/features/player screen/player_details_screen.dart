// lib/features/player details/player_details_screen.dart
//
// Player detail screen — opens when a player card / pitch player is tapped.
//
// Data sources:
//   • TheSportsDB searchplayers.php      → photo, bio, nationality, team,
//                                           position, height, weight, wage
//   • Wikipedia (already wired into SportsDbService) for photo fallback
//
// Includes a banner ad at the bottom.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/live_data_service.dart';
import '../../core/services/sportsdb_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ad_banner_widget.dart';

final _playerProvider = FutureProvider.family
    .autoDispose<SportsDbPlayer?, String>((ref, key) async {
  final parts = key.split('|');
  final name = parts.isNotEmpty ? parts[0] : '';
  final hint = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
  return SportsDbService.searchPlayer(name, teamHint: hint);
});

class PlayerDetailScreen extends ConsumerWidget {
  final String name;
  final String? teamHint;
  final int? shirtNumber;
  final String? position;
  final int? playerId;
  const PlayerDetailScreen({
    super.key,
    required this.name,
    this.teamHint,
    this.shirtNumber,
    this.position,
    this.playerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);

    // Prefer Firestore when playerId is known; SportsDB fills the gaps.
    final fsAsync =
        playerId != null ? ref.watch(playerProvider(playerId!)) : null;
    final sdbAsync = ref.watch(_playerProvider('$name|${teamHint ?? ''}'));

    final fsPlayer = fsAsync?.value;
    final sdbPlayer = sdbAsync.value;

    final bool isLoading =
        (fsAsync?.isLoading ?? false) || (fsAsync == null && sdbAsync.isLoading);

    // Merge: Firestore fields take precedence, SportsDB fills anything missing.
    final displayPhoto = (fsPlayer?['photoUrl'] as String?) ??
        sdbPlayer?.photoUrl ??
        sdbPlayer?.thumbUrl;
    final resolvedPosition = (fsPlayer?['position'] as String?) ??
        sdbPlayer?.position ??
        position;

    int? age;
    final dobStr = fsPlayer?['dateOfBirth'] as String?;
    if (dobStr != null) {
      final dob = DateTime.tryParse(dobStr);
      if (dob != null) age = DateTime.now().difference(dob).inDays ~/ 365;
    } else if (sdbPlayer?.birthYear != null) {
      age = DateTime.now().year - sdbPlayer!.birthYear!;
    }

    final teamVal =
        (fsPlayer?['teamName'] as String?) ?? sdbPlayer?.team;
    final nationalityVal =
        (fsPlayer?['nationality'] as String?) ?? sdbPlayer?.nationality;
    final heightVal = sdbPlayer?.height;
    final weightVal = sdbPlayer?.weight;
    final bio = sdbPlayer?.description;

    final rows = <(IconData, String, String)>[];
    if (resolvedPosition != null) {
      rows.add((Icons.sports_soccer_rounded, 'Position', resolvedPosition));
    }
    if (teamVal != null) rows.add((Icons.shield_rounded, 'Team', teamVal));
    if (nationalityVal != null) {
      rows.add((Icons.public_rounded, 'Nationality', nationalityVal));
    }
    if (age != null) rows.add((Icons.cake_rounded, 'Age', '$age yrs'));
    if (heightVal != null && heightVal.isNotEmpty) {
      rows.add((Icons.height_rounded, 'Height', heightVal));
    }
    if (weightVal != null && weightVal.isNotEmpty) {
      rows.add((Icons.fitness_center_rounded, 'Weight', weightVal));
    }
    if (shirtNumber != null) {
      rows.add((Icons.tag_rounded, 'Shirt', '#$shirtNumber'));
    }

    final noData = !isLoading && fsPlayer == null && sdbPlayer == null;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 280,
                  backgroundColor: p.bg,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.share_rounded),
                      onPressed: () =>
                          Share.share('⚽ $name on Football Fan Hub 2026'),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _PlayerHero(
                      name: name,
                      photoUrl: displayPhoto,
                      position: resolvedPosition,
                      shirtNumber: shirtNumber,
                    ),
                  ),
                ),
                if (isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  SliverList(
                    delegate: SliverChildListDelegate([
                      _InfoSection(title: 'PROFILE', rows: rows),
                      if (bio != null && bio.isNotEmpty) ...[
                        const _SectionLabel('BIOGRAPHY'),
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(AppTheme.r),
                            border: Border.all(color: p.stroke),
                          ),
                          child: Text(bio,
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: p.textMid)),
                        ),
                      ],
                      if (noData)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.person_off_outlined,
                                  size: 48, color: p.textLow),
                              const SizedBox(height: 12),
                              Text('Limited info available',
                                  style: TextStyle(
                                      color: p.textMid,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('No public bio for this player.',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(color: p.textLow, fontSize: 12)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                    ]),
                  ),
              ],
            ),
          ),
          const AdBannerWidget(),
        ],
      ),
    );
  }
}

// ─── Hero ──────────────────────────────────────────────────────────────────

class _PlayerHero extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String? position;
  final int? shirtNumber;
  const _PlayerHero({
    required this.name,
    required this.photoUrl,
    required this.position,
    required this.shirtNumber,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: Container(
                      width: 120,
                      height: 120,
                      color: Colors.black26,
                      child: photoUrl != null
                          ? Image.network(
                              photoUrl!,
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
                              errorBuilder: (_, __, ___) => _initialsBox(),
                            )
                          : _initialsBox(),
                    ),
                  ),
                  if (shirtNumber != null)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text('#$shirtNumber',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              if (position != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(position!.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _initialsBox() => Container(
        width: 120,
        height: 120,
        color: const Color(0xFF263238),
        alignment: Alignment.center,
        child: Text(_initials,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w900)),
      );
}

// ─── Info section ──────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final String title;
  final List<(IconData, String, String)> rows;
  const _InfoSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title),
        ...rows.map((r) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.stroke),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(r.$1, size: 16, color: AppTheme.brand),
                  ),
                  const SizedBox(width: 10),
                  Text(r.$2,
                      style: TextStyle(
                          fontSize: 12,
                          color: p.textLow,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Flexible(
                      child: Text(r.$3,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: p.textHi))),
                ],
              ),
            )),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
              color: p.textLow)),
    );
  }
}
