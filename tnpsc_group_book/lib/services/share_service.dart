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
🎯 *TNPSC Quiz Challenge | உங்களால் சரியாக பதில் சொல்ல முடியுமா?* 🔥

*கேள்வி / Question:*
$questionTa
($questionEn)

$optionsText

TNPSC Group 1, Group 2, Group 4 தேர்வுக்கு தயாராகிறீர்களா? 📚
இந்த Quiz-ல் உங்களுடைய அறிவை Test பண்ணிப் பாருங்கள்! 💯

✅ Daily TNPSC Quiz
✅ Previous Year Questions
✅ Mock Tests
✅ Daily Study & Practice
✅ Leaderboard & Streak 🔥

📲 *TNPSC Master App Download:*
$_appLink

👉 *App-ஐ Download செய்து தினமும் Quiz Practice செய்யுங்கள்!*

#TNPSC #TNPSCQuiz #TNPSCGroup4 #TNPSCGroup2 #TNPSCPreparation #TNPSC2026 #TNPSCMaster #DailyQuiz #Tamilவினாடிவினா #GovernmentJobs
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
