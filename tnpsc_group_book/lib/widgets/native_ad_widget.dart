import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/hive_service.dart';
import '../utils/app_log.dart';

class NativeAdWidget extends StatefulWidget {
  final bool isSmall;
  final int? refreshIntervalSeconds;

  const NativeAdWidget({
    super.key,
    this.isSmall = true,
    this.refreshIntervalSeconds,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  Timer? _refreshTimer;

  final String adUnitId = 'ca-app-pub-9952621231526514/5355753081';

  @override
  void initState() {
    super.initState();
    if (!HiveService.isAdFree()) {
      _loadAd();
      if (widget.refreshIntervalSeconds != null) {
        _startRefreshTimer();
      }
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: widget.refreshIntervalSeconds!), (timer) {
      AppLog.d('AI_DEBUG: Refreshing Native Ad...');
      _loadAd();
    });
  }

  void _loadAd() {
    // Helper to create ad instance
    NativeAd createAdInstance() {
      return NativeAd(
        adUnitId: adUnitId,
        factoryId: widget.isSmall ? 'listTileSmall' : 'listTileMedium',
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            AppLog.d('AI_DEBUG: Native Ad loaded and ready to swap.');
            if (mounted) {
              setState(() {
                // IMPORTANT: Dispose the old ad ONLY after new one is ready
                if (_nativeAd != null && _nativeAd != ad) {
                  _nativeAd!.dispose();
                }
                _nativeAd = ad as NativeAd;
                _isAdLoaded = true;
              });
            }
          },
          onAdFailedToLoad: (ad, error) {
            AppLog.e('AI_DEBUG: Native Ad failed to load: $error');
            ad.dispose();
            // If we have no ad showing yet, update state. 
            // If we already have one showing, we keep it as is.
            if (_nativeAd == null && mounted) {
              setState(() {
                _isAdLoaded = false;
              });
            }
          },
        ),
      );
    }

    final nextAd = createAdInstance();
    nextAd.load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (HiveService.isAdFree()) return const SizedBox.shrink();

    if (_nativeAd != null && _isAdLoaded) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        height: widget.isSmall ? 80 : 300,
        alignment: Alignment.center,
        child: AdWidget(ad: _nativeAd!),
      );
    }

    return const SizedBox.shrink();
  }
}
