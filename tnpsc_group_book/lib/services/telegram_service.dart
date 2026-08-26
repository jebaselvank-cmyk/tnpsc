import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/question.dart';
import '../utils/app_log.dart';

class TelegramService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Sends a question as a Telegram Quiz Poll directly from the app.
  /// Fetches Bot Token and Channel ID from Firestore for security & flexibility.
  static Future<Map<String, dynamic>> sendQuestionAsPoll(Question q) async {
    try {
      AppLog.d("TELEGRAM_DEBUG: Fetching config from Firestore...");
      // 1. Fetch Config from Firestore
      final configDoc = await _db.collection('settings').doc('admin_config').get();
      
      if (!configDoc.exists) {
        AppLog.e("TELEGRAM_DEBUG: Document settings/admin_config NOT FOUND");
        return {'success': false, 'error': 'Telegram config not found in Firestore (settings/admin_config)'};
      }

      final botToken = configDoc.get('telegram_bot_token')?.toString().trim();
      final channelId = configDoc.get('telegram_channel_id')?.toString().trim();

      if (botToken == null || channelId == null || botToken.isEmpty || channelId.isEmpty) {
        AppLog.e("TELEGRAM_DEBUG: Token or Channel ID is NULL or EMPTY in Firestore");
        return {'success': false, 'error': 'Bot Token or Channel ID is missing in Firestore'};
      }

      AppLog.d("TELEGRAM_DEBUG: Config loaded. Token prefix: ${botToken.substring(0, 5)}..., Channel: $channelId");

      // 2. Prepare Data
      final questionTa = q.questionTa ?? q.question.split('\n').last;
      final questionEn = q.questionEn ?? q.question.split('\n').first;
      
      final combinedQuestion = "$questionTa\n\n($questionEn)";
      
      final formattedOptions = List.generate(4, (i) {
        String optEn = "";
        String optTa = "";
        if (q.optionsEn != null && q.optionsTa != null) {
          optEn = q.optionsEn![i];
          optTa = q.optionsTa![i];
        } else {
          final parts = q.options[i].split('/');
          optTa = parts.first.trim();
          optEn = parts.length > 1 ? parts.last.trim() : "";
        }
        String text = "$optTa / $optEn";
        return text.length > 100 ? text.substring(0, 97) + "..." : text;
      });

      final explanationTa = q.explanationTa ?? "";
      final explanationEn = q.explanationEn ?? "";
      final combinedExplanation = "$explanationTa\n\n$explanationEn".trim();

      AppLog.d("TELEGRAM_DEBUG: Sending request to Telegram API...");

      // 3. Direct API Call to Telegram
      final url = Uri.parse("https://api.telegram.org/bot$botToken/sendPoll");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "chat_id": channelId,
          "question": combinedQuestion.length > 300 ? combinedQuestion.substring(0, 297) + "..." : combinedQuestion,
          "options": formattedOptions,
          "is_anonymous": true, // Must be true for Telegram Channels
          "type": "quiz",
          "correct_option_id": q.correctOptionIndex,
          "explanation": combinedExplanation.isEmpty ? null : (combinedExplanation.length > 200 ? combinedExplanation.substring(0, 197) + "..." : combinedExplanation),
        }),
      ).timeout(const Duration(seconds: 15));

      AppLog.d("TELEGRAM_DEBUG: Telegram API Response Code: ${response.statusCode}");
      AppLog.d("TELEGRAM_DEBUG: Telegram API Response Body: ${response.body}");

      final result = jsonDecode(response.body);

      if (result['ok'] == true) {
        return {'success': true, 'message_id': result['result']['message_id']};
      } else {
        AppLog.e("TELEGRAM_DEBUG: Telegram Error: ${result['description']}");
        return {'success': false, 'error': result['description']};
      }
    } catch (e) {
      AppLog.e("TELEGRAM_DEBUG: Catch Error: $e");
      return {'success': false, 'error': e.toString()};
    }
  }
}
