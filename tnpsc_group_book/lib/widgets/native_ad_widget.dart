import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/hive_service.dart';
import '../utils/app_log.dart';

class NativeAdWidget extends StatefulWidget {
  final bool isSmall;
  final int? refreshIntervalSeconds;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final Decoration? decoration;

  const NativeAdWidget({
    super.key,
    this.isSmall = true,
    this.refreshIntervalSeconds,
    this.width,
    this.height,
    this.margin,
    this.decoration,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> with WidgetsBindingObserver {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  bool _isPaused = false;
  bool _hasBeenVisible = false;
  Timer? _nextRequestTimer;
  int _retryDelaySeconds = 60;

  final String adUnitId = 'ca-app-pub-9952621231526514/5355753081';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _isPaused = true;
      _nextRequestTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _isPaused = false;
      if (_hasBeenVisible && _nativeAd == null && !_isLoading && mounted) {
        _loadAd();
      }
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (HiveService.isAdFree()) return;
    if (_isPaused || !mounted) return;

    // Load only when the ad is actually near the visible area (e.g., 5% visible)
    if (info.visibleFraction > 0.05 && !_hasBeenVisible) {
      _hasBeenVisible = true;
      _loadAd();
    }
  }

  void _loadAd() {
    if (!mounted || _isPaused || _isLoading || _nativeAd != null || HiveService.isAdFree()) {
      return;
    }

    _isLoading = true;

    final ad = NativeAd(
      adUnitId: adUnitId,
      factoryId: widget.isSmall ? 'listTileSmall' : 'listTileMedium',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          _retryDelaySeconds = 60; // Reset retry delay on success
          setState(() {
            _nativeAd = ad as NativeAd;
            _isAdLoaded = true;
            _isLoading = false;
          });
          AppLog.d('NativeAd loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isLoading = false;
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
            });
          }
          AppLog.d('NativeAd failed: ${error.code} - ${error.message}');
          // Exponential backoff retry
          _scheduleRetry();
        },
        onAdImpression: (ad) {
          AppLog.d('NativeAd impression recorded');
          if (widget.refreshIntervalSeconds != null) {
            _scheduleNextLoad(widget.refreshIntervalSeconds!);
          }
        },
        onAdClicked: (ad) {
          AppLog.d('NativeAd clicked');
        },
      ),
    );

    ad.load();
  }

  void _scheduleRetry() {
    _nextRequestTimer?.cancel();
    _nextRequestTimer = Timer(Duration(seconds: _retryDelaySeconds), () {
      if (!mounted || _isPaused || !_hasBeenVisible || _nativeAd != null) return;
      _loadAd();
    });
    // Double the delay up to a max of 5 minutes
    _retryDelaySeconds = (_retryDelaySeconds * 2).clamp(60, 300);
  }

  void _scheduleNextLoad(int seconds) {
    _nextRequestTimer?.cancel();
    _nextRequestTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted || _isPaused) return;
      
      _nativeAd?.dispose();
      setState(() {
        _nativeAd = null;
        _isAdLoaded = false;
        _isLoading = false;
      });
      _loadAd();
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

    return VisibilityDetector(
      key: Key('native_ad_${widget.key ?? hashCode}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: _isAdLoaded && _nativeAd != null
          ? Container(
              margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 10),
              width: widget.width,
              height: widget.height ?? (widget.isSmall ? 80 : 300),
              decoration: widget.decoration,
              alignment: Alignment.center,
              child: AdWidget(ad: _nativeAd!),
            )
          : const SizedBox.shrink(),
    );
  }
}
