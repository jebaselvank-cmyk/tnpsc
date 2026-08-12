import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../services/hive_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_log.dart';

class AppRatingDialog extends StatefulWidget {
  const AppRatingDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => const AppRatingDialog(),
    );
  }

  @override
  State<AppRatingDialog> createState() => _AppRatingDialogState();
}

class _AppRatingDialogState extends State<AppRatingDialog> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) return;

    setState(() => _isSaving = true);
    
    try {
      final String feedback = _commentController.text.trim();

      // 1. Save to Firestore
      await FirestoreService().saveAppRating(_rating, feedback);
      
      // 2. Mark as rated locally
      await HiveService.setAppRated(true);

      // 3. If high rating, Copy feedback to Clipboard and go to Play Store
      if (_rating >= 4) {
        if (feedback.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: feedback));
        }
        await _launchStore();
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      AppLog.e("Error submitting rating: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _launchStore() async {
    const String url = "https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book";
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLog.e("Error launching store for rating: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isTamil = AppLanguage.languageNotifier.value == 'ta';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark 
                    ? const Color(0xFF1E293B).withOpacity(0.7) 
                    : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withOpacity(0.1) 
                      : Colors.black.withOpacity(0.05),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "⭐",
                    style: TextStyle(fontSize: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isTamil ? "உங்களுக்கு இந்த ஆப் பிடித்திருக்கிறதா?" : "Do you like this app?",
                    textAlign: TextAlign.center,
                    style: AppTheme.getStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textMainColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTamil 
                        ? "உங்கள் கருத்து எங்களுக்கு மிகவும் முக்கியமானது. எங்களை மதிப்பிடவும்." 
                        : "Your feedback is very important to us. Please rate us.",
                    textAlign: TextAlign.center,
                    style: AppTheme.getStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        onPressed: () {
                          setState(() {
                            _rating = index + 1;
                          });
                        },
                        icon: Icon(
                          index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 36,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    maxLines: 2,
                    style: AppTheme.getStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : AppTheme.textMainColor,
                    ),
                    decoration: InputDecoration(
                      hintText: isTamil ? "உங்கள் கருத்துக்களை இங்கே எழுதவும்..." : "Write your feedback here...",
                      hintStyle: AppTheme.getStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          child: Text(
                            isTamil ? "பிறகு" : "Maybe Later",
                            style: AppTheme.getStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white60 : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (_rating == 0 || _isSaving) ? null : _submitRating,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                isTamil ? "சேமிக்க" : "Save",
                                style: AppTheme.getStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
