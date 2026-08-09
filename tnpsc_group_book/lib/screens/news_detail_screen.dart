import 'package:flutter/material.dart';
import '../models/news_item.dart';
import '../services/tts_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../utils/app_icons.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsItem newsItem;
  const NewsDetailScreen({super.key, required this.newsItem});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  bool _isSpeaking = false;

  @override
  void dispose() {
    TtsService.stop();
    super.dispose();
  }

  void _toggleTts() {
    String lang = AppLanguage.languageNotifier.value;
    String text = lang == 'ta' ? widget.newsItem.contentTa : widget.newsItem.contentEn;
    
    if (_isSpeaking) {
      TtsService.stop();
      setState(() => _isSpeaking = false);
    } else {
      TtsService.speak(text);
      setState(() => _isSpeaking = true);
      TtsService.onComplete = () {
        if (mounted) setState(() => _isSpeaking = false);
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String lang = AppLanguage.languageNotifier.value;
    String title = lang == 'ta' ? widget.newsItem.titleTa : widget.newsItem.titleEn;
    String content = lang == 'ta' ? widget.newsItem.contentTa : widget.newsItem.contentEn;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: isDark ? Colors.white : AppTheme.textMainColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang == 'ta' ? "நடப்பு நிகழ்வுகள்" : "Current Affairs",
          style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.secondaryColor.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.newsItem.category,
                style: AppTheme.getStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.secondaryColor : AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTheme.getStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textMainColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.newsItem.date,
              style: AppTheme.getStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const Divider(height: 40),
            Text(
              content,
              style: AppTheme.getStyle(
                fontSize: 16,
                height: 1.6,
                color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleTts,
        label: Text(_isSpeaking ? (lang == 'ta' ? "நிறுத்து" : "Stop") : (lang == 'ta' ? "கேட்க" : "Listen")),
        icon: Icon(_isSpeaking ? Icons.stop_rounded : Icons.play_arrow_rounded),
        backgroundColor: isDark ? AppTheme.primaryColorLight : AppTheme.secondaryColorLight,
      ),
    );
  }
}
