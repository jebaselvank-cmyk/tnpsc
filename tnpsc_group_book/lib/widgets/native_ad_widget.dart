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

class _NativeAdWidgetState extends State<NativeAdWidget> with WidgetsBindingObserver {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  Timer? _refreshTimer;
  bool _isPaused = false;

  final String adUnitId = 'ca-app-pub-9952621231526514/5355753081';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!HiveService.isAdFree()) {
      // Add a small delay before loading to ensure it's not a fast scroll-by
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && !_isPaused) {
          _loadAd();
          if (widget.refreshIntervalSeconds != null) {
            _startRefreshTimer();
          }
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _isPaused = true;
      _refreshTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _isPaused = false;
      if (widget.refreshIntervalSeconds != null) {
        _startRefreshTimer();
      }
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: widget.refreshIntervalSeconds!), (timer) {
      if (!_isPaused && mounted) {
        AppLog.d('AI_DEBUG: Refreshing Native Ad...');
        _loadAd();
      }
    });
  }

  void _loadAd() {
    if (_isPaused || !mounted) return;

    NativeAd createAdInstance() {
      return NativeAd(
        adUnitId: adUnitId,
        factoryId: widget.isSmall ? 'listTileSmall' : 'listTileMedium',
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (mounted) {
              setState(() {
                if (_nativeAd != null && _nativeAd != ad) {
                  _nativeAd!.dispose();
                }
                _nativeAd = ad as NativeAd;
                _isAdLoaded = true;
              });
            }
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (_nativeAd == null && mounted) {
              setState(() {
                _isAdLoaded = false;
              });
            }
          },
          // Triggered when an ad is clicked
          onAdClicked: (ad) => AppLog.d('Ad Clicked'),
          // Triggered when an ad impression is recorded
          onAdImpression: (ad) => AppLog.d('Ad Impression recorded'),
        ),
      );
    }

    final nextAd = createAdInstance();
    nextAd.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
