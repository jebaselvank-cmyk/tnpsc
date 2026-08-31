import 'package:share_plus/share_plus.dart';
import '../models/question.dart';

class ShareService {
  static const String _appLink = "https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book";

  /// Formats a question into a poll-like text for WhatsApp/Facebook sharing.
  static String _formatQuestionAsPoll(Question q) {
    final questionTa = q.questionTa ?? q.question.split('\n').last;
    final questionEn = q.questionEn ?? q.question.split('\n').first;

    final List<String> optionEmojis = ["1️⃣", "2️⃣", "3️⃣", "4️⃣"];
    String optionsText = "";

    for (int i = 0; i < 4; i++) {
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
      optionsText += "${optionEmojis[i]} $optTa / $optEn\n";
    }

    return """
📊 *TNPSC Daily Challenge* 📊

*கேள்வி / Question:*
$questionTa
($questionEn)

$optionsText
✅ *சரியான விடையைக் காண ஆப்பை பதிவிறக்கவும்:*
👇 *Download App to check answer:*
$_appLink
""";
  }

  /// Shares the question to WhatsApp (via system share sheet)
  static Future<void> shareToWhatsApp(Question q) async {
    final text = _formatQuestionAsPoll(q);
    await Share.share(text, subject: 'TNPSC Quiz Challenge');
  }

  /// Shares the question to Facebook (via system share sheet)
  static Future<void> shareToFacebook(Question q) async {
    final text = _formatQuestionAsPoll(q);
    // Note: Facebook often strips text when sharing a link, 
    // but sharing just text or a formatted block works through the system dialog.
    await Share.share(text, subject: 'TNPSC Quiz Challenge');
  }

  /// Generic share method that allows the user to choose any app
  static Future<void> shareGeneric(Question q) async {
    final text = _formatQuestionAsPoll(q);
    await Share.share(text, subject: 'TNPSC Quiz Challenge');
  }
}
