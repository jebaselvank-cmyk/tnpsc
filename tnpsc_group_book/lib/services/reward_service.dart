import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'hive_service.dart';
import 'firestore_service.dart';
import '../utils/app_log.dart';

class RewardService {
  static RewardedAd? _rewardedAd;
  static bool _isRewardedLoaded = false;
  static bool _isRewardedLoading = false;
  static int _rewardedRetryDelay = 60;

  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialLoaded = false;
  static bool _isInterstitialLoading = false;
  static int _interstitialRetryDelay = 60;

  static const String testRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String realRewardedId = 'ca-app-pub-9952621231526514/2142313722';

  static const String testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String realInterstitialId = 'ca-app-pub-9952621231526514/2643599886'; 

  static bool useTestAds = false;

  static String get rewardedAdUnitId => useTestAds ? testRewardedId : realRewardedId;
  static String get interstitialAdUnitId => useTestAds ? testInterstitialId : realInterstitialId;

  static Future<void> handleConsentAndInit() async {
    if (HiveService.isAdFree()) return;
    
    final Completer<void> completer = Completer<void>();
    AppLog.d('AI_DEBUG: [UMP] Requesting consent information update...');
    
    final params = ConsentRequestParameters();

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          ConsentForm.loadAndShowConsentFormIfRequired(
            (FormError? formError) async {
              if (await ConsentInformation.instance.canRequestAds()) {
                _initializeMobileAds();
              }
              if (!completer.isCompleted) completer.complete();
            },
          );
        },
        (FormError error) {
          _initializeMobileAds();
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (e) {
      _initializeMobileAds();
      if (!completer.isCompleted) completer.complete();
    }
    
    return completer.future;
  }

  static void _initializeMobileAds() async {
    try {
      await MobileAds.instance.initialize();
      loadRewardedAd();
      loadInterstitialAd();
    } catch (e) {
      AppLog.e('AI_DEBUG: MobileAds initialization failed: $e');
    }
  }

  static void loadRewardedAd() {
    if (HiveService.isAdFree()) return;
    if (_isRewardedLoaded || _isRewardedLoading) return;

    _isRewardedLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoaded = true;
          _isRewardedLoading = false;
          _rewardedRetryDelay = 60;
          AppLog.d('AI_DEBUG: Rewarded Ad Loaded');
        },
        onAdFailedToLoad: (err) {
          _isRewardedLoaded = false;
          _isRewardedLoading = false;
          AppLog.d('AI_DEBUG: Rewarded Ad failed to load: $err. Retrying in $_rewardedRetryDelay s');
          Future.delayed(Duration(seconds: _rewardedRetryDelay), () => loadRewardedAd());
          _rewardedRetryDelay = (_rewardedRetryDelay * 2).clamp(60, 300);
        },
      ),
    );
  }

  static void loadInterstitialAd() {
    if (HiveService.isAdFree()) return;
    if (_isInterstitialLoaded || _isInterstitialLoading) return;

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoaded = true;
          _isInterstitialLoading = false;
          _interstitialRetryDelay = 60;
          AppLog.d('AI_DEBUG: Interstitial Ad Loaded');
        },
        onAdFailedToLoad: (err) {
          _isInterstitialLoaded = false;
          _isInterstitialLoading = false;
          AppLog.d('AI_DEBUG: Interstitial Ad failed to load: $err. Retrying in $_interstitialRetryDelay s');
          Future.delayed(Duration(seconds: _interstitialRetryDelay), () => loadInterstitialAd());
          _interstitialRetryDelay = (_interstitialRetryDelay * 2).clamp(60, 300);
        },
      ),
    );
  }

  static Future<void> addPoints(int points, {bool syncToCloud = false}) async {
    if (points <= 0) return;
    await HiveService.addPoints(points);
    if (syncToCloud) {
      final fs = FirestoreService();
      await fs.incrementUserPoints(points);
    }
  }

  static Future<void> deductPoints(int points) async {
    try {
      if (points <= 0) return;
      final fs = FirestoreService();
      await fs.incrementUserPoints(-points);
      AppLog.d('AI_DEBUG: Deducted $points points');
    } catch (e) {
      AppLog.d('AI_DEBUG: Failed to deduct points: $e');
    }
  }

  static Future<void> showRewardAdIfAllowed({
    required VoidCallback onRewardEarned, 
    int? fixedRewardAmount, 
    bool useLimit = false
  }) async {
    if (useLimit && !HiveService.canWatchRewardAdToday()) {
      onRewardEarned(); 
      return;
    }
    
    int rewardAmount = fixedRewardAmount ?? 0;
    if (fixedRewardAmount == null) {
      int watchCount = HiveService.getQuizAdWatchCountToday();
      if (watchCount == 0) rewardAmount = 15;
      else if (watchCount == 1) rewardAmount = 10;
      else if (watchCount == 2) rewardAmount = 5;
    }

    if (HiveService.isAdFree()) {
      await addPoints(rewardAmount, syncToCloud: true);
      if (useLimit) await HiveService.incrementRewardAdWatchCountToday();
      if (fixedRewardAmount == null) await HiveService.incrementQuizAdWatchCountToday();
      onRewardEarned();
      return;
    }

    final success = await showRewardAd(onRewardEarned: () {});
    if (success) {
      await addPoints(rewardAmount, syncToCloud: true);
      if (useLimit) await HiveService.incrementRewardAdWatchCountToday();
      if (fixedRewardAmount == null) await HiveService.incrementQuizAdWatchCountToday();
      onRewardEarned();
    } else {
      onRewardEarned(); // Proceed anyway to not block user flow
    }
  }

  static Future<bool> showRewardAd({VoidCallback? onRewardEarned}) async {
    if (HiveService.isAdFree()) {
      if (onRewardEarned != null) onRewardEarned();
      return true;
    }

    if (_isRewardedLoaded && _rewardedAd != null) {
      final Completer<bool> completer = Completer<bool>();
      
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          _isRewardedLoaded = false;
          loadRewardedAd();
          if (!completer.isCompleted) completer.complete(true);
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _rewardedAd = null;
          _isRewardedLoaded = false;
          loadRewardedAd();
          if (!completer.isCompleted) completer.complete(false);
        },
      );
      
      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        AppLog.d('AI_DEBUG: Reward earned');
        if (onRewardEarned != null) onRewardEarned();
      });
      
      return completer.future;
    } else {
      loadRewardedAd();
      if (onRewardEarned != null) onRewardEarned();
      return false; // Immediate failure, don't wait
    }
  }

  static Future<void> showInterstitialAd({required VoidCallback onDismissed}) async {
    if (HiveService.isAdFree()) {
      onDismissed();
      return;
    }

    if (_isInterstitialLoaded && _interstitialAd != null) {
      final Completer<void> completer = Completer<void>();
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialLoaded = false;
          loadInterstitialAd();
          onDismissed();
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialLoaded = false;
          loadInterstitialAd();
          onDismissed();
          if (!completer.isCompleted) completer.complete();
        },
      );
      _interstitialAd!.show();
      return completer.future;
    } else {
      loadInterstitialAd();
      onDismissed();
    }
  }

  static Future<void> watchTwoAdsAndAwardPoints() async {
    await showRewardAdIfAllowed(onRewardEarned: () {});
    await showRewardAdIfAllowed(onRewardEarned: () {});
  }
}
