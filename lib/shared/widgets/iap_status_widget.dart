// lib/shared/widgets/iap_status_widget.dart
//
// Reusable IAP status banner — drop on any screen to show whether the user
// has an active "Remove Ads" subscription + a one-tap restore button. Helps
// the $1.99/month IAP flow feel polished.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/iap_service.dart';
import '../../core/theme/app_theme.dart';

class IapStatusWidget extends ConsumerStatefulWidget {
  /// If true, hides the banner when ads are already removed.
  final bool hideWhenRemoved;
  const IapStatusWidget({super.key, this.hideWhenRemoved = false});

  @override
  ConsumerState<IapStatusWidget> createState() => _IapStatusWidgetState();
}

class _IapStatusWidgetState extends ConsumerState<IapStatusWidget> {
  bool _busy = false;

  Future<void> _buy() async {
    setState(() => _busy = true);
    try {
      final started = await IapService.buyRemoveAds();
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription is not available yet. Try again soon.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      await IapService.restore();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final removed = AdService.adsRemoved;
    if (widget.hideWhenRemoved && removed) {
      return const SizedBox.shrink();
    }

    if (removed) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.good.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.good.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppTheme.good, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ads removed',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: p.textHi)),
                  Text('Thanks for supporting the app!',
                      style: TextStyle(
                          fontSize: 11,
                          color: p.textMid,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(AppTheme.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block_rounded, color: Colors.black, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Remove ads monthly',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.black)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('\$1.99/mo',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
              'Monthly subscription. No banner ads or interstitials while active.',
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _busy ? null : _buy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Subscribe',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _restore,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black54),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Restore',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
