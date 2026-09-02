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
  bool _isPaused = false;
  Timer? _nextRequestTimer;

  final String adUnitId = 'ca-app-pub-9952621231526514/5355753081';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!HiveService.isAdFree()) {
      // Load the first ad with a small initial delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && !_isPaused) {
          _loadAd();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _isPaused = true;
      _nextRequestTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _isPaused = false;
    }
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
            // Optional: Retry after failure
            _scheduleNextLoad(30); 
          },
          onAdImpression: (ad) {
            AppLog.d('AI_DEBUG: Ad Impression recorded. Scheduling next refresh...');
            // Only when the user SEES the ad, we schedule the next one
            if (widget.refreshIntervalSeconds != null) {
              _scheduleNextLoad(widget.refreshIntervalSeconds!);
            }
          },
        ),
      );
    }

    final nextAd = createAdInstance();
    nextAd.load();
  }

  void _scheduleNextLoad(int seconds) {
    _nextRequestTimer?.cancel();
    _nextRequestTimer = Timer(Duration(seconds: seconds), () {
      if (!_isPaused && mounted) {
        _loadAd();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nextRequestTimer?.cancel();
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
