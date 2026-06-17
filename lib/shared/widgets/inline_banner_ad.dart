// lib/shared/widgets/inline_banner_ad.dart
//
// Self-loading inline ad widget.
// Default size: AdSize.mediumRectangle (300×250) — the "square" ad shown
// between match groups in lists.  Pass a custom size for other placements.

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/services/ad_service.dart';

class InlineBannerAd extends StatefulWidget {
  final AdSize size;
  final double verticalMargin;

  const InlineBannerAd({
    super.key,
    this.size = AdSize.mediumRectangle,
    this.verticalMargin = 8,
  });

  @override
  State<InlineBannerAd> createState() => _InlineBannerAdState();
}

class _InlineBannerAdState extends State<InlineBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!AdService.adsRemoved) {
      _ad = BannerAd(
        adUnitId: AdService.bannerId,
        size: widget.size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, _) => ad.dispose(),
        ),
      )..load();
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark;
    if (AdService.adsRemoved || _ad == null || !_loaded) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: EdgeInsets.symmetric(vertical: widget.verticalMargin),
      color: p ? const Color(0xFF0D1208) : const Color(0xFFF0F5F0),
      alignment: Alignment.center,
      height: _ad!.size.height.toDouble(),
      child: SizedBox(
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
