// lib/features/offline_pack/offline_pack_screen.dart
//
// UI for spec feature #18 — Offline Match Packs.
// User picks a competition and taps Download — we warm all the caches so
// the app works offline. Progress is shown in real time.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/selected_leagues_provider.dart';
import '../../core/services/offline_pack_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/leagues.dart';
import '../../shared/widgets/ad_banner_widget.dart';

class OfflinePackScreen extends ConsumerStatefulWidget {
  const OfflinePackScreen({super.key});

  @override
  ConsumerState<OfflinePackScreen> createState() => _OfflinePackScreenState();
}

class _OfflinePackScreenState extends ConsumerState<OfflinePackScreen> {
  OfflinePackProgress? _progress;
  bool _downloading = false;
  String? _error;
  late League _selectedLeague;

  @override
  void initState() {
    super.initState();
    _selectedLeague = ref.read(selectedLeagueProvider);
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = null;
    });
    try {
      await OfflinePackService.downloadPack(
        _selectedLeague,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) {
      setState(() {
        _downloading = false;
      });
    }
  }

  Future<void> _clear() async {
    final p = AppTheme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Clear offline data?', style: TextStyle(color: p.textHi)),
        content: Text(
            'This will delete all cached fixtures, scores, standings, and team data. The app will need to re-fetch from the network next time.',
            style: TextStyle(color: p.textMid)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      await OfflinePackService.clearPack();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final lastDl = OfflinePackService.lastDownload();
    final entries = OfflinePackService.cachedEntryCount();
    final lastLabel = lastDl == null
        ? 'Never downloaded'
        : 'Last downloaded ${DateFormat('d MMM, HH:mm').format(lastDl)}';

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text('Offline Match Pack',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: p.textHi)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: p.heroGradient,
                    borderRadius: BorderRadius.circular(AppTheme.r),
                    border: Border.all(
                        color: AppTheme.brand.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_download_rounded,
                              color: AppTheme.brand, size: 22),
                          const SizedBox(width: 8),
                          Text('Watch without data',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: p.textHi)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Download fixtures, scores, standings, and team data for a competition so you can use the app offline.',
                          style: TextStyle(
                              fontSize: 13, color: p.textMid, height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('SELECT COMPETITION',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                        color: p.textLow)),
                const SizedBox(height: 8),
                ...Leagues.all
                    .map((l) => _LeagueTile(
                          league: l,
                          isSelected: _selectedLeague.code == l.code,
                          onTap: _downloading
                              ? null
                              : () => setState(() => _selectedLeague = l),
                        ))
                    ,
                const SizedBox(height: 20),
                // Download button
                if (!_downloading)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _download,
                      icon: const Icon(Icons.download_rounded),
                      label: Text('Download ${_selectedLeague.name} pack'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brand,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                if (_downloading && _progress != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(AppTheme.r),
                      border: Border.all(color: p.stroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Downloading…',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: p.textHi)),
                        const SizedBox(height: 6),
                        Text(_progress!.currentItem,
                            style: TextStyle(
                                fontSize: 12,
                                color: p.textMid,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _progress!.fraction,
                            minHeight: 8,
                            backgroundColor: p.surfaceHi,
                            valueColor:
                                const AlwaysStoppedAnimation(AppTheme.brand),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                            '${_progress!.done} / ${_progress!.total} (${(_progress!.fraction * 100).round()}%)',
                            style: TextStyle(
                                fontSize: 11,
                                color: p.textLow,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bad.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.bad.withValues(alpha: 0.3)),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppTheme.bad, fontWeight: FontWeight.w700)),
                  ),
                ],
                const SizedBox(height: 24),
                // Status section
                Text('CACHE STATUS',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                        color: p.textLow)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(AppTheme.r),
                    border: Border.all(color: p.stroke),
                  ),
                  child: Column(
                    children: [
                      _row(p, Icons.event_rounded, lastLabel),
                      const SizedBox(height: 8),
                      _row(p, Icons.storage_rounded, '$entries cached items'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _downloading ? null : _clear,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Clear offline data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.bad,
                    side:
                        BorderSide(color: AppTheme.bad.withValues(alpha: 0.4)),
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ],
            ),
          ),
          const AdBannerWidget(),
        ],
      ),
    );
  }

  Widget _row(Palette p, IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.brand),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 12,
                      color: p.textMid,
                      fontWeight: FontWeight.w700))),
        ],
      );
}

class _LeagueTile extends StatelessWidget {
  final League league;
  final bool isSelected;
  final VoidCallback? onTap;
  const _LeagueTile({
    required this.league,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected ? AppTheme.brand.withValues(alpha: 0.15) : p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? AppTheme.brand : p.stroke,
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(Icons.emoji_events_rounded,
                size: 18, color: isSelected ? AppTheme.brand : p.textLow),
            const SizedBox(width: 10),
            Expanded(
              child: Text(league.name,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: p.textHi)),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.brand, size: 18),
          ],
        ),
      ),
    );
  }
}
