import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../utils/app_log.dart';
import 'package:http/http.dart' as http;

import '../config/password_email_config.dart';
import 'auth_status_service.dart';

/// Sends forgot-password emails when Cloud Functions are not deployed (Spark plan).
class PasswordEmailService {
  static final _db = FirebaseFirestore.instance;
  static final _random = Random.secure();

  static String _norm(String email) => email.trim().toLowerCase();

  static String generateTempPassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyz';
    final part1 = List.generate(4, (_) => chars[_random.nextInt(chars.length)]).join();
    final part2 = 1000 + _random.nextInt(9000);
    return '$part1$part2';
  }

  /// Handles Google Apps Script POST redirects manually.
  static Future<http.Response> postToAppsScript(Map<String, dynamic> data) async {
    final url = PasswordEmailConfig.appsScriptWebAppUrl.trim();
    if (url.isEmpty) {
      throw FirebaseFunctionsException(code: 'failed-precondition', message: 'EMAIL_SETUP_REQUIRED');
    }

    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(url))
        ..headers['Content-Type'] = 'application/json'
        ..headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        ..body = jsonEncode(data)
        ..followRedirects = false;

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 45));
      
      // Handle 302/301 redirects manually
      if (streamedResponse.statusCode == 302 || streamedResponse.statusCode == 301) {
        final location = streamedResponse.headers['location'];
        if (location != null) {
          // Redirect target should be accessed via GET
          return await http.get(
            Uri.parse(location),
            headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'}
          ).timeout(const Duration(seconds: 45));
        }
      }
      
      return await http.Response.fromStream(streamedResponse);
    } finally {
      client.close();
    }
  }

  /// Apps Script updates Firebase Auth + sends Gmail.
  static Future<void> sendViaAppsScript(String email) async {
    final response = await postToAppsScript({'email': _norm(email)});

    AppLog.d('Apps Script response: ${response.statusCode} ${response.body}');

    if (response.statusCode != 200) {
      AppLog.e('Apps Script error status: ${response.statusCode}');
      if (response.body.contains('<!DOCTYPE html>')) {
        AppLog.e('ERROR: Apps Script returned HTML instead of JSON. Please check if Deployment is set to "Anyone".');
      }
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'EMAIL_SEND_FAILED',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      final err = body['error']?.toString() ?? 'EMAIL_SEND_FAILED';
      throw FirebaseFunctionsException(code: 'internal', message: err);
    }
  }

  /// EmailJS + Firestore; optional Apps Script sync on next login.
  static Future<void> sendViaEmailJs(String email) async {
    final norm = _norm(email);
    final tempPassword = generateTempPassword();
    final hash = BCrypt.hashpw(tempPassword, BCrypt.gensalt());

    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: norm)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update({
        'passwordHash': hash,
        'mustChangePassword': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // If user doesn't exist in users collection, EmailJS reset won't work well 
      // because we shouldn't create a random user doc without a UID.
      // But we will fallback to a temporary doc if necessary.
      throw FirebaseFunctionsException(
        code: 'not-found',
        message: 'EMAIL_NOT_REGISTERED',
      );
    }

    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': PasswordEmailConfig.emailJsServiceId,
        'template_id': PasswordEmailConfig.emailJsTemplateId,
        'user_id': PasswordEmailConfig.emailJsPublicKey,
        'template_params': {
          'to_email': norm,
          'user_email': norm,
          'password': tempPassword,
          'app_name': 'TNPSC Master',
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLog.e('EmailJS error: ${response.statusCode} ${response.body}');
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'EMAIL_SEND_FAILED',
      );
    }

    if (PasswordEmailConfig.hasAppsScript) {
      await syncFirebasePassword(norm, tempPassword);
    }
  }

  /// Sync Firebase Auth password (Apps Script) after EmailJS forgot flow.
  static Future<void> syncFirebasePassword(String email, String password) async {
    if (!PasswordEmailConfig.hasAppsScript) return;

    try {
      final response = await postToAppsScript({
        'email': _norm(email),
        'action': 'syncPassword',
        'password': password,
      });

      if (response.statusCode != 200 || response.body.contains('<!DOCTYPE html>')) {
        AppLog.e('Apps Script sync failed (HTML or Error): ${response.statusCode}');
      } else {
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (body['success'] != true) {
            AppLog.e('Apps Script sync returned error: ${body['error']}');
          }
        } catch (e) {
          AppLog.e('Apps Script sync JSON parse error: $e');
        }
      }
    } catch (e) {
      AppLog.e('Apps Script sync network error: $e');
    }
  }

  static Future<bool> verifyFirestorePassword(String email, String password) async {
    final norm = _norm(email);
    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: norm)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return false;
    final hash = snap.docs.first.data()['passwordHash'] as String?;
    if (hash == null || hash.isEmpty) return false;
    return BCrypt.checkpw(password, hash);
  }

  /// Fallback when Cloud Functions return NOT_FOUND.
  static Future<String> sendForgotPasswordEmail(String email) async {
    final norm = _norm(email);

    if (PasswordEmailConfig.hasAppsScript) {
      await sendViaAppsScript(norm);
      await AuthStatusService.setMustChangePassword(norm, true);
      return 'PASSWORD_EMAIL_SENT';
    }

    if (PasswordEmailConfig.hasEmailJs) {
      await sendViaEmailJs(norm);
      await AuthStatusService.setMustChangePassword(norm, true);
      return 'PASSWORD_EMAIL_SENT';
    }

    throw FirebaseFunctionsException(
      code: 'failed-precondition',
      message: 'EMAIL_SETUP_REQUIRED',
    );
  }

  /// Sends the 6-digit OTP to the user's email for Passwordless Login
  static Future<void> sendOtpEmail(String email, String otp) async {
    final norm = _norm(email);

    // Try EmailJS first for OTPs as it's faster usually
    if (PasswordEmailConfig.hasEmailJs) {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': PasswordEmailConfig.emailJsServiceId,
          'template_id': PasswordEmailConfig.emailJsTemplateId, // Reusing template for OTP
          'user_id': PasswordEmailConfig.emailJsPublicKey,
          'template_params': {
            'to_email': norm,
            'user_email': norm,
            'password': otp, // Injecting OTP into the generic password placeholder
            'app_name': 'TNPSC Master OTP',
          },
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
    }

    // Fallback to Apps Script if EmailJS fails or is not configured
    if (PasswordEmailConfig.hasAppsScript) {
      final response = await postToAppsScript({
        'email': norm,
        'action': 'sendOtp',
        'otp': otp,
      });

      if (response.statusCode == 200 && !response.body.contains('<!DOCTYPE html>')) {
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (body['success'] == true) return;
          AppLog.e('Apps Script returned error: ${body['error']}');
        } catch (e) {
          return; // Success or non-JSON but not HTML
        }
      } else {
        AppLog.e('Apps Script sendOtp failed (HTML or HTTP ${response.statusCode})');
      }
    }

    throw FirebaseFunctionsException(
      code: 'internal',
      message: 'EMAIL_SEND_FAILED',
    );
  }
}
