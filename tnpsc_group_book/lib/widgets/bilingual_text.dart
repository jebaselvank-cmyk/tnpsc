import 'package:flutter/material.dart';
import '../models/question.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';

class BilingualText extends StatelessWidget {
  final String? en;
  final String? ta;
  final String? legacy;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final bool showBoth;
  final bool singleLine;

  const BilingualText({
    super.key,
    this.en,
    this.ta,
    this.legacy,
    this.fontSize = 16,
    this.fontWeight = FontWeight.normal,
    this.color,
    this.showBoth = true,
    this.singleLine = false,
  });

  static String cleanSingleLine(String text) {
    String cleaned = text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll(RegExp(r'[\r\n]+', multiLine: true), ' ')
        .replaceAll(RegExp(r'\s*,\s*'), ', ')
        .replaceAll(RegExp(r',\s*,\s*'), ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.endsWith(',')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String currentLang = AppLanguage.languageNotifier.value;

    String displayEn = en ?? "";
    String displayTa = ta ?? "";
    
    // structured fields or legacy splitting (clean legacy first to avoid splitting on internal newlines)
    if (displayEn.isEmpty && displayTa.isEmpty && legacy != null) {
      var cleanedLegacy = cleanSingleLine(legacy!);
      var parsed = AppLanguage.parseBilingual(cleanedLegacy);
      displayEn = parsed['en']!;
      displayTa = parsed['ta']!;
    }
    
    // Safety check: if one is empty but the other isn't, use the available one for both to avoid empty lines
    if (displayEn.isEmpty && displayTa.isNotEmpty) displayEn = displayTa;
    if (displayTa.isEmpty && displayEn.isNotEmpty) displayTa = displayEn;

    // 1. If only one language is requested and available
    if (!showBoth) {
      if (currentLang == 'ta') {
        String taText = Question.formatQuestionText(displayTa.isNotEmpty ? displayTa : displayEn);
        return Text(
          singleLine ? cleanSingleLine(taText) : taText,
          style: AppTheme.getStyle(fontSize: fontSize, fontWeight: fontWeight, color: color),
        );
      } else {
        String enText = Question.formatQuestionText(displayEn);
        return Text(
          singleLine ? cleanSingleLine(enText) : enText,
          style: AppTheme.getStyle(fontSize: fontSize, fontWeight: fontWeight, color: color),
        );
      }
    }

    // 2. If singleLine is true (e.g. for options, flatten all vertical newlines into a clean single line)
    if (singleLine) {
      String cleanTa = cleanSingleLine(displayTa);
      String cleanEn = cleanSingleLine(displayEn);

      String combined = (cleanTa.isNotEmpty && cleanEn.isNotEmpty && cleanTa != cleanEn)
          ? "$cleanTa\n$cleanEn"
          : (cleanTa.isNotEmpty ? cleanTa : cleanEn);
      return Text(
        combined,
        maxLines: 20,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.getStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color ?? (isDark ? Colors.white : AppTheme.textMainColor),
        ),
      );
    }

    displayEn = Question.formatQuestionText(displayEn);
    displayTa = Question.formatQuestionText(displayTa);

    // 3. Show both nicely separated
    if (displayEn == displayTa || displayTa.isEmpty) {
      return Text(
        displayEn,
        style: AppTheme.getStyle(fontSize: fontSize, fontWeight: fontWeight, color: color),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayTa,
          style: AppTheme.getStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color ?? (isDark ? Colors.white : AppTheme.textMainColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          displayEn,
          style: AppTheme.getStyle(
            fontSize: fontSize - 1,
            fontWeight: FontWeight.w500,
            color: color?.withValues(alpha: 0.8) ?? (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ],
    );
  }
}
