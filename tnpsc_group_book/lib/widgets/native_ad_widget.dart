import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/hive_service.dart';
import '../utils/app_log.dart';

class NativeAdWidget extends StatefulWidget {
  final bool isSmall;

  const NativeAdWidget({super.key, this.isSmall = true});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  final String adUnitId = 'ca-app-pub-9952621231526514/5355753081';

  @override
  void initState() {
    super.initState();
    if (!HiveService.isAdFree()) {
      _loadAd();
    }
  }

  void _loadAd() {
    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'listTile', // Use the factory ID configured in AndroidManifest/MainActivity
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          AppLog.d('AI_DEBUG: Native Ad loaded.');
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          AppLog.e('AI_DEBUG: Native Ad failed to load: $error');
          ad.dispose();
          _nativeAd = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
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
