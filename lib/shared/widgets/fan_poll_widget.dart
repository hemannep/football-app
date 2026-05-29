// lib/shared/widgets/fan_poll_widget.dart
//
// Drop-in widget that shows a fan poll for a given match.
// Designed to be placed inside the match details Summary tab or anywhere
// a single match is featured.

import 'package:flutter/material.dart';
import '../../core/services/fan_polls_service.dart';
import '../../core/theme/app_theme.dart';
import '../models/match.dart';

class FanPollWidget extends StatefulWidget {
  final Match match;
  const FanPollWidget({super.key, required this.match});

  @override
  State<FanPollWidget> createState() => _FanPollWidgetState();
}

class _FanPollWidgetState extends State<FanPollWidget> {
  late FanPoll _poll;

  @override
  void initState() {
    super.initState();
    _poll = FanPollsService.forMatch(widget.match);
  }

  void _vote(int i) {
    if (_poll.userChoice == i) return;
    setState(() {
      _poll = FanPollsService.vote(_poll.id, i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final hasVoted = _poll.userChoice != null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_rounded, size: 16, color: AppTheme.brand),
              const SizedBox(width: 6),
              const Text('FAN POLL',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brand)),
              const Spacer(),
              Text(hasVoted ? '${_poll.totalVotes} votes' : 'Tap to vote',
                  style: TextStyle(
                      fontSize: 11,
                      color: p.textLow,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(_poll.question,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: p.textHi)),
          const SizedBox(height: 10),
          ...List.generate(_poll.options.length, (i) {
            final isMine = _poll.userChoice == i;
            final pct = _poll.percent(i);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                onTap: () => _vote(i),
                borderRadius: BorderRadius.circular(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: p.surfaceHi,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      if (hasVoted)
                        FractionallySizedBox(
                          widthFactor: pct,
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: isMine
                                  ? AppTheme.brand.withValues(alpha: 0.45)
                                  : AppTheme.brand.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            if (isMine)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.check_circle_rounded,
                                    size: 14, color: AppTheme.brand),
                              ),
                            Expanded(
                              child: Text(_poll.options[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: p.textHi)),
                            ),
                            if (hasVoted)
                              Text('${(pct * 100).round()}%',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: p.textMid)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
