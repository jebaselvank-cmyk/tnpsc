import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../utils/app_log.dart';

import 'auth_local_api.dart';
import 'auth_status_service.dart';
import '../config/password_email_config.dart';
import 'password_email_service.dart';

/// Auth API: Cloud Functions first, Firestore fallback if functions not deployed.
class AuthService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static bool _useLocalFallback(FirebaseFunctionsException e) {
    final msg = (e.message ?? '').toUpperCase();
    if (msg == 'EMAIL_NOT_REGISTERED' ||
        msg == 'WRONG_CURRENT_PASSWORD' ||
        msg == 'INVALID_EMAIL' ||
        msg == 'WEAK_PASSWORD' ||
        msg == 'NOT_SIGNED_IN' ||
        msg == 'EMAIL_NOT_CONFIGURED') {
      return false;
    }
    return e.code == 'not-found' ||
        e.code == 'unavailable' ||
        e.code == 'deadline-exceeded' ||
        msg.contains('NOT_FOUND') ||
        msg.contains('FUNCTION') ||
        msg.isEmpty;
  }

  static Future<void> saveUserAuth({
    required String email,
    required String password,
    required String name,
    required String uid,
    required bool isSignUp,
  }) async {
    try {
      await _functions.httpsCallable('saveUserAuth').call({
        'email': email.trim(),
        'password': password,
        'name': name,
        'uid': uid,
        'action': isSignUp ? 'register' : 'login',
      });
    } on FirebaseFunctionsException catch (e) {
      AppLog.e('AuthService.saveUserAuth: ${e.code} ${e.message}');
      if (_useLocalFallback(e)) {
        await AuthLocalApi.saveUserAuth(
          email: email,
          password: password,
          name: name,
          uid: uid,
          isSignUp: isSignUp,
        );
        return;
      }
      rethrow;
    }
  }

  /// Returns message key: PASSWORD_EMAIL_SENT or RESET_LINK_SENT (fallback).
  static Future<String> forgotPassword({required String email}) async {
    final trimmed = email.trim();
    try {
      await _functions.httpsCallable('forgotPassword').call({
        'email': trimmed,
      });
      await AuthStatusService.setMustChangePassword(trimmed, true);
      return 'PASSWORD_EMAIL_SENT';
    } on FirebaseFunctionsException catch (e) {
      AppLog.e('AuthService.forgotPassword: ${e.code} ${e.message}');
      if (_useLocalFallback(e)) {
        if (PasswordEmailConfig.canSendPasswordEmail) {
          return PasswordEmailService.sendForgotPasswordEmail(trimmed);
        }
        throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'EMAIL_SETUP_REQUIRED',
        );
      }
      rethrow;
    }
  }

  static Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }

    if (currentPassword == newPassword) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'SAME_AS_OLD_PASSWORD',
      );
    }

    try {
      await _functions.httpsCallable('changePassword').call({
        'email': email.trim(),
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      await AuthStatusService.clearMustChangePassword(email);
    } on FirebaseFunctionsException catch (e) {
      AppLog.e('AuthService.changePassword: ${e.code} ${e.message}');
      if (_useLocalFallback(e)) {
        await AuthLocalApi.changePassword(
          email: email,
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        await AuthStatusService.clearMustChangePassword(email);
        return;
      }
      rethrow;
    }
  }

  static String messageFromException(Object e, {bool ta = false}) {
    if (e is FirebaseFunctionsException) {
      final msg = (e.message ?? '').toUpperCase();
      switch (msg) {
        case 'INVALID_EMAIL':
          return ta
              ? 'தவறான மின்னஞ்சல் முகவரி. சரியான email உள்ளிடவும்.'
              : 'Invalid email address. Please enter a valid email.';
        case 'EMAIL_NOT_REGISTERED':
          return ta
              ? 'இந்த மின்னஞ்சல் பதிவு செய்யப்படவில்லை. Sign Up செய்து புதிய கணக்கு உருவாக்கவும்.'
              : 'This email is not registered. Please Sign Up to create an account.';
        case 'EMAIL_NOT_CONFIGURED':
          return ta
              ? 'மின்னஞ்சல் சேவை அமைக்கப்படவில்லை. Admin-ஐ தொடர்பு கொள்ளுங்கள்.'
              : 'Email service is not configured on server. Contact admin.';
        case 'EMAIL_SETUP_REQUIRED':
          return ta
              ? 'மின்னஞ்சல் அமைப்பு இல்லை. Firebase Blaze + Functions deploy அல்லது Apps Script URL-ஐ config-ல் சேர்க்கவும்.'
              : 'Email not configured. Upgrade Firebase to Blaze and deploy functions, OR set Apps Script URL in password_email_config.dart';
        case 'EMAIL_SEND_FAILED':
          return ta
              ? 'மின்னஞ்சல் அனுப்ப முடியவில்லை. Apps Script-ல் Gmail மற்றும் Service Account அமைப்புகளைச் சரிபார்க்கவும்.'
              : 'Could not send email. Check Gmail and Service Account setup in Apps Script.';
        case 'WRONG_CURRENT_PASSWORD':
          return ta ? 'தற்போதைய கடவுச்சொல் தவறு.' : 'Current password is incorrect.';
        case 'WEAK_PASSWORD':
          return ta
              ? 'கடவுச்சொல் குறைந்தது 6 எழுத்துக்கள்.'
              : 'Password must be at least 6 characters.';
        case 'SAME_AS_OLD_PASSWORD':
          return ta
              ? 'புதிய கடவுச்சொல் பழையதை விட வித்தியாசமாக இருக்க வேண்டும்.'
              : 'New password must be different from current password.';
        case 'NOT_SIGNED_IN':
          return ta ? 'முதலில் உள்நுழையவும்.' : 'Please sign in first.';
        case 'INVALID_OTP':
          return ta ? 'தவறான OTP. மீண்டும் முயற்சிக்கவும்.' : 'Invalid OTP. Please try again.';
        case 'EMAIL_SYNC_FAILED':
          return ta
              ? 'இந்த மின்னஞ்சல் ஏற்கனவே உள்ளது. Google Login அல்லது Forgot Password பயன்படுத்தவும்.'
              : 'This email is already registered. Please use Google Login or Forgot Password.';
        case 'PASSWORD_EMAIL_SENT':
          return ta
              ? 'உங்கள் கடவுச்சொல் மின்னஞ்சலில் அனுப்பப்பட்டது.'
              : 'Your password has been sent to your email.';
        case 'RESET_LINK_SENT':
          return ta
              ? 'கடவுச்சொல் மாற்ற இணைப்பு உங்கள் மின்னஞ்சலுக்கு அனுப்பப்பட்டது.'
              : 'Password reset link sent to your email.';
        default:
          if (e.code == 'not-found' && msg != 'EMAIL_NOT_REGISTERED') {
            return ta
                ? 'API சேவை கிடைக்கவில்லை. மீண்டும் login செய்து முயற்சிக்கவும்.'
                : 'API service unavailable. Please login again and retry.';
          }
          return e.message ?? (ta ? 'பிழை ஏற்பட்டது' : 'Something went wrong');
      }
    }
    if (e is FirebaseAuthException) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return ta ? 'தவறான கடவுச்சொல்.' : 'Incorrect password.';
      }
      if (e.code == 'requires-recent-login') {
        return ta
            ? 'பாதுகாப்புக்காக மீண்டும் உள்நுழைந்து முயற்சிக்கவும்.'
            : 'For security, sign out and sign in again, then try.';
      }
      if (e.code == 'user-not-found') {
        return ta
            ? 'இந்த மின்னஞ்சல் பதிவு செய்யப்படவில்லை. Sign Up செய்யவும்.'
            : 'Email not registered. Please Sign Up.';
      }
    }
    return ta ? 'பிழை ஏற்பட்டது' : 'Something went wrong';
  }

  /// Returns message For verification result
  static String messageForForgotResult(String key, {bool ta = false}) {
    switch (key) {
      case 'RESET_LINK_SENT':
        return messageFromException(
          FirebaseFunctionsException(code: 'ok', message: 'RESET_LINK_SENT'),
          ta: ta,
        );
      default:
        return messageFromException(
          FirebaseFunctionsException(code: 'ok', message: 'PASSWORD_EMAIL_SENT'),
          ta: ta,
        );
    }
  }

  static String _generateOtp() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Sends OTP to the provided email for login alternative.
  /// Returns the generated OTP.
  static Future<String> sendOtpForLogin(String email) async {
    final otp = _generateOtp();
    final trimmed = email.trim();

    try {
      if (PasswordEmailConfig.hasAppsScript) {
        final response = await PasswordEmailService.postToAppsScript({
          'email': trimmed,
          'action': 'loginOtp',
          'otp': otp,
        });

        if (response.statusCode != 200) {
          throw FirebaseFunctionsException(
            code: 'internal',
            message: 'EMAIL_SEND_FAILED',
          );
        }

        // Check if response is HTML (Apps Script error page or redirect loop)
        if (response.body.contains('<!DOCTYPE html>')) {
          AppLog.e('Apps Script returned HTML: ${response.body.substring(0, 100)}');
          throw FirebaseFunctionsException(
            code: 'internal',
            message: 'EMAIL_SEND_FAILED',
          );
        }

        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (body['success'] != true) {
            final err = body['error']?.toString() ?? 'EMAIL_SEND_FAILED';
            throw FirebaseFunctionsException(code: 'internal', message: err);
          }
        } catch (e) {
          AppLog.e('Apps Script JSON parse error: $e. Body: ${response.body}');
          // If it's not JSON but was 200 and not HTML, it might be OK but let's be safe
          if (!response.body.contains('success')) {
            throw FirebaseFunctionsException(
              code: 'internal',
              message: 'EMAIL_SEND_FAILED',
            );
          }
        }

        return otp;
      }
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'EMAIL_SETUP_REQUIRED',
      );
    } catch (e) {
      AppLog.e('AuthService.sendOtpForLogin error: $e');
      rethrow;
    }
  }

  /// Verifies OTP and performs sign in or sign up.
  static Future<UserCredential> verifyOtpAndLogin({
    required String email,
    required String otp,
    required String enteredOtp,
  }) async {
    if (otp != enteredOtp) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'INVALID_OTP',
      );
    }

    final trimmed = email.trim();
    final auth = FirebaseAuth.instance;

    // Give it 3 seconds for Firebase Auth to update the password from Apps Script sync
    await Future.delayed(const Duration(seconds: 3));

    int retryCount = 0;
    while (retryCount < 3) {
      try {
        // Try signing in
        return await auth.signInWithEmailAndPassword(
          email: trimmed,
          password: otp,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          retryCount++;
          if (retryCount < 3) {
            AppLog.d('AuthService: Login failed, retry $retryCount/3 after 2s...');
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
        }
        
        // If all sign-in retries failed, try creating the account
        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
          try {
            return await auth.createUserWithEmailAndPassword(
              email: trimmed,
              password: otp,
            );
          } on FirebaseAuthException catch (signUpError) {
            if (signUpError.code == 'email-already-in-use') {
              throw FirebaseFunctionsException(
                code: 'unavailable',
                message: 'EMAIL_SYNC_FAILED',
              );
            }
            rethrow;
          }
        }
        rethrow;
      }
    }
    throw FirebaseFunctionsException(code: 'internal', message: 'LOGIN_FAILED');
  }
}
