import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_log.dart';
import 'hive_service.dart';

class IapService {
  static final IapService _instance = IapService._internal();
  factory IapService() => _instance;
  IapService._internal();

  static const String productIdMonthly49 = 'tnpsc_monthly_49';
  static final Set<String> _kProductIds = {productIdMonthly49};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _isLoading = false;

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  bool get isLoading => _isLoading;

  /// ValueNotifier for UI reactive updates when PRO status changes
  static final ValueNotifier<bool> isProNotifier = ValueNotifier<bool>(false);

  /// Initializes IAP service, fetches product details, and listens to purchase stream
  Future<void> init() async {
    isProNotifier.value = checkIsProUser();

    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      AppLog.d("IAP_DEBUG: InAppPurchase is not available on this device.");
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        AppLog.e("IAP_DEBUG: Purchase stream error: $error");
      },
    );

    await fetchProducts();
  }

  /// Fetches product details from Google Play Console / App Store
  Future<void> fetchProducts() async {
    if (!_isAvailable) return;
    _isLoading = true;

    try {
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(_kProductIds);

      if (response.error != null) {
        AppLog.e("IAP_DEBUG: Error querying products: ${response.error}");
      }

      _products = response.productDetails;
      AppLog.d("IAP_DEBUG: Fetched ${_products.length} products from Play Store.");
      for (var p in _products) {
        AppLog.d("IAP_DEBUG: Product: ${p.id} | Price: ${p.price}");
      }
    } catch (e) {
      AppLog.e("IAP_DEBUG: Exception fetching products: $e");
    } finally {
      _isLoading = false;
    }
  }

  /// Gets the formatted price string (e.g., "₹49.00")
  String getMonthlyPrice() {
    for (var p in _products) {
      if (p.id == productIdMonthly49) {
        return p.price;
      }
    }
    return "₹49 / மாதம்";
  }

  /// Triggers buying the ₹49 monthly subscription
  Future<bool> buyMonthlySubscription() async {
    if (!_isAvailable) return false;

    ProductDetails? product;
    for (var p in _products) {
      if (p.id == productIdMonthly49) {
        product = p;
        break;
      }
    }

    if (product == null) {
      AppLog.d("IAP_DEBUG: Product $productIdMonthly49 not found in fetched list. Querying again...");
      await fetchProducts();
      for (var p in _products) {
        if (p.id == productIdMonthly49) {
          product = p;
          break;
        }
      }
    }

    if (product == null) {
      AppLog.e("IAP_DEBUG: Unable to find product $productIdMonthly49");
      return false;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    try {
      // Subscriptions use buyNonConsumable in Flutter in_app_purchase
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      AppLog.e("IAP_DEBUG: Error initiating purchase: $e");
      return false;
    }
  }

  /// Restores previous purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      AppLog.e("IAP_DEBUG: Error restoring purchases: $e");
    }
  }

  /// Handles incoming purchase updates from Google Play / App Store
  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        AppLog.d("IAP_DEBUG: Purchase pending for ${purchaseDetails.productID}");
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        AppLog.e("IAP_DEBUG: Purchase error: ${purchaseDetails.error}");
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        bool valid = await _verifyAndGrantSubscription(purchaseDetails);
        if (valid) {
          AppLog.d("IAP_DEBUG: Purchase verified and activated: ${purchaseDetails.productID}");
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// Verifies purchase and grants PRO status in Hive & Firestore
  Future<bool> _verifyAndGrantSubscription(PurchaseDetails purchaseDetails) async {
    try {
      // Set local Hive PRO flag
      var box = Hive.box(HiveService.userBoxName);
      await box.put('is_pro_user', true);
      
      // Calculate 30 days expiry date
      DateTime now = DateTime.now();
      DateTime expiry = now.add(const Duration(days: 30));
      await box.put('pro_expiry_date', expiry.toIso8601String());

      isProNotifier.value = true;

      // Sync to Firestore if user is signed in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'isPro': true,
          'proPlan': 'monthly_49',
          'proPurchasedAt': FieldValue.serverTimestamp(),
          'proExpiryDate': Timestamp.fromDate(expiry),
          'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
        }, SetOptions(merge: true));
      }

      AppLog.d("IAP_DEBUG: User successfully upgraded to PRO ₹49 monthly!");
      return true;
    } catch (e) {
      AppLog.e("IAP_DEBUG: Error granting subscription: $e");
      return false;
    }
  }

  /// Checks if current user is active PRO member
  static bool checkIsProUser() {
    try {
      var box = Hive.box(HiveService.userBoxName);
      bool isPro = box.get('is_pro_user', defaultValue: false) as bool;
      if (!isPro) return false;

      String? expiryStr = box.get('pro_expiry_date') as String?;
      if (expiryStr != null) {
        DateTime expiry = DateTime.parse(expiryStr);
        if (DateTime.now().isAfter(expiry)) {
          // Expired
          box.put('is_pro_user', false);
          isProNotifier.value = false;
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
