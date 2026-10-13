import 'package:flutter/material.dart';
import '../services/iap_service.dart';
import '../utils/app_theme.dart';

class PremiumSubscriptionScreen extends StatefulWidget {
  const PremiumSubscriptionScreen({super.key});

  @override
  State<PremiumSubscriptionScreen> createState() => _PremiumSubscriptionScreenState();
}

class _PremiumSubscriptionScreenState extends State<PremiumSubscriptionScreen> {
  final IapService _iapService = IapService();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initIap();
  }

  Future<void> _initIap() async {
    setState(() => _isProcessing = true);
    await _iapService.init();
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleBuy() async {
    setState(() => _isProcessing = true);
    bool initiated = await _iapService.buyMonthlySubscription();
    if (!initiated && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Unable to open Google Play Billing. Please try again or check Google Play Store connection."),
      ));
    }
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isProcessing = true);
    await _iapService.restorePurchases();
    if (mounted) {
      setState(() => _isProcessing = false);
      bool isPro = IapService.checkIsProUser();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isPro ? "✨ PRO Subscription restored successfully!" : "No active subscription found to restore."),
        backgroundColor: isPro ? Colors.green : Colors.orange,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isPro = IapService.checkIsProUser();
    String priceText = _iapService.getMonthlyPrice();

    return Scaffold(
      appBar: AppBar(
        title: const Text("TNPSC Master PRO"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade700, Colors.deepOrange.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 54, color: Colors.white),
                    const SizedBox(height: 10),
                    const Text(
                      "TNPSC Master PRO",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "பிரீமியம் சந்தா சேர்க்கை",
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Pro Features List
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "PRO உறுப்பினர்களின் சிறப்பு நன்மைகள்:",
                  style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 14),

              _buildFeatureTile(
                icon: Icons.block_rounded,
                iconColor: Colors.redAccent,
                title: "100% விளம்பரமில்லாத கற்றல் (No Ads)",
                subtitle: "எந்தவித விளம்பர இடையூறுகளுமின்றித் தடையின்றிப் படிக்கலாம்.",
              ),
              _buildFeatureTile(
                icon: Icons.auto_awesome,
                iconColor: Colors.purple,
                title: "தடையற்ற AI வினாக்கள் & பதில்கள்",
                subtitle: "AI Smart Prep, Quiz & Explanations அனைத்தையும் பயன்படுத்தலாம்.",
              ),
              _buildFeatureTile(
                icon: Icons.article_rounded,
                iconColor: Colors.indigo,
                title: "அனைத்து முந்தைய வினாத்தாள்கள் (PYQs)",
                subtitle: "2010 முதல் 2025 வரை உள்ள அசல் வினாத்தாள்கள் & விடைகள்.",
              ),
              _buildFeatureTile(
                icon: Icons.star_rounded,
                iconColor: Colors.amber,
                title: "PRO பேட்ஜ் & முன்னுரிமை உதவி",
                subtitle: "Leaderboard-ல் PRO Badge மற்றும் உடனடி உதவி மையம்.",
              ),

              const SizedBox(height: 24),

              // Pricing Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPro ? Colors.green : AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    if (isPro) ...[
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 24),
                          SizedBox(width: 8),
                          Text(
                            "நீங்கள் PRO உறுப்பினராக உள்ளீர்கள்!",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "உங்கள் 49 ரூபாய் பிரீமியம் சந்தா ஆக்டிவ் ஆக உள்ளது.",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            priceText,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "30 நாட்கள் முழு அணுகல் (Monthly Subscription)",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Buy / Restore Buttons
              if (!isPro)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _handleBuy,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.payment_rounded),
                    label: const Text(
                      "₹49 - இப்பொழுதே சந்தா சேர் (Subscribe)",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              TextButton.icon(
                onPressed: _isProcessing ? null : _handleRestore,
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text("ஏற்கனவே வாங்கியதை மீட்டெடு (Restore Purchases)"),
              ),

              const SizedBox(height: 16),

              const Text(
                "Google Play Store விதிமுறைகளின்படி, சந்தா தொகையை எப்போது வேண்டுமானாலும் ரத்து செய்ய முடியும்.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTheme.getStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// 📋 Google Play Console-இல் நீங்கள் செய்ய வேண்டிய 3 எளிய வழிகள்:
// 1.
// Google Play Console லாக் இன் செய்து உங்கள் App-ஐத் தேர்ந்தெடுக்கவும்.
// 2.
// Monetize ➔ Products ➔ Subscriptions பகுதிக்குச் செல்லவும்.
// 3.
// Create Subscription கிளிக் செய்து:
// ◦
// Product ID: tnpsc_monthly_49
// ◦
// Name: TNPSC Master PRO Monthly
// ◦
// Price: ₹49.00 INR (Monthly Billing) எனக் கொடுத்து Save செய்து Publish செய்யவும்.



//🛠️ Google Play Console-இல் நீங்கள் செய்ய வேண்டிய அமைப்புகள் (Quick Steps):
//1.
//Google Play Console லாக் இன் செய்யவும்.
//2.
//Setup ➔ Monetization setup பகுதிக்குச் சென்று "Create Merchant Account" கிளிக் செய்யவும்.
//3.
//உங்களது வங்கி கணக்கு எண் (Bank Account Number), IFSC Code மற்றும் PAN Card விவரங்களை உள்ளிடவும்.
//4.
//Monetize ➔ Subscriptions பகுதிக்குச் சென்று Product ID: tnpsc_monthly_49 என அமைத்து ₹49 விலையை நிர்ணயிக்கவும்.