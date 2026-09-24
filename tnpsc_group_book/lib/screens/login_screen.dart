import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_service.dart';
import '../services/hive_service.dart';
import '../utils/app_log.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../main.dart'; // To navigate to MainWrapper
import '../widgets/app_logo.dart';
import '../services/notification_service.dart';
import '../services/google_auth_service.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isGoogleLoading = false;
  bool _isGuestLoading = false;
  bool _isOtpLoading = false;
  bool _isVerifyLoading = false;
  bool get _anyLoading => _isGoogleLoading || _isGuestLoading || _isOtpLoading || _isVerifyLoading;
  bool _isExiting = false;

  // Email/OTP Form State
  bool _showEmailForm = false;
  bool _showOtpForm = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String _generatedOtp = '';
  DateTime? _otpGeneratedTime;
  int _timerSeconds = 30;
  bool _canResend = false;
  bool _isResending = false;
  dynamic _timer;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    final ta = AppLanguage.languageNotifier.value == 'ta';
    AppLog.d("LOGIN SCREEN OPENED");
    AppLog.d("Current User = ${FirebaseAuth.instance.currentUser?.uid}");
    try {
      final userCredential = await GoogleAuthService.signInWithGoogle();
      if (userCredential != null && userCredential.user != null) {
        await _initializeUserInFirestore(userCredential.user);
        _navigateToHome();
      } else {
        setState(() => _isGoogleLoading = false);
        // User canceled sign-in
      }
    } catch (e) {
      setState(() => _isGoogleLoading = false);
      _showError(ta ? 'Google உள்நுழைவு தோல்வியடைந்தது.' : 'Google Sign-In failed.');
    }
  }

  Future<void> _handleGuestLogin() async {
    setState(() => _isGuestLoading = true);
    final ta = AppLanguage.languageNotifier.value == 'ta';
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      if (userCredential.user != null) {
        await _initializeGuestUserInFirestore(userCredential.user);
        _navigateToHome();
      } else {
        setState(() => _isGuestLoading = false);
      }
    } catch (e) {
      setState(() => _isGuestLoading = false);
      AppLog.e("Guest login error: $e");
      _showError(ta ? 'விருந்தினர் உள்நுழைவு தோல்வியடைந்தது.' : 'Guest login failed.');
    }
  }

  void _startOtpTimer() {
    _timer?.cancel();
    setState(() {
      _timerSeconds = 30;
      _canResend = false;
    });
    _timer = Stream.periodic(const Duration(seconds: 1), (i) => 29 - i).take(30).listen((seconds) {
      if (mounted) {
        setState(() => _timerSeconds = seconds);
        if (seconds == 0) setState(() => _canResend = true);
      }
    });
  }

  Future<void> _initializeGuestUserInFirestore(User? user) async {
    if (user == null) return;
    await HiveService.clearUserSession();
    
    final guestId = (100000000 + Random().nextInt(900000000)).toString(); // 9 digits
    final guestName = 'guest_$guestId';

    try {
      await user.updateDisplayName(guestName);
    } catch (_) {}

    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      await userDoc.set({
        'name': guestName,
        'email': '', // No email for guest
        'isGuest': true,
        'streak': 1,
        'points': 0,
        'totalScore': 0,
        'lastActive': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await userDoc.update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    }

    // Cache user data in Hive immediately
    await HiveService.cacheUserData({
      'name': guestName,
      'email': '',
      'isGuest': true,
      'streak': 1,
      'points': 0,
      'totalScore': 0,
    });

    // Force refresh user data from Firestore to populate Hive on fresh install
    final fs = FirestoreService();
    await fs.getUserData(forceRefresh: true);
    await NotificationService.saveFCMToken();
  }

  Future<void> _handleEmailLogin() async {
    setState(() {
      _showEmailForm = !_showEmailForm;
      if (!_showEmailForm) {
        _showOtpForm = false;
        _timer?.cancel();
        _emailController.clear();
        _otpController.clear();
      }
    });
  }

  Future<void> _sendOtp() async {
    final ta = AppLanguage.languageNotifier.value == 'ta';
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError(ta ? 'மின்னஞ்சலை உள்ளிடவும்' : 'Please enter your email');
      return;
    }
    if (!email.contains('@')) {
      _showError(ta ? 'சரியான மின்னஞ்சலை உள்ளிடவும்' : 'Please enter a valid email');
      return;
    }

    setState(() => _isOtpLoading = true);
    try {
      final generatedOtp = await AuthService.sendOtpForLogin(email);
      setState(() {
        _generatedOtp = generatedOtp;
        _otpGeneratedTime = DateTime.now();
        _showOtpForm = true;
        _isOtpLoading = false;
      });
      _startOtpTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ta ? 'OTP அனுப்பப்பட்டது (3 நிமிடங்கள் செல்லுபடியாகும்)' : 'OTP sent successfully (Valid for 3 mins)')),
      );
    } catch (e) {
      setState(() => _isOtpLoading = false);
      _showError(AuthService.messageFromException(e, ta: ta));
    }
  }

  Future<void> _resendOtp() async {
    final ta = AppLanguage.languageNotifier.value == 'ta';
    final email = _emailController.text.trim();
    setState(() => _isResending = true);
    try {
      final newOtp = await AuthService.sendOtpForLogin(email);
      if (mounted) {
        setState(() {
          _generatedOtp = newOtp;
          _otpGeneratedTime = DateTime.now();
          _isResending = false;
        });
        _startOtpTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ta ? 'OTP மீண்டும் அனுப்பப்பட்டது (3 நிமிடங்கள் செல்லுபடியாகும்)' : 'OTP Resent successfully (Valid for 3 mins)')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResending = false);
        _showError(AuthService.messageFromException(e, ta: ta));
      }
    }
  }

  Future<void> _verifyAndLogin() async {
    final ta = AppLanguage.languageNotifier.value == 'ta';
    final email = _emailController.text.trim();
    final enteredOtp = _otpController.text.trim();

    if (enteredOtp.isEmpty) {
      _showError(ta ? 'OTP-ஐ உள்ளிடவும்' : 'Please enter the OTP');
      return;
    }

    // Check OTP Expiry (3 minutes = 180 seconds)
    if (_otpGeneratedTime != null &&
        DateTime.now().difference(_otpGeneratedTime!).inSeconds > 180) {
      _showError(ta ? 'OTP காலாவதியாகிவிட்டது! மீண்டும் புதிய OTP பெறவும்.' : 'OTP has expired! Please get a new OTP.');
      return;
    }

    setState(() => _isVerifyLoading = true);
    try {
      final userCredential = await AuthService.verifyOtpAndLogin(
        email: email,
        otp: _generatedOtp,
        enteredOtp: enteredOtp,
      );
      
      if (userCredential.user != null) {
        await _initializeUserInFirestore(userCredential.user);
        _navigateToHome();
      } else {
        setState(() => _isVerifyLoading = false);
      }
    } catch (e) {
      setState(() => _isVerifyLoading = false);
      _showError(AuthService.messageFromException(e, ta: ta));

    }
  }

  Future<void> _initializeUserInFirestore(User? user) async {
    if (user == null) return;
    await HiveService.clearUserSession();
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      final name = user.displayName ?? AppLanguage.getString('user_fallback');
          
      await userDoc.set({
        'name': name,
        'email': user.email,
        'photoURL': user.photoURL,
        'streak': 1,
        'points': 0,
        'totalScore': 0,
        'lastActive': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await userDoc.update({
        'lastActive': FieldValue.serverTimestamp(),
        'photoURL': user.photoURL,
      });
    }

    // Force refresh user data from Firestore to populate Hive on fresh install
    final fs = FirestoreService();
    await fs.getUserData(forceRefresh: true);

    // AI_DEBUG: Admin pool refresh logic for Share quizzes (Weekly Once)
    if ((user.email == 'adminjeba@gmail.com' || 
        user.email == 'kjebaselvan987@gmail.com' || 
        user.phoneNumber == '+918754236411') && HiveService.shouldRefreshSharePool()) {
       AppLog.d("AI_DEBUG: Admin Logged in. Refreshing Share Quiz Pool...");
       try {
         final pool = await fs.fetchLargeShareQuizPool(200);
         if (pool.isNotEmpty) {
           await HiveService.saveShareQuizPool(pool);
         }
       } catch (e) {
         AppLog.e("Error refreshing admin share pool", e);
       }
    }

    await NotificationService.saveFCMToken();
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainWrapper()),
    );
  }

  Future<void> _showExitDialog(BuildContext context) async {
    if (_isExiting) return;
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF101F42) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLanguage.getString('exit_app_title'),
          style: AppTheme.getStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          AppLanguage.getString('exit_app_desc'),
          style: AppTheme.getStyle(
            fontSize: 16,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLanguage.getString('no'),
              style: AppTheme.getStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppLanguage.getString('yes')),
          ),
        ],
      ),
    );

    if (shouldPop ?? false) {
      _isExiting = true;
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final ta = lang == 'ta';

        return PopScope(
          canPop: _isExiting,
          onPopInvokedWithResult: (didPop, result) {
            AppLog.d("AI_DEBUG: [LoginScreen] PopScope triggered. didPop: $didPop");
            if (didPop) return;
            _showExitDialog(context);
          },
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const AppLogo(size: 100, showShadow: false),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      AppLanguage.getString('welcome_title'),
                      style: AppTheme.getStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textMainColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ta ? 'உள்நுழைந்து உங்களின் TNPSC தயாரிப்பைத் தொடரவும்.' : 'Login to continue your TNPSC preparation.',
                      style: AppTheme.getStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Email Login Button
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: OutlinedButton.icon(
                            onPressed: _anyLoading ? null : _handleEmailLogin,
                            icon: Icon(
                              _showEmailForm ? Icons.keyboard_arrow_up : Icons.email_outlined,
                              color: Colors.blue,
                            ),
                            label: Text(
                              ta ? 'மின்னஞ்சல் மூலம் தொடரவும்' : 'Continue with Email',
                              style: AppTheme.getStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: isDark ? Colors.white30 : Colors.black12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        if (_showEmailForm) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF020D1E) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ta ? 'மின்னஞ்சல் முகவரி' : 'Email Address',
                                  style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  enabled: !_showOtpForm && !_anyLoading,
                                  style: AppTheme.getStyle(fontSize: 16),
                                  decoration: InputDecoration(
                                    hintText: 'example@gmail.com',
                                    hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black38),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                                if (!_showOtpForm) ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _anyLoading ? null : _sendOtp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: _isOtpLoading
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : Text(ta ? 'OTP பெறுக' : 'Get OTP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                                if (_showOtpForm) ...[
                                  const SizedBox(height: 20),
                                  Text(
                                    ta ? 'OTP குறியீடு' : 'Enter OTP',
                                    style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _otpController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    enabled: !_anyLoading,
                                    style: AppTheme.getStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      counterText: "",
                                      hintText: '• • • • • •',
                                      hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black38),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.center,
                                    child: !_canResend
                                        ? Text(
                                      ta ? 'மீண்டும் அனுப்ப: $_timerSeconds விநாடிகள்' : 'Resend in: $_timerSeconds sec',
                                      style: AppTheme.getStyle(fontSize: 12, color: Colors.grey),
                                    )
                                        : TextButton(
                                      onPressed: _isResending ? null : _resendOtp,
                                      child: _isResending
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                          : Text(ta ? 'OTP-ஐ மீண்டும் அனுப்பு' : 'Resend OTP'),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _anyLoading ? null : _verifyAndLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: _isVerifyLoading
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : Text(ta ? 'சரிபார் & உள்நுழை' : 'Verify & Login', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Google Sign-In Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        onPressed: _anyLoading ? null : _handleGoogleSignIn,
                        icon: _isGoogleLoading 
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2)
                            )
                          : ValueListenableBuilder<double>(
                              valueListenable: AppTheme.fontSizeFactorNotifier,
                              builder: (context, factor, child) {
                                return Image.network(
                                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_\"G\"_logo.svg/1200px-Google_\"G\"_logo.svg.png',
                                  height: 24 * factor,
                                  width: 24 * factor,
                                  errorBuilder: (context, error, stackTrace) => Icon(Icons.login, color: Colors.red, size: 24 * factor),
                                );
                              },
                            ),
                        label: Text(
                          ta ? 'Google மூலம் தொடரவும்' : 'Continue with Google',
                          style: AppTheme.getStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? Colors.white30 : Colors.black12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Guest Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        onPressed: _anyLoading ? null : _handleGuestLogin,
                        icon: _isGuestLoading 
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2)
                            )
                          : Icon(
                              Icons.person_outline,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                        label: Text(
                          ta ? 'விருந்தினராக தொடரவும் (Guest)' : 'Continue as Guest',
                          style: AppTheme.getStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? Colors.white30 : Colors.black12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),
        ));
      },
    );
  }
}

class OtpVerificationDialog extends StatefulWidget {
  final String email;
  final String initialOtp;

  const OtpVerificationDialog({super.key, required this.email, required this.initialOtp});

  @override
  State<OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends State<OtpVerificationDialog> {
  late String currentGeneratedOtp;
  String enteredOtp = '';
  int _timerSeconds = 30;
  bool _canResend = false;
  bool _isResending = false;
  late var _timer;

  @override
  void initState() {
    super.initState();
    currentGeneratedOtp = widget.initialOtp;
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _timerSeconds = 30;
      _canResend = false;
    });
    _timer = Stream.periodic(const Duration(seconds: 1), (i) => 29 - i).take(30).listen((seconds) {
      if (mounted) {
        setState(() => _timerSeconds = seconds);
        if (seconds == 0) setState(() => _canResend = true);
      }
    });
  }

  Future<void> _handleResend() async {
    final ta = AppLanguage.languageNotifier.value == 'ta';
    setState(() => _isResending = true);
    try {
      final newOtp = await AuthService.sendOtpForLogin(widget.email);
      if (mounted) {
        setState(() {
          currentGeneratedOtp = newOtp;
          _isResending = false;
        });
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ta ? 'OTP மீண்டும் அனுப்பப்பட்டது' : 'OTP Resent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthService.messageFromException(e, ta: ta)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ta = AppLanguage.languageNotifier.value == 'ta';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF000307) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        ta ? 'OTP சரிபார்ப்பு' : 'OTP Verification',
        style: AppTheme.getStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ta 
              ? '${widget.email}-க்கு அனுப்பப்பட்ட 6 இலக்க OTP-ஐ உள்ளிடவும்.' 
              : 'Enter the 6-digit OTP sent to ${widget.email}.',
            style: AppTheme.getStyle(fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextField(
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            style: AppTheme.getStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: "",
              hintText: '• • • • • •',
              hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (value) => enteredOtp = value,
          ),
          const SizedBox(height: 16),
          if (!_canResend)
            Text(
              ta ? 'மீண்டும் அனுப்ப: $_timerSeconds விநாடிகள்' : 'Resend in: $_timerSeconds sec',
              style: AppTheme.getStyle(fontSize: 12, color: Colors.grey),
            )
          else
            TextButton(
              onPressed: _isResending ? null : _handleResend,
              child: _isResending 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(ta ? 'OTP-ஐ மீண்டும் அனுப்பு' : 'Resend OTP'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(ta ? 'ரத்து' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, enteredOtp),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(ta ? 'சரிபார்' : 'Verify', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
