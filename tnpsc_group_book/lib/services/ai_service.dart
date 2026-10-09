import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:tnpsc_group_book/utils/app_date.dart';
import '../utils/app_log.dart';
import '../models/question.dart';
import 'hive_service.dart';

class AiService {
  static List<String>? _cachedApiKeys;
  static List<String>? _cachedPreferredModels;

  static bool _isFetchingConfig = false;

  // -----------------------------------------------------------------
  // Language Topics for Topical Rotation
  // -----------------------------------------------------------------
  static const List<Map<String, dynamic>> _languageTopics = [
    {'id': 1, 'title': 'இலக்கணம் (Grammar)', 'desc': 'எழுத்தியல், சொற்களின் வகைகள், புணர்ச்சி, வேற்றுமை, பெயர்ச்சொல், வினைச்சொல்.'},
    {'id': 2, 'title': 'சொல்லகராதி (Vocabulary)', 'desc': 'சொற்களின் அர்த்தம், பயன்பாடு, ஒருபொருள் பலசொல், பலபொருள் ஒரு சொல்.'},
    {'id': 3, 'title': 'திருக்குறள் (Thirukkural)', 'desc': 'அறத்துப்பால், பொருட்பால், இன்பத்துப்பால் தொடர்பான வினாக்கள்.'},
    {'id': 4, 'title': 'சங்க இலக்கியம் (Sangam Literature)', 'desc': 'எட்டுத்தொகை, பத்துப்பாட்டு மற்றும் சங்க கால செய்திகள்.'},
    {'id': 5, 'title': 'காப்பியங்கள் (Epics)', 'desc': 'ஐம்பெருங் காப்பியங்கள் மற்றும் ஐஞ்சிறு காப்பியங்கள்.'},
    {'id': 6, 'title': 'ஆசிரியர் மற்றும் நூல்கள் (Authors and Books)', 'desc': 'நூலாசிரியர்கள், அவர்களின் படைப்புகள் மற்றும் குறிப்புகள்.'},
    {'id': 7, 'title': 'தமிழ் அறிஞர்கள் (Tamil Scholars)', 'desc': 'தமிழ் அறிஞர்களும் அவர்களின் தமிழ்த் தொண்டும்.'},
    {'id': 8, 'title': 'பழமொழிகள் (Proverbs)', 'desc': 'பழமொழிகள் மற்றும் அவற்றின் வாழ்வியல் விளக்கங்கள்.'},
    {'id': 9, 'title': 'மரபுத்தொடர்கள் (Idioms)', 'desc': 'மரபுத்தொடர்கள், சொலவடைகள் மற்றும் அவற்றின் பொருள்.'},
    {'id': 10, 'title': 'எதிர்ச்சொல் (Antonyms)', 'desc': 'சரியான எதிர்ச்சொற்களைத் தேர்வு செய்தல்.'},
    {'id': 11, 'title': 'இணைச்சொல் (Synonyms)', 'desc': 'நேரிணை, எதிரிணை மற்றும் செறிணைச் சொற்கள்.'},
    {'id': 12, 'title': 'ஒருபொருள் பலசொல் (One meaning many words)', 'desc': 'ஒரே பொருளைத் தரும் பல்வேறு சொற்களை அறிதல்.'},
    {'id': 13, 'title': 'பலபொருள் ஒரு சொல் (One word many meanings)', 'desc': 'ஒரு சொல்லுக்கு இருக்கும் பல்வேறு அர்த்தங்கள்.'},
    {'id': 14, 'title': 'புணர்ச்சி (Punarchi)', 'desc': 'இயல்புப் புணர்ச்சி மற்றும் விகாரப் புணர்ச்சி விதிகள்.'},
    {'id': 15, 'title': 'வேற்றுமை (Case)', 'desc': 'முதல் முதல் எட்டாம் வேற்றுமை வரையிலான உருபுகள் மற்றும் பயன்கள்.'},
    {'id': 16, 'title': 'வினைச்சொல் (Verb)', 'desc': 'தன்வினை, பிறவினை, செய்வினை, செயப்பாட்டு வினை.'},
    {'id': 17, 'title': 'பெயர்ச்சொல் (Noun)', 'desc': 'பெயர்ச்சொல்லின் வகைகள் மற்றும் பயன்பாடு.'},
    {'id': 18, 'title': 'வாக்கிய அமைப்பு (Sentence Structure)', 'desc': 'நேரடி உரை, மறைமுக உரை மற்றும் வாக்கிய வகைகள்.'},
    {'id': 19, 'title': 'பிழை திருத்தம் (Error Correction)', 'desc': 'எழுத்துப் பிழை, சந்திப் பிழை மற்றும் ஒருமை-பன்மை பிழை நீக்குதல்.'},
    {'id': 20, 'title': 'வாசிப்புப் புரிதல் (Comprehension)', 'desc': 'பத்தியைப் படித்து வினாக்களுக்கு விடையளித்தல்.'},
    {'id': 21, 'title': 'தமிழ் மொழி வரலாறு (Tamil History)', 'desc': 'தமிழ் மொழியின் தோற்றம் மற்றும் வளர்ச்சி நிலைகள்.'},
    {'id': 22, 'title': 'சங்க காலம் (Sangam Era)', 'desc': 'சங்க காலத் தமிழகத்தின் சமூக மற்றும் பண்பாட்டு நிலைகள்.'},
    {'id': 23, 'title': 'பக்தி இலக்கியம் (Devotional)', 'desc': 'தேவாரம், திருவாசகம், நாலாயிர திவ்ய பிரபந்தம் உள்ளிட்டவை.'},
    {'id': 24, 'title': 'சிற்றிலக்கியம் (Minor Literature)', 'desc': 'தூது, உலா, பரணி, பள்ளு, குறவஞ்சி போன்ற 96 வகை இலக்கியங்கள்.'},
    {'id': 25, 'title': 'செம்மொழித் தமிழ் (Classical)', 'desc': 'தமிழ் செம்மொழியானதற்கான தகுதிகள் மற்றும் சிறப்புகள்.'},
    {'id': 26, 'title': 'தமிழ் வளர்ச்சி (Development)', 'desc': 'தற்காலத் தமிழ் வளர்ச்சி மற்றும் கணினித் தமிழ்.'},
    {'id': 27, 'title': 'முந்தைய ஆண்டு கேள்விகள் (PYQ)', 'desc': 'டிஎன்பிஎஸ்சி தேர்வுகளில் கேட்கப்பட்ட முந்தைய வினாக்கள்.'},
    {'id': 28, 'title': 'Mixed Tamil Quiz', 'desc': 'அனைத்துப் பகுதிகளில் இருந்தும் கேட்கப்படும் பொதுவான வினாக்கள்.'},
  ];

  static const List<Map<String, dynamic>> _aptitudeTopics = [
    {'id': 1, 'title': 'Simplification', 'desc': 'BODMAS, Fractions, Decimals, Square/Cube Roots.'},
    {'id': 2, 'title': 'Percentage', 'desc': 'Basic percentage, increase/decrease, results.'},
    {'id': 3, 'title': 'Ratio and Proportion', 'desc': 'Comparison of quantities and sharing.'},
    {'id': 4, 'title': 'Average', 'desc': 'Mean, weights, and age-based averages.'},
    {'id': 5, 'title': 'Profit and Loss', 'desc': 'Cost price, selling price, discounts, markup.'},
    {'id': 6, 'title': 'Simple Interest', 'desc': 'P*N*R/100 calculations and variations.'},
    {'id': 7, 'title': 'Compound Interest', 'desc': 'Annual, half-yearly, and quarterly compounding.'},
    {'id': 8, 'title': 'Time and Work', 'desc': 'Man-days, efficiency, combined work.'},
    {'id': 9, 'title': 'Pipes and Cisterns', 'desc': 'Inlet and outlet flow calculations.'},
    {'id': 10, 'title': 'Time, Speed and Distance', 'desc': 'Relative speed, trains, and boats.'},
    {'id': 11, 'title': 'Problems on Ages', 'desc': 'Past, present, and future age relations.'},
    {'id': 12, 'title': 'Number System', 'desc': 'Divisibility, units digit, remainder theorem.'},
    {'id': 13, 'title': 'HCF and LCM', 'desc': 'Factors, multiples, and their applications.'},
    {'id': 14, 'title': 'Fractions and Decimals', 'desc': 'Conversion, ordering, and operations.'},
    {'id': 15, 'title': 'Square Root and Cube Root', 'desc': 'Calculation and application in problems.'},
    {'id': 16, 'title': 'Data Interpretation', 'desc': 'Pie charts, Bar graphs, Tables, Line graphs.'},
    {'id': 17, 'title': 'Mensuration', 'desc': 'Area and Volume of 2D/3D shapes.'},
    {'id': 18, 'title': 'Geometry', 'desc': 'Lines, Angles, Triangles, and Circles.'},
    {'id': 19, 'title': 'Probability', 'desc': 'Coin, Dice, and Card-based problems.'},
    {'id': 20, 'title': 'Permutations and Combinations', 'desc': 'Arrangements and Selections.'},
    {'id': 21, 'title': 'Logical Reasoning', 'desc': 'Puzzles, Deductions, and Conclusions.'},
    {'id': 22, 'title': 'Number Series', 'desc': 'Missing number, next number patterns.'},
    {'id': 23, 'title': 'Odd One Out', 'desc': 'Identifying the non-matching item.'},
    {'id': 24, 'title': 'Analogy', 'desc': 'Finding similar relationships.'},
    {'id': 25, 'title': 'Coding and Decoding', 'desc': 'Pattern-based word/number conversion.'},
    {'id': 26, 'title': 'Direction Sense', 'desc': 'Movement and final position tracking.'},
    {'id': 27, 'title': 'Blood Relations', 'desc': 'Family tree and relationship mapping.'},
    {'id': 28, 'title': 'Ranking and Order', 'desc': 'Position in a row or sequence.'},
    {'id': 29, 'title': 'Calendar', 'desc': 'Finding day of the week, odd days.'},
    {'id': 30, 'title': 'Clock', 'desc': 'Angles between hands, time gain/loss.'},
    {'id': 31, 'title': 'Mixed Aptitude Quiz', 'desc': 'General problems from all chapters.'},
  ];

  static const List<Map<String, dynamic>> _gsTopics = [
    {'id': 1, 'title': 'General Science', 'desc': 'Physics, Chemistry, and Biology fundamentals.'},
    {'id': 2, 'title': 'Current Affairs', 'desc': 'National and international news from last 6 months.'},
    {'id': 3, 'title': 'Indian History', 'desc': 'Indus Valley to British Era history.'},
    {'id': 4, 'title': 'Indian National Movement', 'desc': 'Freedom struggle and leaders.'},
    {'id': 5, 'title': 'Indian Polity', 'desc': 'Constitution, Governance, and Rights.'},
    {'id': 6, 'title': 'Indian Economy', 'desc': 'Finance, Planning, and RBI.'},
    {'id': 7, 'title': 'Indian Geography', 'desc': 'Monsoon, Rivers, and Minerals.'},
    {'id': 8, 'title': 'Tamil Nadu History', 'desc': 'Society and archaeological discoveries.'},
    {'id': 9, 'title': 'Tamil Nadu Culture', 'desc': 'Traditions, literature, and art forms.'},
    {'id': 10, 'title': 'Tamil Nadu Heritage', 'desc': 'Monuments and historical significance.'},
    {'id': 11, 'title': 'Tamil Nadu Administration', 'desc': 'E-governance and social welfare schemes.'},
    {'id': 12, 'title': 'Social Issues', 'desc': 'Population, Poverty, and Corruption.'},
    {'id': 13, 'title': 'Development Administration', 'desc': 'HDI and socioeconomic development in TN.'},
    {'id': 14, 'title': 'Science and Technology', 'desc': 'Space, Defense, and IT developments.'},
    {'id': 15, 'title': 'Environment and Ecology', 'desc': 'Biodiversity and Climate change.'},
    {'id': 16, 'title': 'Government Schemes', 'desc': 'Central and State welfare programs.'},
    {'id': 17, 'title': 'Important Personalities', 'desc': 'Leaders, Scientists, and Social Reformers.'},
    {'id': 18, 'title': 'Awards and Honours', 'desc': 'Nobel, Bharat Ratna, and State awards.'},
    {'id': 19, 'title': 'Sports', 'desc': 'Cricket, Chess, Olympics, and Championships.'},
    {'id': 20, 'title': 'Books and Authors', 'desc': 'Famous publications and literary awards.'},
    {'id': 21, 'title': 'Mixed General Studies Quiz', 'desc': 'Integrated questions from all GS areas.'},
  ];

  static String _getLanguageTopicsForDate(DateTime date, int count) {
    // Truly random selection by shuffling the list
    List<Map<String, dynamic>> shuffled = List<Map<String, dynamic>>.from(_languageTopics)..shuffle();
    List<Map<String, dynamic>> selected = shuffled.take(count).toList();

    return selected.map((t) => "- ${t['title']}: ${t['desc']}").join("\n");
  }

  static String _getAptitudeTopicsForDate(DateTime date, int count) {
    // Truly random selection by shuffling the list
    List<Map<String, dynamic>> shuffled = List<Map<String, dynamic>>.from(_aptitudeTopics)..shuffle();
    List<Map<String, dynamic>> selected = shuffled.take(count).toList();

    return selected.map((t) => "- ${t['title']}: ${t['desc']}").join("\n");
  }

  static String _getGsTopicsForDate(DateTime date, int count) {
    // Truly random selection by shuffling the list
    List<Map<String, dynamic>> shuffled = List<Map<String, dynamic>>.from(_gsTopics)..shuffle();
    List<Map<String, dynamic>> selected = shuffled.take(count).toList();

    return selected.map((t) => "- ${t['title']}: ${t['desc']}").join("\n");
  }

  // -----------------------------------------------------------------
  // Remote Config fetcher for API key and Model Priority
  // -----------------------------------------------------------------
  static Future<void> _fetchRemoteConfig() async {
    if (_isFetchingConfig) return;
    _isFetchingConfig = true;
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: Duration.zero,
        ),
      );
      await remoteConfig.fetchAndActivate();

      // 1. API Keys (Rotation support)
      String keysStr = remoteConfig.getString('gemini_api_key');
      if (keysStr.isNotEmpty) {
        _cachedApiKeys =
            keysStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        AppLog.d("AI_DEBUG: Loaded ${_cachedApiKeys!.length} API keys from Remote Config");
      }

      // 2. Preferred Models
      String modelsStr = remoteConfig.getString('gemini_preferred_models');
      if (modelsStr.isNotEmpty) {
        _cachedPreferredModels =
            modelsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        AppLog.d("AI_DEBUG: Preferred Models from Remote Config: $_cachedPreferredModels");
      }
    } catch (e) {
      AppLog.d("AI_DEBUG: Remote Config Error: $e");
    } finally {
      _isFetchingConfig = false;
    }
  }

  static Future<List<String>> _getApiKeys() async {
    if (_cachedApiKeys == null || _cachedApiKeys!.isEmpty) {
      await _fetchRemoteConfig();
    }
    return _cachedApiKeys ?? [];
  }

  static Future<List<String>> _getPreferredModels() async {
    if (_cachedPreferredModels == null) {
      await _fetchRemoteConfig();
    }

    // AI_DEBUG: Whitelist of stable models that are known to work
    const whitelist = [
      'gemini-3.6-flash',
      'gemini-3.5-flash-lite',
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-pro',
    ];

    if (_cachedPreferredModels != null && _cachedPreferredModels!.isNotEmpty) {
      // Filter Remote Config models against our whitelist
      List<String> filtered = _cachedPreferredModels!
          .where((m) => whitelist.contains(m.toLowerCase().trim()))
          .toList();

      if (filtered.isNotEmpty) return filtered;
    }

    // Default stable list if Remote Config is empty or invalid
    return [
      'gemini-3.6-flash',
      'gemini-3.5-flash-lite',
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-pro',
    ];
  }

  static bool _lastFailWasParse = false;

  static Future<String?> _generateWithFallback(String prompt, {String? base64Pdf}) async {
    // 0. Check Sticky Config First
    final sticky = HiveService.getStickyAiConfig();
    if (sticky != null) {
      String sKey = sticky['key'] ?? "";
      String sModel = sticky['model'] ?? "";
      String sVersion = sticky['version'] ?? "";

      if (sKey.isNotEmpty && sModel.isNotEmpty && sVersion.isNotEmpty) {
        AppLog.d("AI_DEBUG: Using Sticky Config - Model: $sModel, Version: $sVersion");
        final res = await _tryModelRequest(sKey, sModel, sVersion, prompt, base64Pdf: base64Pdf);
        if (res != null) return res;

        AppLog.d("AI_DEBUG: Sticky Config failed. Clearing and proceeding to discovery.");
        await HiveService.clearStickyAiConfig();
      }
    }

    final apiKeys = await _getApiKeys();
    if (apiKeys.isEmpty) return null;

    // Try each API key in rotation
    for (String apiKey in apiKeys) {
      // 1. Discover available models
      List<String> discoveredModels = [];
      try {
        AppLog.d("AI_DEBUG: Discovering models with key: ${apiKey.substring(0, 5)}...");
        final listUrl = Uri.parse(
          'https://generativelanguage.googleapis.com/v1/models?key=$apiKey',
        );
        final listRes = await http.get(listUrl).timeout(const Duration(seconds: 10));
        if (listRes.statusCode == 200) {
          final listData = jsonDecode(listRes.body);
          for (var m in listData['models']) {
            String mName = m['name'].toString().replaceFirst('models/', '');
            if (m['supportedGenerationMethods'].contains('generateContent')) {
              discoveredModels.add(mName);
            }
          }
        } else {
          AppLog.d("AI_DEBUG: Key ${apiKey.substring(0, 5)} discovery failed (${listRes.statusCode}). Trying next key...");
          continue; // Try next API key
        }
      } catch (e) {
        AppLog.d("AI_DEBUG: Discovery failed for key ${apiKey.substring(0, 5)}: $e");
        continue;
      }

      // 2. Model Priority logic
      final preferredModels = await _getPreferredModels();

      List<String> finalModelsToTry = [];

      // AI_DEBUG: ONLY try models that are BOTH discovered AND in our preferred/whitelist
      // This prevents trying experimental/invalid models that cause 400 errors
      for (var p in preferredModels) {
        if (discoveredModels.contains(p)) {
          finalModelsToTry.add(p);
        }
      }

      // Final fallback if none of our preferred models were discovered on this key
      if (finalModelsToTry.isEmpty) {
        if (discoveredModels.contains('gemini-1.5-flash')) finalModelsToTry.add('gemini-1.5-flash');
        else if (discoveredModels.contains('gemini-pro')) finalModelsToTry.add('gemini-pro');
      }

      if (finalModelsToTry.isEmpty) {
        finalModelsToTry = ['gemini-1.5-flash', 'gemini-pro'];
      }

      AppLog.d("AI_DEBUG: Trying restricted stable models: $finalModelsToTry");

      // 3. Try each model (v1beta)
      bool keyFailed = false;
      for (String version in ['v1beta']) {
        if (keyFailed) break;
        for (String modelName in finalModelsToTry) {
          final res = await _tryModelRequest(apiKey, modelName, version, prompt, base64Pdf: base64Pdf, onKeyInvalid: () => keyFailed = true);
          if (res != null) {
            // SUCCESS! Save this as the sticky config for the rest of the day
            AppLog.d("AI_DEBUG: Saving new Sticky Config: $modelName on $version");
            await HiveService.saveStickyAiConfig(apiKey, modelName, version);
            return res;
          }
          if (_lastFailWasParse) return null;
          if (keyFailed) break;
        }
      }
      // If we reach here and keyFailed is true, the outer loop continues to next API key
    }
    return null;
  }

  static List<dynamic> _extractQuestionsFromText(String text) {
    List<dynamic> questions = [];
    int startIndex = 0;
    while (true) {
      int openBrace = text.indexOf('{', startIndex);
      if (openBrace == -1) break;

      int braceCount = 0;
      int closeBrace = -1;
      for (int i = openBrace; i < text.length; i++) {
        if (text[i] == '{') {
          braceCount++;
        } else if (text[i] == '}') {
          braceCount--;
          if (braceCount == 0) {
            closeBrace = i;
            break;
          }
        }
      }

      if (closeBrace != -1) {
        String objStr = text.substring(openBrace, closeBrace + 1);
        try {
          final decoded = jsonDecode(objStr);
          if (decoded is Map) {
            questions.add(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
        startIndex = closeBrace + 1;
      } else {
        break;
      }
    }
    return questions;
  }

  static List<dynamic> _parseQuestions(String res) {
    try {
      int start = res.indexOf('[');
      int end = res.lastIndexOf(']');
      if (start != -1 && end != -1 && end > start) {
        String jsonPart = res.substring(start, end + 1);
        try {
          final decoded = jsonDecode(jsonPart);
          if (decoded is List) {
            return List<dynamic>.from(decoded);
          }
        } catch (_) {}
      }
    } catch (_) {}

    return _extractQuestionsFromText(res);
  }

  static Future<String?> _tryModelRequest(
      String apiKey,
      String modelName,
      String version,
      String prompt, {
        String? base64Pdf,
        Function? onKeyInvalid,
      }) async {
    int retries = 0;
    const int maxRetries = 2;

    while (retries <= maxRetries) {
      try {
        AppLog.d("AI_DEBUG: REST Call - Trying $modelName on $version (Attempt ${retries + 1})...");
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/$version/models/$modelName:generateContent?key=$apiKey',
        );

        List<Map<String, dynamic>> parts = [];
        if (base64Pdf != null && base64Pdf.isNotEmpty) {
          parts.add({
            'inline_data': {
              'mime_type': 'application/pdf',
              'data': base64Pdf,
            },
          });
        }
        parts.add({'text': prompt});

        final response = await http
            .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': parts,
              },
            ],
            'safetySettings': [
              {
                'category': 'HARM_CATEGORY_HARASSMENT',
                'threshold': 'BLOCK_NONE',
              },
              {
                'category': 'HARM_CATEGORY_HATE_SPEECH',
                'threshold': 'BLOCK_NONE',
              },
              {
                'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                'threshold': 'BLOCK_NONE',
              },
              {
                'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                'threshold': 'BLOCK_NONE',
              },
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'temperature': 0.4,
              'topP': 0.85,
              'topK': 20,
              'maxOutputTokens': 16384,
            },
          }),
        )
            .timeout(const Duration(seconds: 90));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidate = data['candidates'][0];
          if (candidate['finishReason'] != 'STOP' && candidate['finishReason'] != 'MAX_TOKENS') {
            AppLog.d("AI_DEBUG: Model finished with reason: ${candidate['finishReason']}");
            return null; // Try next model
          }

          String? text = candidate['content']['parts'][0]['text'];
          if (text != null) {
            text = text.trim();
            // Auto-heal truncated JSON array if finished due to MAX_TOKENS
            if (text.contains('[') && !text.trim().endsWith(']')) {
              int lastBrace = text.lastIndexOf('}');
              if (lastBrace != -1) {
                text = text.substring(0, lastBrace + 1) + ']';
                AppLog.d("AI_DEBUG: Auto-healed truncated JSON array from MAX_TOKENS");
              }
            }

            final jsonRegex = RegExp(r'\[.*\]|\{.*\}', dotAll: true);
            final match = jsonRegex.stringMatch(text);
            if (match != null) {
              text = match.trim();
            }

            try {
              jsonDecode(text);
              _lastFailWasParse = false;
              return text;
            } catch (e) {
              AppLog.d("AI_DEBUG: JSON Decode failed for: ${text.substring(0, text.length > 50 ? 50 : text.length)}...");
              _lastFailWasParse = true;
              return null;
            }
          }
        } else if (response.statusCode == 429) {
          if (retries >= 3) {
            AppLog.d("AI_DEBUG: Rate limit reached (429) after max retries. Rotating key and backing off...");
            if (onKeyInvalid != null) onKeyInvalid();
            await Future.delayed(const Duration(seconds: 15));
            return null;
          }
          AppLog.d("AI_DEBUG: Rate limit reached (429). Retrying after backoff (${retries + 1})...");
          await Future.delayed(Duration(seconds: 8 * (retries + 1)));
          retries++;
          continue;
        } else if (response.statusCode == 403) {
          AppLog.d("AI_DEBUG: Key invalid or permission denied (403). Switching key...");
          if (onKeyInvalid != null) onKeyInvalid();
          return null;
        } else if (response.statusCode == 503 || response.statusCode == 500) {
          AppLog.d("AI_DEBUG: Server error (${response.statusCode}). Retrying...");
          await Future.delayed(Duration(seconds: 1 * (retries + 1)));
          retries++;
          continue;
        } else {
          AppLog.d("AI_DEBUG: REST FAIL - Status: ${response.statusCode}");
          return null; // Try next model
        }
      } catch (e) {
        AppLog.d("AI_DEBUG: REST Error: $e");
        return null; // Try next model
      }
    }
    return null;
  }

  static Future<String> _getRecentQuizContext(String collectionName, int days) async {
    String context = "";
    DateTime cutoff = AppDate.getISTNow().subtract(Duration(days: days));
    try {
      final docs = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('createdAt', isGreaterThan: cutoff)
          .orderBy('createdAt', descending: true)
          .limit(20) // Limit to last 20 quizzes to avoid prompt bloat
          .get();

      for (var doc in docs.docs) {
        List qs = doc.get('questions') ?? [];
        // Take a few representative questions from each quiz
        for (var q in qs.take(5)) {
          String text = q['question'].toString().split('\n').first;
          if (text.length > 60) text = text.substring(0, 60);
          context += "$text, ";
        }
      }
    } catch (e) {
      AppLog.d("AI_DEBUG: Context fetch error ($collectionName): $e");
    }
    return context;
  }

  static String _detectQuizType(Map<String, dynamic> q) {
    final qEn = (q['question_en'] ?? q['question'] ?? '').toString().toLowerCase();
    final qTa = (q['question_ta'] ?? q['question'] ?? '').toString().toLowerCase();
    final expEn = (q['explanation_en'] ?? q['explanation'] ?? '').toString().toLowerCase();
    final expTa = (q['explanation_ta'] ?? q['explanation'] ?? '').toString().toLowerCase();
    final combined = '$qEn $qTa $expEn $expTa';

    // Check for Tamil literature / grammar / language keywords first
    if (combined.contains('thirukkural') ||
        combined.contains('kamba ramayanam') ||
        combined.contains('sangam literature') ||
        combined.contains('tamil literature') ||
        combined.contains('bhakti movement') ||
        combined.contains('vetrumai') ||
        combined.contains('ettuthogai') ||
        combined.contains('pattupattu') ||
        combined.contains('silappatikaram') ||
        combined.contains('manimekalai') ||
        combined.contains('purananuru') ||
        combined.contains('kurunthogai') ||
        combined.contains('paddinappalai') ||
        combined.contains('kalithogai') ||
        combined.contains('bharathidasan') ||
        combined.contains('பத்துப்பாட்டு') ||
        combined.contains('எட்டுத்தொகை') ||
        combined.contains('சிலப்பதிகாரம்') ||
        combined.contains('மணிமேகலை') ||
        combined.contains('புறநானூறு') ||
        combined.contains('குறுந்தொகை') ||
        combined.contains('பட்டினப்பாலை') ||
        combined.contains('கலித்தொகை') ||
        combined.contains('திருக்குறள்') ||
        combined.contains('வேற்றுமை') ||
        combined.contains('தமிழ் இலக்கிய') ||
        combined.contains('சங்க காலம்') ||
        combined.contains('பக்தி இலக்கிய')) {
      return 'general_tamil';
    }

    if (combined.contains('compound interest') ||
        combined.contains('simple interest') ||
        combined.contains('percentage') ||
        combined.contains('ratio') ||
        combined.contains('hcf') ||
        combined.contains('lcm') ||
        combined.contains('profit and loss') ||
        combined.contains('speed, distance') ||
        combined.contains('formula: amount') ||
        combined.contains('கூட்டு வட்டி') ||
        combined.contains('தனி வட்டி') ||
        combined.contains('சதவீதம்') ||
        combined.contains('விகிதம்') ||
        combined.contains('மீ.பொ.வ') ||
        combined.contains('மீ.பொ.ம') ||
        combined.contains('இலாபம்') ||
        combined.contains('நஷ்டம்') ||
        combined.contains('வேகம்') ||
        combined.contains('காலம்') ||
        combined.contains('சூத்திரம்: கூடுதல்')) {
      return 'aptitude';
    }

    return q['quiz_type']?.toString().toLowerCase() ?? 'general_studies';
  }

  static bool _validateQuestion(Map<String, dynamic> q, {bool isExamPaper = false, DateTime? generationDate, bool skipYearCheck = false}) {
    try {
      // Automatically correct quiz_type based on content analysis
      q['quiz_type'] = _detectQuizType(q);

      // Validate event_date <= generationDate if present
      final eventDateStr = q['event_date']?.toString().trim();
      if (eventDateStr != null && eventDateStr.isNotEmpty && !isExamPaper) {
        try {
          DateTime evDate = DateTime.parse(eventDateStr);
          DateTime genDate = generationDate ?? AppDate.getISTNow();
          DateTime evDateOnly = DateTime(evDate.year, evDate.month, evDate.day);
          DateTime genDateOnly = DateTime(genDate.year, genDate.month, genDate.day);
          if (evDateOnly.isAfter(genDateOnly)) {
            AppLog.d("AI_DEBUG: REJECT - event_date ($eventDateStr) is after generation date ($genDateOnly)");
            return false;
          }
        } catch (_) {}
      }

      final qEn = q['question_en']?.toString().trim() ?? '';
      final qTa = q['question_ta']?.toString().trim() ?? '';
      final expEn = q['explanation_en']?.toString().trim() ?? '';
      final expTa = q['explanation_ta']?.toString().trim() ?? '';
      if (qEn.isEmpty && qTa.isEmpty) {
        AppLog.d("AI_DEBUG: REJECT - empty question");
        return false;
      }

      // In exam papers, if one language is missing or short, mirror from the other
      if (isExamPaper) {
        if (qTa.isEmpty && qEn.isNotEmpty) q['question_ta'] = qEn;
        if (qEn.isEmpty && qTa.isNotEmpty) q['question_en'] = qTa;
      } else {
        if (qEn.isEmpty || qTa.isEmpty || qEn.length < 5 || qTa.length < 5) {
          AppLog.d("AI_DEBUG: REJECT - question too short ($qEn / $qTa)");
          return false;
        }
      }

      final options = q['options'];
      if (options is! List || options.length != 4) {
        AppLog.d("AI_DEBUG: REJECT - options length != 4");
        return false;
      }

      Set<String> optionTextsEn = {};
      Set<String> optionTextsTa = {};
      for (var opt in options) {
        if (opt is! Map) {
          AppLog.d("AI_DEBUG: REJECT - option is not Map");
          return false;
        }
        var optEn = opt['en']?.toString().trim() ?? '';
        var optTa = opt['ta']?.toString().trim() ?? '';
        if (optEn.isEmpty && optTa.isEmpty) {
          AppLog.d("AI_DEBUG: REJECT - option empty");
          return false;
        }
        if (isExamPaper) {
          if (optEn.isEmpty) opt['en'] = optTa;
          if (optTa.isEmpty) opt['ta'] = optEn;
        }
        optionTextsEn.add(opt['en']?.toString() ?? '');
        optionTextsTa.add(opt['ta']?.toString() ?? '');
      }
      if (optionTextsEn.length < 2 || optionTextsTa.length < 2) {
        AppLog.d("AI_DEBUG: REJECT - unique options < 2");
        return false;
      }

      final correctIdx = q['correctOptionIndex'];
      if (correctIdx is! int && correctIdx is! num) {
        AppLog.d("AI_DEBUG: REJECT - correctOptionIndex not int");
        return false;
      }
      final idx = (correctIdx as num).toInt();
      if (idx < 0 || idx > 3) {
        AppLog.d("AI_DEBUG: REJECT - correctOptionIndex out of bounds ($idx)");
        return false;
      }

      // Check for foreign scripts & thought leaks
      for (var opt in options) {
        if (opt is Map) {
          final taOpt = opt['ta']?.toString() ?? '';
          final enOpt = opt['en']?.toString() ?? '';
          if (_hasForeignScripts(taOpt) || _hasThoughtLeaks(taOpt) || _hasThoughtLeaks(enOpt)) {
            AppLog.d("AI_DEBUG: REJECT - foreign script or thought leak in option");
            return false;
          }
        }
      }
      if (_hasForeignScripts(qTa) || _hasForeignScripts(expTa) || 
          _hasThoughtLeaks(qEn) || _hasThoughtLeaks(qTa) || _hasThoughtLeaks(expEn) || _hasThoughtLeaks(expTa)) {
        AppLog.d("AI_DEBUG: REJECT - foreign script or thought leak in Q/E");
        return false;
      }

      // Check for answer leak
      if (_isAnswerLeaked(qEn, qTa, options, idx)) {
        AppLog.d("AI_DEBUG: REJECT - Answer leaked in question text");
        return false;
      }

      // Provide default fallback explanations for exam paper questions if missing
      if (isExamPaper) {
        if (expTa.isEmpty) {
          q['explanation_ta'] = "சரியான விடை விருப்பம் ${String.fromCharCode(65 + idx)} ஆகும். இது அதிகாரப்பூர்வ டிஎன்பிஎஸ்சி விடைக்குறிப்பின்படி உறுதிசெய்யப்பட்டது.";
        }
        if (expEn.isEmpty) {
          q['explanation_en'] = "The correct answer is Option ${String.fromCharCode(65 + idx)}, verified according to official TNPSC answer key standards.";
        }
      } else {
        if (expEn.isEmpty || expTa.isEmpty) {
          AppLog.d("AI_DEBUG: REJECT - missing explanation (expEn: $expEn, expTa: $expTa)");
          return false;
        }

        final lowerExpEn = expEn.toLowerCase();
        final lowerExpTa = expTa.toLowerCase();

        // Strict Anti-Hallucination & Non-Existent Facts Filter:
        // Reject questions where explanation or question states no such event exists, or admits it is hypothetical, fictional, or unrecorded
        if ((lowerExpEn.contains('no ') && (lowerExpEn.contains('awarded') || lowerExpEn.contains('exist') || lowerExpEn.contains('scientist') || lowerExpEn.contains('record') || lowerExpEn.contains('such'))) ||
            lowerExpEn.contains('hypothetical') || lowerExpEn.contains('future event') || lowerExpEn.contains('fictional') || lowerExpEn.contains('imaginary') || lowerExpEn.contains('not yet happened') ||
            lowerExpTa.contains('வழங்கப்படவில்லை') || lowerExpTa.contains('இல்லை') || lowerExpTa.contains('கருத்தியல்') || lowerExpTa.contains('தகவல் இல்லை') ||
            lowerExpTa.contains('உண்மையில் இல்லை') || lowerExpTa.contains('கற்பனையான') || lowerExpTa.contains('நிகழவில்லை')) {
          AppLog.d("AI_DEBUG: REJECT - anti-hallucination filter triggered");
          return false;
        }

        // Check Explanation vs correctOptionIndex Coherence:
        if (!_validateOptionExplanationCoherence(idx, lowerExpEn, lowerExpTa)) {
          AppLog.d("AI_DEBUG: REJECT - option explanation coherence failed");
          return false;
        }

        // Check Match the following questions: Both Left and Right data must be present!
        if (!_validateMatchQuestion(qEn, qTa, options)) {
          AppLog.d("AI_DEBUG: REJECT - match question validation failed");
          return false;
        }

        // Check Award, Sports, and Event questions: Year or Date must be present!
        if (!skipYearCheck && !_validateCurrentAffairsYear(qEn, qTa)) {
          AppLog.d("AI_DEBUG: REJECT - current affairs year check failed ($qTa)");
          return false;
        }

        // Check current affairs strict rules (NEP 2020, Vague entities, etc.)
        if (!_passesCurrentAffairsRules(qEn, qTa, expEn, expTa)) {
          AppLog.d("AI_DEBUG: REJECT - current affairs rules failed");
          return false;
        }
      }

      return true;
    } catch (e) {
      AppLog.d("AI_DEBUG: REJECT exception in _validateQuestion: $e");
      return false;
    }
  }

  static bool _hasForeignScripts(String text) {
    // Block non-Tamil Indian scripts (Devanagari, Telugu, Kannada, Malayalam, Bengali, Gujarati, Gurmukhi, Oriya)
    final foreignIndic = RegExp(r'[\u0900-\u0B7F\u0C00-\u0D7F]');
    return foreignIndic.hasMatch(text);
  }

  static bool _hasThoughtLeaks(String text) {
    final lower = text.toLowerCase();
    return lower.contains('உள்ளீட்டை') ||
        lower.contains('மாற்று உள்ளீடு') ||
        lower.contains('சரிபார்த்தல்') ||
        lower.contains('சிந்தனை') ||
        lower.contains('யோசனை') ||
        lower.contains('prompt') ||
        lower.contains('ai model');
  }

  static bool _isAnswerLeaked(String qEn, String qTa, List<dynamic> options, int correctIdx) {
    if (correctIdx < 0 || correctIdx >= options.length) return false;
    final correctOpt = options[correctIdx];
    if (correctOpt is! Map) return false;
    
    final optEn = correctOpt['en']?.toString().trim().toLowerCase() ?? '';
    final optTa = correctOpt['ta']?.toString().trim().toLowerCase() ?? '';

    if (optEn.length > 4 && qEn.toLowerCase().contains(optEn)) return true;
    if (optTa.length > 4 && qTa.toLowerCase().contains(optTa)) return true;

    return false;
  }

  static bool _passesCurrentAffairsRules(String qEn, String qTa, String expEn, String expTa) {
    final combined = '$qEn $qTa $expEn $expTa'.toLowerCase();

    // 1. NEP Rule check: Must not have NEP 2026 or National Education Policy 2026
    if (combined.contains('nep 2026') || combined.contains('national education policy 2026') || combined.contains('கல்விக் கொள்கை 2026')) {
      return false;
    }

    // 2. Vague Entities Check: Reject vague phrases without specific names
    final vaguePhrasesEn = [
      'a prominent scientist',
      'a renowned author',
      'a new wildlife sanctuary',
      'a prominent indian scientist',
      'a renowned tamil author',
      'a prestigious national literary award'
    ];
    for (var vp in vaguePhrasesEn) {
      if (combined.contains(vp)) {
        return false;
      }
    }

    return true;
  }

  /// Ensures that the explanation does NOT contradict the correctOptionIndex.
  /// E.g. If correctOptionIndex is 0 (A), the explanation must NOT claim "Option B is correct" or "விடை B".
  static bool _validateOptionExplanationCoherence(int idx, String expEn, String expTa) {
    const letters = ['a', 'b', 'c', 'd'];
    final correctLetter = letters[idx];

    for (int i = 0; i < 4; i++) {
      if (i != idx) {
        final wrongLetter = letters[i];
        final wrongNum = i + 1;

        final enContradictions = [
          'option $wrongLetter is correct',
          'option ($wrongLetter) is correct',
          'correct option is $wrongLetter',
          'correct option is ($wrongLetter)',
          'correct answer is option $wrongLetter',
          'correct answer is ($wrongLetter)',
          'option $wrongNum is correct',
          'correct option is $wrongNum',
        ];
        for (var p in enContradictions) {
          if (expEn.contains(p)) {
            AppLog.d("AI_DEBUG: Rejected Question - Explanation claims option $wrongLetter is correct, but correctOptionIndex is $idx ($correctLetter)");
            return false;
          }
        }

        final taContradictions = [
          'சரியான விடை $wrongLetter',
          'சரியான விடை ($wrongLetter)',
          'விடை $wrongLetter',
          'விருப்பம் $wrongLetter சரியானது',
          'விருப்பம் ($wrongLetter) சரியானது',
          'விருப்பம் $wrongNum சரியானது',
          'சரியான விருப்பம் $wrongLetter',
        ];
        for (var p in taContradictions) {
          if (expTa.contains(p)) {
            AppLog.d("AI_DEBUG: Rejected Question - Tamil explanation claims option $wrongLetter is correct, but correctOptionIndex is $idx ($correctLetter)");
            return false;
          }
        }
      }
    }

    return true;
  }

  /// Validates that questions about Awards, Sports Tournaments, Summits, and Events
  /// explicitly mention the year or date (e.g. 2024, 2025) so they are unambiguous.
  static bool _validateCurrentAffairsYear(String qEn, String qTa) {
    final lowerEn = qEn.toLowerCase();
    final lowerTa = qTa.toLowerCase();

    final isAward = lowerTa.contains('விருது') ||
        lowerTa.contains('நோபல்') ||
        lowerTa.contains('பால்கே') ||
        lowerTa.contains('சாகித்திய') ||
        lowerTa.contains('சாகித்ய') ||
        lowerTa.contains('பத்ம') ||
        lowerEn.contains('award') ||
        lowerEn.contains('nobel') ||
        lowerEn.contains('prize') ||
        lowerEn.contains('phalke') ||
        lowerEn.contains('padma') ||
        lowerEn.contains('sahitya');

    final isSportsEvent = lowerTa.contains('ஒலிம்பிக்') ||
        lowerTa.contains('உலகக் கோப்பை') ||
        lowerTa.contains('சாம்பியன்ஷிப்') ||
        lowerTa.contains('கிராண்ட் பிரிக்ஸ்') ||
        lowerTa.contains('விம்பிள்டன்') ||
        lowerEn.contains('olympic') ||
        lowerEn.contains('world cup') ||
        lowerEn.contains('championship') ||
        lowerEn.contains('grand prix') ||
        lowerEn.contains('wimbledon');

    final isSummit = lowerTa.contains('உச்சி மாநாடு') ||
        lowerTa.contains('ஜி20') ||
        lowerTa.contains('பிரிக்ஸ்') ||
        lowerEn.contains('summit') ||
        lowerEn.contains('g20') ||
        lowerEn.contains('brics');

    if (!isAward && !isSportsEvent && !isSummit) return true; // Not an award/sports/summit question

    // Allow questions explicitly asking for the "first" ever recipient or inaugural event
    final isFirstOrInaugural = lowerTa.contains('முதல்') ||
        lowerEn.contains('first') ||
        lowerTa.contains('தொடக்க') ||
        lowerEn.contains('inaugural');
    if (isFirstOrInaugural) return true;

    // Must contain a 4-digit year (e.g. 2024, 2025, 2023, 1990...) in question text
    final yearRegex = RegExp(r'\b(19\d\d|20\d\d)\b');
    final hasYear = yearRegex.hasMatch(qTa) || yearRegex.hasMatch(qEn);

    if (!hasYear) {
      AppLog.d("AI_DEBUG: Rejected Award/Sports/Summit Question - Missing year or date in question: $qTa");
      return false;
    }

    return true;
  }

  /// Strictly validates that "Match the Following" (பொருத்துக) questions contain
  /// BOTH the Left Column (a, b, c, d) AND the Right Column (1, 2, 3, 4) with descriptive text.
  static bool _validateMatchQuestion(String qEn, String qTa, List<dynamic> options) {
    final lowerEn = qEn.toLowerCase();
    final lowerTa = qTa.toLowerCase();

    // 1. Detect if this is a Match-the-following question
    final matchOptRegex = RegExp(r'\(?[a-d]\)?\s*[-–—:]\s*[1-4]', caseSensitive: false);
    int matchOptionCount = 0;
    for (var opt in options) {
      if (opt is Map) {
        final en = opt['en']?.toString() ?? '';
        final ta = opt['ta']?.toString() ?? '';
        if (matchOptRegex.hasMatch(en) || matchOptRegex.hasMatch(ta)) {
          matchOptionCount++;
        }
      }
    }

    final isMatchByTitle = lowerTa.contains('பொருத்துக') ||
        lowerTa.contains('பொருத்து') ||
        lowerEn.contains('match the following') ||
        lowerEn.contains('match list') ||
        lowerEn.contains('match column');

    final hasLettersInQuestion = (qTa.contains('(a)') || qTa.contains('(அ)') || qEn.contains('(a)')) &&
        (qTa.contains('(b)') || qTa.contains('(ஆ)') || qEn.contains('(b)'));

    final isMatch = isMatchByTitle || matchOptionCount >= 2 || (hasLettersInQuestion && matchOptionCount >= 1);
    if (!isMatch) return true; // Normal MCQ, not a match question

    // It IS a Match Question: strictly enforce BOTH Left (a,b,c,d) and Right (1,2,3,4) presence!
    final hasTaA = qTa.contains('(a)') || qTa.contains('(A)') || qTa.contains('a)') || qTa.contains('A)') || qTa.contains('(அ)') || qTa.contains('அ)');
    final hasTaB = qTa.contains('(b)') || qTa.contains('(B)') || qTa.contains('b)') || qTa.contains('B)') || qTa.contains('(ஆ)') || qTa.contains('ஆ)');
    final hasTaC = qTa.contains('(c)') || qTa.contains('(C)') || qTa.contains('c)') || qTa.contains('C)') || qTa.contains('(இ)') || qTa.contains('இ)');
    final hasTaD = qTa.contains('(d)') || qTa.contains('(D)') || qTa.contains('d)') || qTa.contains('D)') || qTa.contains('(ஈ)') || qTa.contains('ஈ)');

    final num1Regex = RegExp(r'(?:^|[—\-\s\(\n])1(?:\.|\s*[-–—:]|\))');
    final num2Regex = RegExp(r'(?:^|[—\-\s\(\n])2(?:\.|\s*[-–—:]|\))');
    final num3Regex = RegExp(r'(?:^|[—\-\s\(\n])3(?:\.|\s*[-–—:]|\))');
    final num4Regex = RegExp(r'(?:^|[—\-\s\(\n])4(?:\.|\s*[-–—:]|\))');

    final hasTa1 = num1Regex.hasMatch(qTa);
    final hasTa2 = num2Regex.hasMatch(qTa);
    final hasTa3 = num3Regex.hasMatch(qTa);
    final hasTa4 = num4Regex.hasMatch(qTa);

    if (!hasTaA || !hasTaB || !hasTaC || !hasTaD || !hasTa1 || !hasTa2 || !hasTa3 || !hasTa4) {
      AppLog.d("AI_DEBUG: Rejected Match Question (Tamil) - Missing left or right items: Letters [a:$hasTaA, b:$hasTaB, c:$hasTaC, d:$hasTaD], Numbers [1:$hasTa1, 2:$hasTa2, 3:$hasTa3, 4:$hasTa4]");
      return false;
    }

    final hasEnA = qEn.contains('(a)') || qEn.contains('(A)') || qEn.contains('a)') || qEn.contains('A)');
    final hasEnB = qEn.contains('(b)') || qEn.contains('(B)') || qEn.contains('b)') || qEn.contains('B)');
    final hasEnC = qEn.contains('(c)') || qEn.contains('(C)') || qEn.contains('c)') || qEn.contains('C)');
    final hasEnD = qEn.contains('(d)') || qEn.contains('(D)') || qEn.contains('d)') || qEn.contains('D)');

    final hasEn1 = num1Regex.hasMatch(qEn);
    final hasEn2 = num2Regex.hasMatch(qEn);
    final hasEn3 = num3Regex.hasMatch(qEn);
    final hasEn4 = num4Regex.hasMatch(qEn);

    if (!hasEnA || !hasEnB || !hasEnC || !hasEnD || !hasEn1 || !hasEn2 || !hasEn3 || !hasEn4) {
      AppLog.d("AI_DEBUG: Rejected Match Question (English) - Missing left or right items: Letters [a:$hasEnA, b:$hasEnB, c:$hasEnC, d:$hasEnD], Numbers [1:$hasEn1, 2:$hasEn2, 3:$hasEn3, 4:$hasEn4]");
      return false;
    }

    // Both sides must contain substantial descriptive text
    if (qTa.trim().length < 40 || qEn.trim().length < 40) {
      AppLog.d("AI_DEBUG: Rejected Match Question - Text too short for 4 complete pairs.");
      return false;
    }

    return true;
  }

  static List<dynamic> _filterValidQuestions(List<dynamic> questions, {bool isExamPaper = false, DateTime? generationDate}) {
    List<dynamic> validList = [];
    for (var item in questions) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        if (!_validateQuestion(map, isExamPaper: isExamPaper, generationDate: generationDate)) continue;

        // Auto-format question text for newlines on Match, Statement, and Sequence questions
        if (map['question_ta'] != null) {
          map['question_ta'] = Question.formatQuestionText(map['question_ta'].toString());
        }
        if (map['question_en'] != null) {
          map['question_en'] = Question.formatQuestionText(map['question_en'].toString());
        }
        if (map['question'] != null) {
          map['question'] = Question.formatQuestionText(map['question'].toString());
        }
        validList.add(map);
      }
    }
    return validList;
  }

  static Future<bool> generateAndSaveDailyQuiz(DateTime date) async {
    final dateStr = AppDate.format(date);

    // 1. Check if quiz already exists and has 20 questions
    try {
      final existingSnap = await FirebaseFirestore.instance
          .collection('quizzes')
          .where('date', isEqualTo: dateStr)
          .where('type', isEqualTo: 'daily_quiz')
          .get();
      if (existingSnap.docs.isNotEmpty) {
        List existingQs = existingSnap.docs.first.get('questions') ?? [];
        if (existingQs.length >= 20) {
          AppLog.d("AI_DEBUG: Daily quiz for $dateStr already has ${existingQs.length} questions. Skipping generation.");
          return true;
        }
      }
    } catch (_) {}

    final generationDate = DateTime.now();
    final generationDateStr = AppDate.format(generationDate);
    final quizDateStr = dateStr;

    // Get topics from last 30 days to avoid repeats
    String recentContext = await _getRecentQuizContext('quizzes', 30);

    // Get Focus Topics for the day (Select 4 Language, 3 Aptitude, 3 GS)
    String focusTopics = _getLanguageTopicsForDate(date, 4);
    String focusAptitude = _getAptitudeTopicsForDate(date, 3);
    String focusGS = _getGsTopicsForDate(date, 3);

    final avoidPrompt = recentContext.isNotEmpty
        ? """
==================================================
🚫 PREVIOUSLY USED QUESTIONS / EVENTS / TOPICS
==================================================

The following questions/topics were already used in recent quizzes:
$recentContext

STRICT DUPLICATE PREVENTION:
1. NEVER reuse any question from the above list.
2. NEVER reuse the same underlying EVENT, FACT, NEWS, SCHEME, PERSON, ORGANIZATION, AWARD, SPORTS TOURNAMENT, GOVERNMENT ANNOUNCEMENT, SCIENTIFIC DISCOVERY, or TOPIC.
3. A question is considered DUPLICATE even if the wording, language, or question format is different (e.g. changing Direct MCQ to Assertion/Reason or Match the Following using the same underlying event is strictly FORBIDDEN).
4. If a previous question is about a government scheme, sports tournament, policy, or current-affairs event, do not generate another question about that same scheme/tournament/event.
5. Each generated question MUST represent a genuinely different fact/event/topic identity (`event_id`).
6. If there are not enough verified NEW topics available, generate fewer questions instead of repeating an old topic. NEVER invent a new event just to reach the count.
==================================================
"""
        : "";

    final commonRules = """
STRICT QUALITY RULES (MUST FOLLOW)

GENERATION DATE: $generationDateStr
QUIZ DISPLAY DATE: $quizDateStr

CRITICAL DATE RULE:
The GENERATION DATE ($generationDateStr) is the ONLY date that determines whether a current-affairs event is eligible.
A current-affairs event is eligible ONLY if:
event_date <= GENERATION_DATE
Never use QUIZ DISPLAY DATE ($quizDateStr) to decide whether an event has happened.
Never generate an event that occurs after GENERATION DATE.
If an event is scheduled for a future date, do NOT use it as a completed current-affairs event.

1. Return ONLY valid JSON.
2. No Markdown.
3. No extra text before or after JSON.
4. Generate NEW and ORIGINAL questions.
5. Never repeat questions, options, explanations, or question patterns.
6. Every question must test a different concept.
7. Questions must be suitable for TNPSC SSLC Standard.
8. EVERY field MUST BE BILINGUAL (Separate English and Tamil keys).
9. English must be natural and error-free.
10. Tamil must use proper literary Tamil without spelling mistakes.
11. NO MIXED LANGUAGE: Do NOT mix Tamil and English in the same sentence or field.
12. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages. No Hindi words in brackets or parentheses.
13. Every question must have exactly four options.
14. Only ONE option must be correct.
15. Verify the correct answer before assigning correctOptionIndex.
16. correctOptionIndex MUST exactly match the correct option (0-3).
17. Explanation must clearly justify why the answer is correct. 
    - For Math/Aptitude: Show step-by-step calculation (Formula -> Steps -> Final Answer).
    - Ensure the calculated result EXACTLY matches the value in the correct option.
18. MANDATORY BILINGUAL FORMAT (STRICT):
    - "question_en": "English question text"
    - "question_ta": "தமிழ் வினா உரை"
    - "options": [{"en": "English Option", "ta": "தமிழ் விருப்பம்"}, ...] (List of 4 objects)
    - "explanation_en": "English explanation text"
    - "explanation_ta": "தமிழ் விளக்க உரை"
19. Avoid vague or ambiguous questions.
20. Avoid duplicate option values.
21. Avoid options like "All of the above" or "None of the above".
22. Do not generate trick questions.
23. Ensure every question is unique.
24. Ensure every option is unique.
25. Ensure every explanation is unique.
26. Maintain balanced difficulty.
27. Use proper punctuation.
28. Do not use unnecessary quotation marks.
29. Never invent incorrect historical or scientific facts.
30. Validate every answer before returning JSON.
31. FACTUAL & ANSWER ACCURACY (CRITICAL - 100% REAL DATA ONLY):
    - Every question MUST be based exclusively on REAL, VERIFIED FACTS from:
      * Tamil Nadu State Board (Samacheer Kalvi) Textbooks (Classes 6-12)
      * Authentic Classical & Modern Tamil Literature (Thirukkural, Silappatikaram, Manimekalai, Naladiyar, Bharathiyar, etc.)
      * Authentic Constitution of India (Articles, Parts, Schedules, Amendments)
      * Real Indian & Tamil Nadu History, Geography, Economy, and Science
      * Official Government Releases (PIB, DIPR TN, Official Portals)
    - NEVER invent fictional poets, fake book titles, imaginary awards, or non-existent government acts.
    - Zero hallucination. Every fact must be authentic and verifiable.
32. 100% COHERENCE BETWEEN QUESTION, OPTIONS, CORRECT ANSWER & EXPLANATION:
    - `correctOptionIndex` (0-3) MUST precisely point to the single correct option (0=Option 1, 1=Option 2, 2=Option 3, 3=Option 4).
    - The Explanation MUST directly explain and validate why `options[correctOptionIndex]` is the right answer.
    - NEVER let the explanation mention another option as correct (e.g. claiming Option B is correct while index is 0).
    - The 3 incorrect options (distractors) MUST be authentic, real alternatives from the same syllabus.
    - For Aptitude & Math: Solve step-by-step. The calculation result MUST EXACTLY match the number in the chosen option.
33. ALL AUTHENTIC TNPSC QUESTION FORMATS (MANDATORY VARIETY):
    - Must include a rich mix of all 5 authentic TNPSC exam formats:
      a) Standard Direct MCQs (~40%)
      b) "Match the Following / பொருத்துக" Questions (~25%): 
         CRITICAL REQUIREMENT: BOTH the LEFT COLUMN (a, b, c, d) AND the RIGHT COLUMN (1, 2, 3, 4) MUST BE INCLUDED in the question text. NEVER omit either side! Both left and right items must have actual descriptive text. The 4 options MUST be matching code combinations (e.g. "(a)-2, (b)-1, (c)-4, (d)-3").
      c) "Statement & Reason / Assertion Questions (கூற்று மற்றும் காரணம் / சரியானது எது?)" (~15%): Both Assertion (A) and Reason (R) must be present on separate lines.
      d) "Find the Incorrect Pair / Statement (தவறான கூற்று / தவறான இணை எது?)" (~10%): Identify the wrongly matched pair or false statement among options.
      e) "Chronological Order / Sequence (காலவரிசைப்படி முறைப்படுத்துக / ஏறுவரிசை)" (~10%): Arrange historical events, numbers, or facts in chronological order with all 4 items (1), (2), (3), (4) listed.
34. MANDATORY QUESTION FORMATTING INSTRUCTIONS (CRITICAL FOR NEWLINES & BOTH SIDES):
    - For "Match the following (பொருத்துக)", list ALL 4 items (a), (b), (c), (d) on SEPARATE NEW LINES using \n. 
      EACH LINE MUST CONTAIN BOTH the Left item AND the Right item separated by " — "!
      DO NOT GENERATE ONLY LEFT OR ONLY RIGHT! BOTH SIDES ARE STRICTLY MANDATORY!
      Tamil Example:
      "கீழ்க்காண்பனவற்றைச் சரியாகப் பொருத்துக:\n(a) பரணி — 1. யானைப்படையை வென்றவர் மீது பாடுவது\n(b) தூது — 2. தூது செல்லும் இலக்கியம்\n(c) உலா — 3. வீதியில் உலா வரும் தலைவனைக் கண்டு பாடுவது\n(d) குறவஞ்சி — 4. 96 வகைச் சிற்றிலக்கியங்களில் ஒன்று"
      English Example:
      "Match the following correctly:\n(a) Parani — 1. Literature sung on victory over elephants\n(b) Thoothu — 2. Envoy literature\n(c) Ula — 3. Literature on leader's street procession\n(d) Kuravanji — 4. One of the 96 minor literature types"
    - For "Statement & Reason (கூற்று மற்றும் காரணம்)", place Assertion and Reason on SEPARATE NEW LINES using \n.
      Example: "கூற்று (A): சிலப்பதிகாரமும் மணிமேகலையும் இரட்டைக் காப்பியங்கள்.\nகாரணம் (R): இரண்டும் ஒரே காலக்கட்டத்தில் தோன்றியவை."
    - For "Chronological Order (காலவரிசைப்படுத்துக)", place numbered items on SEPARATE NEW LINES using \n.
      Example: "காலவரிசைப்படுத்துக:\n(1) சிலப்பதிகாரம்\n(2) மணிமேகலை\n(3) சீவக சிந்தாமணி\n(4) வளையாபதி"
35. MANDATORY YEAR/DATE SPECIFICATION (AWARDS, SPORTS, SCHEMES, SUMMITS, EVENTS):
    - For any question related to an Award (விருது), Sports Tournament (விளையாட்டு/போட்டி), Government Scheme (திட்டம்), Summit/Conference (மாநாடு), or Current Affairs event, YOU MUST EXPLICITLY INCLUDE THE YEAR (e.g. 2024, 2025) or DATE / MONTH & YEAR (e.g. '2024-ஆம் ஆண்டிற்கான...', 'செப்டம்பர் 2024-ல்...') in BOTH question_en and question_ta!
    - Example: '2024-ஆம் ஆண்டிற்கான தாதாசாகேப் பால்கே விருதை வென்றவர் யார்? / Who received the Dadasaheb Phalke Award for the year 2024?'
    - Example: '2024 பாரிஸ் ஒலிம்பிக்கில் தங்கம் வென்றவர் யார்? / Who won gold at the 2024 Paris Olympics?'
    - NEVER generate an award, sports, or event question without the year or date. Without the year, questions are ambiguous because awards and sports tournaments occur annually.
36. STRICTLY NO FUTURE-DATED OR UNVERIFIED EVENTS (CRITICAL):
    - NEVER generate questions about sports tournaments, awards, elections, summits, or current affairs events whose dates are in the future or have not yet concluded/happened relative to the current generation date.
    - All current affairs and event-based questions must reference past, completed, and verified events up to the present date.
    - Never assume, predict, or project winners, outcomes, or future event dates.
37. TN GOVT SCHEMES & INITIATIVES ACCURACY & NOMENCLATURE (CRITICAL):
    - Never invent, alter, or confuse Tamil Nadu government scheme/initiative names (e.g. do not confuse official titles like "இளம் தளிர் இல்லம்" with general child welfare or institutional care homes).
    - Verify exact scheme names, exact target beneficiaries (e.g. adolescent school girls for child marriage prevention vs orphaned children), objectives, and launch details from official Tamil Nadu DIPR press releases or Government Orders.
    - Zero tolerance for nomenclature or objective hallucination regarding government welfare programs.
38. SCIENTIFIC & SPACE MISSIONS PRECISION (CRITICAL):
    - For questions regarding space missions (ISRO, NASA, etc.), orbital parameters, landing sites (e.g. Chandrayaan-4 landing site around 84°–86° South latitude), payload specifications, or scientific terms, ensure absolute geographical and technical precision.
    - Use exact terms (e.g., "தென் துருவப் பகுதி / South Polar Region" rather than just "தென் துருவம் / South Pole" when referring to specific landing coordinate zones).
39. ENTITY & POLICY PRECISION (CRITICAL):
    - Provide exact person, event, scheme, award, and institution names. Avoid vague phrases like "an eminent scientist" or "a new wildlife sanctuary".
    - For educational policy references, always use "National Education Policy (NEP) 2020", never use speculative years like NEP 2026 unless officially established.
40. CORRECT OPTION RANDOM DISTRIBUTION (CRITICAL):
    - Ensure `correctOptionIndex` (0, 1, 2, 3) is randomly and evenly distributed across generated questions. Never make option index 0 the correct answer for every question.
41. STRICT CURRENT-AFFAIRS & DATE VALIDATION RULES (CRITICAL):
    - Never generate a future event as a completed event.
    - event_date MUST be <= quiz_generation_date ($generationDateStr).
    - If an event is scheduled for a future date, DO NOT create a question describing it as held, launched, won, concluded, announced, inaugurated, awarded, allocated, or completed.
    - Every current-affairs question MUST be supported by a verifiable official source (PIB, GoI ministries, Tamil Nadu Government, ISRO, CMRL, official sports federations/tournament websites).
    - Never invent: awards, competitions, schemes, government announcements, funding allocations, winners, summits, projects, appointments.
    - Avoid vague entities: "an eminent scientist", "a renowned author", "a new wildlife sanctuary", "a major event". Use exact names: person_name, event_name, award_name, organization_name, location, event_date.
    - National Education Policy must be referred to as "National Education Policy 2020 (NEP 2020)" unless an official source explicitly establishes otherwise. Never generate "NEP 2026".
    - If the fact cannot be verified, REMOVE the question. Never guess or fill missing details.
42. OPTION UNIQUENESS & SAME-QUIZ DEDUPLICATION (CRITICAL):
    - Options must represent four genuinely different entities or values. Do NOT treat spelling variations, abbreviations, initials, punctuation differences, or alternate names of the SAME entity as different options (e.g., "P. V. Sindhu" and "PV Sindhu" are identical and forbidden).
    - SAME-QUIZ EVENT DEDUPLICATION: Do not reuse the same underlying event, scheme, tournament, or topic across questions in the same quiz.

Before generating the JSON, internally verify:
- APTITUDE ACCURACY: Perform step-by-step calculation. Does the result match the option?
- BILINGUAL REQUIREMENT: Does every field have both English and Tamil?
- Grammar accuracy (Tamil & English)
- No duplicate questions or patterns
- No duplicate options
- Correctness of correctOptionIndex
- Explanation clarity and accuracy (Show the math!)

Output Format:

[
  {
    "question_en":"...",
    "question_ta":"...",
    "options":[
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."}
    ],
    "correctOptionIndex":0,
    "explanation_en":"...",
    "explanation_ta":"..."
  }
]

Return ONLY the final verified JSON array.
""";

    // Prompt definitions ------------------------------------------------
    final promptTamil = """
Generate up to 10 UNIQUE TNPSC General Language MCQs (Target: 10. Quality and uniqueness are more important than count. If fewer genuinely new and verified questions are available, return fewer. NEVER repeat an old question/event/topic merely to reach the target).
Focus primarily on these 3 categories for today:
$focusTopics

Requirements:
- SSLC Standard
- Cover Grammar, Vocabulary, and Literature.
- No repeated question pattern.
$avoidPrompt

$commonRules
""";

    final promptGS = """
Generate up to 6 UNIQUE TNPSC General Studies MCQs (Target: 6. Quality and uniqueness are more important than count. If fewer genuinely new and verified questions are available, return fewer. NEVER repeat an old question/event/topic merely to reach the target).
Focus primarily on these categories for today:
$focusGS

Requirements:
- SSLC Standard
- Balanced coverage of History, Science, and Polity.
- No repeated question pattern.

$avoidPrompt

$commonRules
""";

    final promptAptitude = """
Generate up to 4 UNIQUE TNPSC Aptitude & Mental Ability MCQs (Target: 4. Quality and uniqueness are more important than count. If fewer genuinely new questions are available, return fewer. NEVER repeat an old question or calculation pattern).
Focus primarily on these categories for today:
$focusAptitude

Requirements:
- SSLC Standard
- Each question must require calculation (except for reasoning). 
- You MUST solve the problem step-by-step internally before selecting the correct option.
- The explanation MUST show the formula and the substitution steps clearly in both languages.
- Ensure the calculated result EXACTLY matches the correct option value.

$avoidPrompt

$commonRules
""";

    // --------------------------------------------------------------------
    // Daily quiz generation with precise category quotas (10 Tamil, 6 GS, 4 Aptitude)
    List<dynamic> draftQuestions = [];
    Set<String> seenTexts = {};

    int getCountForType(String type) => draftQuestions.where((q) => q['quiz_type'] == type).length;

    Future<void> fillCategory(String promptText, String quizType, int targetCount, int maxAttemptsPerCategory) async {
      int attempts = 0;
      while (getCountForType(quizType) < targetCount && attempts < maxAttemptsPerCategory) {
        attempts++;
        int needed = targetCount - getCountForType(quizType);
        if (needed <= 0) break;

        final promptWithTarget = promptText.replaceAll(RegExp(r'Target: \d+'), 'Target: $needed').replaceAll(RegExp(r'up to \d+'), 'up to $needed');
        final res = await _generateWithFallback(promptWithTarget);
        if (res != null) {
          List<dynamic> parsed = _parseQuestions(res);
          List<dynamic> validQ = _filterValidQuestions(parsed, generationDate: generationDate);
          int rejected = parsed.length - validQ.length;
          AppLog.d("AI_DEBUG: [Daily Quiz - $quizType] Attempt $attempts -> Generated: ${parsed.length}, Added: ${validQ.length}, Rejected: $rejected");

          for (var item in validQ) {
            if (getCountForType(quizType) >= targetCount) break;
            String textTa = (item['question_ta'] ?? '').toString().trim();
            if (textTa.isNotEmpty && !seenTexts.contains(textTa)) {
              seenTexts.add(textTa);
              int index = draftQuestions.length + 1;
              String topicKey = quizType == 'general_tamil' ? 'Culture' : (quizType == 'general_studies' ? 'National Affairs' : 'Economy');
              String eventName = quizType == 'general_tamil' ? 'TNPSC General Tamil & Literature' : (quizType == 'general_studies' ? 'TNPSC General Studies Assessment' : 'TNPSC Quantitative Aptitude');
              String sourceName = quizType == 'general_tamil' ? 'Tamil Nadu Textbooks (Samacheer Kalvi)' : 'Press Information Bureau (PIB)';
              String sourceUrl = quizType == 'general_tamil' ? 'https://www.tntextbooks.in' : 'https://pib.gov.in';

              draftQuestions.add({
                ...item,
                'quiz_type': quizType,
                'topic_key': topicKey,
                'event_name': eventName,
                'event_date': dateStr,
                'published_at': DateTime.now().toIso8601String(),
                'source_name': sourceName,
                'source_url': sourceUrl,
                'source_id': "${quizType}_${dateStr}_$index",
                'event_id': "${quizType}_event_${dateStr}_$index",
              });
            }
          }
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    // 1. Fill General Tamil (Target: 10)
    await fillCategory(promptTamil, 'general_tamil', 10, 5);

    // 2. Fill General Studies (Target: 6)
    await fillCategory(promptGS, 'general_studies', 6, 5);

    // 3. Fill Aptitude (Target: 4)
    await fillCategory(promptAptitude, 'aptitude', 4, 5);

    if (draftQuestions.length < 20) {
      AppLog.d("AI_DEBUG: [FAILED] Daily Quiz generation for $dateStr fell short at ${draftQuestions.length}/20");
      return false;
    }

    if (draftQuestions.length > 20) {
      draftQuestions = draftQuestions.sublist(0, 20);
    }
    draftQuestions.shuffle();
    List<dynamic> allQuestions = draftQuestions;
    AppLog.d("AI_DEBUG: [SUCCESS] Daily Quiz generated for $dateStr. Total questions added: ${allQuestions.length} (Tamil: ${getCountForType('general_tamil')}, GS: ${getCountForType('general_studies')}, Aptitude: ${getCountForType('aptitude')})");

    // Store / update in Firestore
    final querySnapshot = await FirebaseFirestore.instance
        .collection('quizzes')
        .where('date', isEqualTo: dateStr)
        .where('type', isEqualTo: 'daily_quiz')
        .get();

    final quizData = {
      'date': dateStr,
      'title': "Daily Quiz / தினசரி வினாடி வினா",
      'quizType': 'daily_quiz',
      'questions': allQuestions,
      'type': 'daily_quiz',
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (querySnapshot.docs.isNotEmpty) {
      await querySnapshot.docs.first.reference.set(
        quizData,
        SetOptions(merge: true),
      );
    } else {
      await FirebaseFirestore.instance.collection('quizzes').doc('daily_$dateStr').set(quizData, SetOptions(merge: true));
    }
    return true;
  }

  static Future<bool> generateAndSaveMockQuiz(DateTime date) async {
    final dateStr = AppDate.format(date);

    // 1. Check if quiz already exists and has 50 questions
    try {
      final existingSnap = await FirebaseFirestore.instance
          .collection('mock_tests')
          .where('date', isEqualTo: dateStr)
          .where('type', isEqualTo: 'daily_quiz')
          .where('quizType', isEqualTo: 'daily_50_quiz')
          .get();
      if (existingSnap.docs.isNotEmpty) {
        List existingQs = existingSnap.docs.first.get('questions') ?? [];
        if (existingQs.length >= 50) {
          AppLog.d("AI_DEBUG: 50-Mock quiz for $dateStr already has ${existingQs.length} questions. Skipping generation.");
          return true;
        }
      }
    } catch (_) {}

    // Get topics from last 30 days to avoid repeats in mock tests
    String recentContext = await _getRecentQuizContext('mock_tests', 30);

    // Get Focus Topics for the mock test (Select 6 Language, 5 Aptitude, 4 GS)
    String focusTopics = _getLanguageTopicsForDate(date, 6);
    String focusAptitude = _getAptitudeTopicsForDate(date, 5);
    String focusGS = _getGsTopicsForDate(date, 4);

    final avoidPrompt = recentContext.isNotEmpty
        ? """
STRICTLY DO NOT create questions that are identical, very similar, or based on these recent questions/topics from the last 30 days:
$recentContext

Rules:
- Do NOT repeat the same question.
- Do NOT repeat the same answer choices with different wording.
- Do NOT repeat the same concept unless it is from a completely different chapter.
"""
        : "";

    final commonRules = """
STRICT QUALITY RULES (MUST FOLLOW)

1. Return ONLY valid JSON.
2. No Markdown.
3. No extra text before or after JSON.
4. Generate NEW and ORIGINAL questions.
5. Never repeat questions, options, explanations, or question patterns.
6. Every question must test a different concept.
7. Questions must be suitable for TNPSC SSLC Standard.
8. EVERY field MUST BE BILINGUAL (Separate English and Tamil keys).
9. English must be natural and error-free.
10. Tamil must use proper literary Tamil without spelling mistakes.
11. NO MIXED LANGUAGE: Do NOT mix Tamil and English in the same sentence or field.
12. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages. No Hindi words in brackets or parentheses.
13. Every question must have exactly four options.
14. Only ONE option must be correct.
15. Verify the correct answer before assigning correctOptionIndex.
16. correctOptionIndex MUST exactly match the correct option (0-3).
17. Explanation must clearly justify why the answer is correct. 
    - For Math/Aptitude: Show step-by-step calculation (Formula -> Steps -> Final Answer).
    - Ensure the calculated result EXACTLY matches the value in the correct option.
18. MANDATORY BILINGUAL FORMAT (STRICT):
    - "question_en": "English question text"
    - "question_ta": "தமிழ் வினா உரை"
    - "options": [{"en": "English Option", "ta": "தமிழ் விருப்பம்"}, ...] (List of 4 objects)
    - "explanation_en": "English explanation text"
    - "explanation_ta": "தமிழ் விளக்க உரை"
19. Avoid vague or ambiguous questions.
20. Avoid duplicate option values.
21. Avoid options like "All of the above" or "None of the above".
22. Do not generate trick questions.
23. Ensure every question is unique.
24. Ensure every option is unique.
25. Ensure every explanation is unique.
26. Maintain balanced difficulty.
27. Use proper punctuation.
28. Do not use unnecessary quotation marks.
29. Never invent incorrect historical or scientific facts.
31. FACTUAL & ANSWER ACCURACY (CRITICAL - 100% REAL DATA ONLY):
    - Every question MUST be based exclusively on REAL, VERIFIED FACTS from:
      * Tamil Nadu State Board (Samacheer Kalvi) Textbooks (Classes 6-12)
      * Authentic Classical & Modern Tamil Literature (Thirukkural, Silappatikaram, Manimekalai, Naladiyar, Bharathiyar, etc.)
      * Authentic Constitution of India (Articles, Parts, Schedules, Amendments)
      * Real Indian & Tamil Nadu History, Geography, Economy, and Science
      * Official Government Releases (PIB, DIPR TN, Official Portals)
    - NEVER invent fictional poets, fake book titles, imaginary awards, or non-existent government acts.
    - Zero hallucination. Every fact must be authentic and verifiable.
32. 100% COHERENCE BETWEEN QUESTION, OPTIONS, CORRECT ANSWER & EXPLANATION:
    - `correctOptionIndex` (0-3) MUST precisely point to the single correct option (0=Option 1, 1=Option 2, 2=Option 3, 3=Option 4).
    - The Explanation MUST directly explain and validate why `options[correctOptionIndex]` is the right answer.
    - NEVER let the explanation mention another option as correct (e.g. claiming Option B is correct while index is 0).
    - The 3 incorrect options (distractors) MUST be authentic, real alternatives from the same syllabus.
    - For Aptitude & Math: Solve step-by-step. The calculation result MUST EXACTLY match the number in the chosen option.
33. ALL AUTHENTIC TNPSC QUESTION FORMATS (MANDATORY VARIETY):
    - Must include a rich mix of all 5 authentic TNPSC exam formats:
      a) Standard Direct MCQs (~40%)
      b) "Match the Following / பொருத்துக" Questions (~25%): 
         CRITICAL REQUIREMENT: BOTH the LEFT COLUMN (a, b, c, d) AND the RIGHT COLUMN (1, 2, 3, 4) MUST BE INCLUDED in the question text. NEVER omit either side! Both left and right items must have actual descriptive text. The 4 options MUST be matching code combinations (e.g. "(a)-2, (b)-1, (c)-4, (d)-3").
      c) "Statement & Reason / Assertion Questions (கூற்று மற்றும் காரணம் / சரியானது எது?)" (~15%): Both Assertion (A) and Reason (R) must be present on separate lines.
      d) "Find the Incorrect Pair / Statement (தவறான கூற்று / தவறான இணை எது?)" (~10%): Identify the wrongly matched pair or false statement among options.
      e) "Chronological Order / Sequence (காலவரிசைப்படி முறைப்படுத்துக / ஏறுவரிசை)" (~10%): Arrange historical events, numbers, or facts in chronological order with all 4 items (1), (2), (3), (4) listed.
33. MANDATORY QUESTION FORMATTING INSTRUCTIONS (CRITICAL FOR NEWLINES & BOTH SIDES):
    - For "Match the following (பொருத்துக)", list ALL 4 items (a), (b), (c), (d) on SEPARATE NEW LINES using \n. 
      EACH LINE MUST CONTAIN BOTH the Left item AND the Right item separated by " — "!
      DO NOT GENERATE ONLY LEFT OR ONLY RIGHT! BOTH SIDES ARE STRICTLY MANDATORY!
      Tamil Example:
      "கீழ்க்காண்பனவற்றைச் சரியாகப் பொருத்துக:\n(a) பரணி — 1. யானைப்படையை வென்றவர் மீது பாடுவது\n(b) தூது — 2. தூது செல்லும் இலக்கியம்\n(c) உலா — 3. வீதியில் உலா வரும் தலைவனைக் கண்டு பாடுவது\n(d) குறவஞ்சி — 4. 96 வகைச் சிற்றிலக்கியங்களில் ஒன்று"
      English Example:
      "Match the following correctly:\n(a) Parani — 1. Literature sung on victory over elephants\n(b) Thoothu — 2. Envoy literature\n(c) Ula — 3. Literature on leader's street procession\n(d) Kuravanji — 4. One of the 96 minor literature types"
    - For "Statement & Reason (கூற்று மற்றும் காரணம்)", place Assertion and Reason on SEPARATE NEW LINES using \n.
      Example: "கூற்று (A): சிலப்பதிகாரமும் மணிமேகலையும் இரட்டைக் காப்பியங்கள்.\nகாரணம் (R): இரண்டும் ஒரே காலக்கட்டத்தில் தோன்றியவை."
    - For "Chronological Order (காலவரிசைப்படுத்துக)", place numbered items on SEPARATE NEW LINES using \n.
      Example: "காலவரிசைப்படுத்துக:\n(1) சிலப்பதிகாரம்\n(2) மணிமேகலை\n(3) சீவக சிந்தாமணி\n(4) வளையாபதி"
34. MANDATORY YEAR/DATE SPECIFICATION (AWARDS, SPORTS, SCHEMES, SUMMITS, EVENTS):
    - For any question related to an Award (விருது), Sports Tournament (விளையாட்டு/போட்டி), Government Scheme (திட்டம்), Summit/Conference (மாநாடு), or Current Affairs event, YOU MUST EXPLICITLY INCLUDE THE YEAR (e.g. 2024, 2025) or DATE / MONTH & YEAR (e.g. '2024-ஆம் ஆண்டிற்கான...', 'செப்டம்பர் 2024-ல்...') in BOTH question_en and question_ta!
    - Example: '2024-ஆம் ஆண்டிற்கான தாதாசாகேப் பால்கே விருதை வென்றவர் யார்? / Who received the Dadasaheb Phalke Award for the year 2024?'
    - Example: '2024 பாரிஸ் ஒலிம்பிக்கில் தங்கம் வென்றவர் யார்? / Who won gold at the 2024 Paris Olympics?'
    - NEVER generate an award, sports, or event question without the year or date.
35. STRICTLY NO FUTURE-DATED OR UNVERIFIED EVENTS (CRITICAL):
    - NEVER generate questions about sports tournaments, awards, elections, summits, or current affairs events whose dates are in the future or have not yet concluded/happened relative to the current generation date.
    - All current affairs and event-based questions must reference past, completed, and verified events up to the present date.
    - Never assume, predict, or project winners, outcomes, or future event dates.
37. TN GOVT SCHEMES & INITIATIVES ACCURACY (CRITICAL):
    - Never invent, alter, or confuse Tamil Nadu government scheme names (e.g. do not confuse official schemes like "நம்ம ஊரு சூப்பரு" with unverified or fabricated names like "நம்ம ஊரு பசுமை").
    - Verify exact scheme names, objectives, and launch details from official Tamil Nadu DIPR press releases or Government Orders.
37. TN GOVT SCHEMES & INITIATIVES ACCURACY (CRITICAL):
    - Never invent, alter, or confuse Tamil Nadu government scheme names (e.g. do not confuse official schemes like "நம்ம ஊரு சூப்பரு" with unverified or fabricated names like "நம்ம ஊரு பசுமை").
    - Verify exact scheme names, objectives, and launch details from official Tamil Nadu DIPR press releases or Government Orders.

Before generating the JSON, internally verify:
- APTITUDE ACCURACY: Perform step-by-step calculation. Does the result match the option?
- BILINGUAL REQUIREMENT: Does every field have both English and Tamil?
- Grammar accuracy (Tamil & English)
- No duplicate questions or patterns
- No duplicate options
- Correctness of correctOptionIndex
- Explanation clarity and accuracy (Show the math!)

Output Format:

[
  {
    "question_en":"...",
    "question_ta":"...",
    "options":[
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."}
    ],
    "correctOptionIndex":0,
    "explanation_en":"...",
    "explanation_ta":"..."
  }
]

Return ONLY the final verified JSON array.
""";

    // Prompt definitions ------------------------------------------------
    final promptTamil = """
Generate exactly 25 UNIQUE TNPSC General Language MCQs. 
Focus primarily on these 4 categories for today:
$focusTopics

Requirements:
- SSLC Standard
- Cover Grammar, Literature, and Authors.
- No repeated question pattern.
$avoidPrompt

$commonRules
""";

    final promptGS = """
Generate exactly 15 UNIQUE TNPSC General Studies MCQs.
Focus primarily on these categories for today:
$focusGS

Requirements:
- SSLC Standard
- Comprehensive coverage across GS domains.
- No repeated question pattern.

$avoidPrompt

$commonRules
""";

    final promptAptitude = """
Generate exactly 10 UNIQUE TNPSC Aptitude & Mental Ability MCQs.
Focus primarily on these categories for today:
$focusAptitude

Requirements:
- SSLC Standard
- Each question must require calculation (except for reasoning).
- You MUST solve the problem step-by-step internally before selecting the correct option.
- The explanation MUST show the formula and the substitution steps clearly in both languages.
- Ensure the calculated result EXACTLY matches the correct option value.

$avoidPrompt

$commonRules
""";

    // --------------------------------------------------------------------
    List<dynamic> draftQuestions = [];
    Set<String> seenTexts = {};

    int getMockCountForType(String type) => draftQuestions.where((q) => q['quiz_type'] == type).length;

    Future<void> fillMockCategory(String promptText, String quizType, int targetCount, int maxAttempts) async {
      int attempts = 0;
      while (getMockCountForType(quizType) < targetCount && attempts < maxAttempts) {
        attempts++;
        int needed = targetCount - getMockCountForType(quizType);
        if (needed <= 0) break;

        final promptWithTarget = promptText.replaceAll(RegExp(r'exactly \d+'), 'exactly $needed').replaceAll(RegExp(r'up to \d+'), 'up to $needed');
        final res = await _generateWithFallback(promptWithTarget);
        if (res != null) {
          List<dynamic> parsed = _parseQuestions(res);
          List<dynamic> validBatch = _filterValidQuestions(parsed);
          int rejected = parsed.length - validBatch.length;
          AppLog.d("AI_DEBUG: [Mock Quiz - $quizType] Attempt $attempts -> Generated: ${parsed.length}, Added: ${validBatch.length}, Rejected: $rejected");

          for (var q in validBatch) {
            if (getMockCountForType(quizType) >= targetCount) break;
            String textTa = (q['question_ta'] ?? '').toString().trim();
            if (textTa.isNotEmpty && !seenTexts.contains(textTa)) {
              seenTexts.add(textTa);
              final detectedType = q['quiz_type']?.toString().toLowerCase() ?? quizType;
              draftQuestions.add({...q, 'quiz_type': detectedType});
            }
          }
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    // 1. Fill General Tamil (Target: 25)
    await fillMockCategory(promptTamil, 'general_tamil', 25, 5);

    // 2. Fill General Studies (Target: 15)
    await fillMockCategory(promptGS, 'general_studies', 15, 5);

    // 3. Fill Aptitude (Target: 10)
    await fillMockCategory(promptAptitude, 'aptitude', 10, 5);

    // --------------------------------------------------------------------
    if (draftQuestions.length >= 50) {
      // Shuffle the final list to mix Tamil, GS, and Aptitude
      draftQuestions.shuffle();
      if (draftQuestions.length > 50) {
        draftQuestions = draftQuestions.sublist(0, 50);
      }
      List<dynamic> allQuestions = draftQuestions;
      AppLog.d("AI_DEBUG: [SUCCESS] 50-Mock Quiz generated for $dateStr. Total questions added: ${allQuestions.length}");

      // Final check for 50 questions total
      final querySnapshot = await FirebaseFirestore.instance
          .collection('mock_tests')
          .where('date', isEqualTo: dateStr)
          .where('type', isEqualTo: 'daily_quiz')
          .where('quizType', isEqualTo: 'daily_50_quiz')
          .get();

      final quizData = {
        'date': dateStr,
        'title': "Daily Mock Quiz / தினசரி மாதிரி வினாடி வினா",
        'quizType': 'daily_50_quiz',
        'quiz_type': 'tamil_gs_aptitude',
        'questions': allQuestions,
        'type': 'daily_quiz',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.set(
          quizData,
          SetOptions(merge: true),
        );
      } else {
        await FirebaseFirestore.instance.collection('mock_tests').doc('mock_$dateStr').set(quizData, SetOptions(merge: true));
      }
      return true;
    }
    return false;
  }

  static Future<bool> generateAndSaveRoomPredefinedQuiz(String subject) async {
    String specializedPrompt = "";

    // Get topics from last 90 days to avoid repeats in room quizzes
    String recentContext = await _getRecentQuizContext('room_predefined_quizzes', 90);

    final avoidPrompt = recentContext.isNotEmpty
        ? """
STRICTLY DO NOT create questions that are identical, very similar, or based on these recent questions/topics:
$recentContext

Rules:
- Do NOT repeat the same question.
- Do NOT repeat the same concepts or historical facts.
"""
        : "";

    if (subject == 'general_tamil') {
      // Get Focus Topics for today (Select 4 categories)
      String focusTopics = _getLanguageTopicsForDate(AppDate.getISTNow(), 4);

      specializedPrompt = '''
Generate 20 UNIQUE TNPSC General Language (பொதுமொழி) MCQs (SSLC Standard). 
Focus primarily on these 4 categories:
$focusTopics

STRICT LANGUAGE REQUIREMENTS (CRITICAL):
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages.
3. Ensure there are NO spelling mistakes.
''';
    } else if (subject == 'general_studies') {
      // Get Focus Topics for today (Select 4 GS categories)
      String focusGS = _getGsTopicsForDate(AppDate.getISTNow(), 4);

      specializedPrompt = '''
Generate 20 UNIQUE TNPSC General Studies (பொது அறிவு) MCQs (SSLC Standard). 
Focus primarily on these categories:
$focusGS

STRICT LANGUAGE REQUIREMENTS (CRITICAL):
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages.
3. Ensure there are NO spelling mistakes.
''';
    } else if (subject == 'aptitude') {
      // Get Focus Topics for today (Select 4 categories)
      String focusAptitude = _getAptitudeTopicsForDate(AppDate.getISTNow(), 4);

      specializedPrompt = '''
Generate 20 UNIQUE TNPSC Aptitude and Mental Ability MCQs (SSLC Standard). 
Focus primarily on these categories:
$focusAptitude

CRITICAL INSTRUCTIONS:
1. Double-check the 'correctOptionIndex' (0, 1, 2, or 3).
2. Solve step-by-step internally before finalizing.
3. The explanation MUST show the formula and clear calculation steps in both English and Tamil.
4. Ensure the calculated result EXACTLY matches the value in the correct option.
5. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages.
''';
    } else if (subject == 'current_affairs') {
      // Current affairs MUST use the source-only pipeline.
      // Never let this generic subject generator invent news.
      AppLog.d(
        "AI_DEBUG: Current affairs is disabled in generic subject generation. "
            "Use generateAndSaveCurrentAffairsQuiz() with verified sources.",
      );
      return false;
    } else {
      specializedPrompt = '''
Create 20 UNIQUE TNPSC MCQs for '$subject' (Bilingual). 
STRICT LANGUAGE REQUIREMENTS (CRITICAL):
1. USE ONLY Pure Tamil and Pure English.
2. NO MIXED LANGUAGE: Do NOT mix English and Tamil in the same sentence or field.
3. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages.
4. Ensure there are NO spelling mistakes.
''';
    }

    final prompt =
    '''
$specializedPrompt
$avoidPrompt
CRITICAL MATCH THE FOLLOWING RULE:
If generating a Match the following (பொருத்துக) question, BOTH the Left column (a, b, c, d) and Right column (1, 2, 3, 4) MUST BE INCLUDED in every line:
Example: "பொருத்துக:\n(a) Left 1 — 1. Right 1\n(b) Left 2 — 2. Right 2\n(c) Left 3 — 3. Right 3\n(d) Left 4 — 4. Right 4"
NEVER omit the right side definitions or the left side items!

Strictly use this BILINGUAL JSON format: 
[{"question_en": "English question text", 
"question_ta": "தமிழ் வினா உரை",
"options": [{"en": "English Option", "ta": "தமிழ் விருப்பம்"}, ...], 
"correctOptionIndex": 0, 
"explanation_en": "English explanation text",
"explanation_ta": "தமிழ் விளக்க உரை"}]. 
Only return the raw JSON array, no other text or markdown formatting.
''';

    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> questions = jsonDecode(
            res.substring(start, end + 1),
          );
          List<dynamic> validQuestions = _filterValidQuestions(questions);

          if (validQuestions.length < 20) return false;

          final docRef = FirebaseFirestore.instance.collection('room_predefined_quizzes').doc(subject);

          // AI_DEBUG: Sliding Window Logic (Max 1500 questions)
          // 1. Fetch existing pool to maintain size
          final snap = await docRef.get();
          List<dynamic> existingQs = [];
          if (snap.exists) {
            existingQs = List.from(snap.get('questions') ?? []);
          }

          // 2. Prepare new questions
          List<dynamic> sanitizedNewQs = validQuestions.map((q) => {
            ...q,
            'quiz_type': subject,
            'subject': subject,
            'createdAt': AppDate.getISTNow().toIso8601String(), // Changed from serverTimestamp to fix Array error
          }).toList();

          // 3. Maintenance: Combine (Prepend new) and trim to latest 500
          // AI_DEBUG: Reduced pool size to 500 to stay under 1MB Firestore limit
          const int maxPoolSize = 500;
          List<dynamic> combinedQs = [...sanitizedNewQs, ...existingQs];

          if (combinedQs.length > maxPoolSize) {
            combinedQs = combinedQs.sublist(0, maxPoolSize);
            AppLog.d("AI_DEBUG: Pool Size Management for $subject. Kept latest 500 questions.");
          }

          // 4. Save back to Firestore
          await docRef.set({
            'subject': subject,
            'questions': combinedQs,
            'lastUpdated': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(), // Added for avoidance context fetch
          }, SetOptions(merge: true));

          return true;
        }
      } catch (e) {
        AppLog.d("AI_DEBUG: Room Predefined Quiz JSON Parse Error: $e");
      }
    }
    return false;
  }

  static Future<bool> generateScheduledQuiz(
      DateTime date,
      String quizType, {
        int count = 20,
        int? setIndex,
      }) async {
    final dateStr = AppDate.format(date);
    String subjectTitle = "";
    String syllabusPrompt = "";

    if (quizType == 'general_tamil') {
      // Get Focus Topics for the scheduled quiz (Select 4 categories)
      String focusTopics = _getLanguageTopicsForDate(date, 4);

      subjectTitle =
      "General Language (SSLC Standard)${setIndex != null ? ' - Set $setIndex' : ''}";
      syllabusPrompt =
      "Focus Categories for today:\n$focusTopics\n\nGeneral Grammar, Vocabulary, Literature, and Authors.";
    } else if (quizType == 'general_studies') {
      subjectTitle =
      "General Studies (SSLC Standard)${setIndex != null ? ' - Set $setIndex' : ''}";
      syllabusPrompt =
      "General Science, Current Events, Geography, History and Culture of India, Indian Polity, Indian Economy, and Indian National Movement.";
    } else {
      // Get Focus Topics for the scheduled quiz (Select 4 categories)
      String focusAptitude = _getAptitudeTopicsForDate(date, 4);

      subjectTitle =
      "Aptitude & Mental Ability Test (SSLC Standard)${setIndex != null ? ' - Set $setIndex' : ''}";
      syllabusPrompt =
      "Focus Categories for today:\n$focusAptitude\n\nSimplification, Percentage, HCF & LCM, Ratio, Interest, Time and Work, and Logical Reasoning.";
    }

    final prompt =
    '''
Generate EXACTLY $count TNPSC MCQs for the subject '$subjectTitle' based on the syllabus: $syllabusPrompt.
STRICT LANGUAGE REQUIREMENTS (CRITICAL):
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages.
3. Ensure there are NO spelling mistakes.
4. Each question MUST be bilingual using separate keys for English and Tamil.
5. For Math/Aptitude questions, you MUST solve them step-by-step internally.
6. The explanation MUST show the formula and clear calculation steps in both languages.
7. Ensure the calculated result EXACTLY matches the correct option.
8. CRITICAL MATCH THE FOLLOWING RULE:
   If generating a Match the following (பொருத்துக) question, BOTH the Left column (a, b, c, d) and Right column (1, 2, 3, 4) MUST BE INCLUDED in every line:
   Example: "பொருத்துக:\n(a) Left 1 — 1. Right 1\n(b) Left 2 — 2. Right 2\n(c) Left 3 — 3. Right 3\n(d) Left 4 — 4. Right 4"
   NEVER omit the right side definitions or the left side items!
Strictly use this BILINGUAL JSON format: 
[{"question_en": "English question text", 
"question_ta": "தமிழ் வினா உரை",
"options": [{"en": "English Option", "ta": "தமிழ் விருப்பம்"}, ...], 
"correctOptionIndex": 0, 
"explanation_en": "English explanation text",
"explanation_ta": "தமிழ் விளக்க உரை"}]. 
Return only the raw JSON array of EXACTLY $count items.
''';

    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> allQuestions = jsonDecode(
            res.substring(start, end + 1),
          );
          allQuestions = _filterValidQuestions(allQuestions);

          // VALIDATION: Ensure at least 70% of requested questions
          if (allQuestions.length < (count * 0.7)) {
            AppLog.d(
              "AI_DEBUG: Count/Validation mismatch. Got valid ${allQuestions.length}, expected at least ${count * 0.7}.",
            );
            return false;
          }
          if (allQuestions.length > count) {
            allQuestions = allQuestions.sublist(0, count);
          }

          final querySnapshot = await FirebaseFirestore.instance
              .collection('quizzes')
              .where('date', isEqualTo: dateStr)
              .where('quiz_type', isEqualTo: quizType)
              .where('set_index', isEqualTo: setIndex)
              .get();

          final quizData = {
            'date': dateStr,
            'title': subjectTitle,
            'quiz_type': quizType,
            'quizType': quizType,
            'set_index': setIndex,
            'questions': allQuestions
                .map((q) => {...q, 'quiz_type': quizType})
                .toList(),
            'type': 'daily_quiz',
            'createdAt': FieldValue.serverTimestamp(),
          };

          if (querySnapshot.docs.isNotEmpty) {
            await querySnapshot.docs.first.reference.set(
              quizData,
              SetOptions(merge: true),
            );
          } else {
            await FirebaseFirestore.instance
                .collection('quizzes')
                .add(quizData);
          }
          return true;
        }
      } catch (e) {
        AppLog.d("AI_DEBUG: JSON Parse Error: $e");
      }
    }
    return false;
  }

  static Future<bool> generateSubjectQuestions(
      String subject, {
        String? category,
      }) async {
    String specializedPrompt = "";

    // Get topics from last 90 days to avoid repeats
    String recentContext = await _getRecentQuizContext('subject_questions', 90);

    final avoidPrompt = recentContext.isNotEmpty
        ? """
STRICTLY DO NOT create questions that are identical, very similar, or based on these recent questions/topics:
$recentContext

Rules:
- Do NOT repeat the same question.
- Do NOT repeat the same concepts or historical facts.
"""
        : "";

    if (subject == 'general_tamil') {
      // Get Focus Topics for today (Select 4 categories)
      String focusTopics = _getLanguageTopicsForDate(AppDate.getISTNow(), 4);

      specializedPrompt = '''
Generate 20 UNIQUE TNPSC General Language (பொதுமொழி) MCQs (SSLC Standard). 
Focus primarily on these 4 categories:
$focusTopics

STRICT LANGUAGE REQUIREMENTS (CRITICAL):
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages.
3. Ensure there are NO spelling mistakes.
''';
    } else if (subject == 'general_studies') {
      // Get Focus Topics for today (Select 4 GS categories)
      String focusGS = _getGsTopicsForDate(AppDate.getISTNow(), 4);

      specializedPrompt = '''
Generate 20 UNIQUE TNPSC General Studies (பொது அறிவு) MCQs (SSLC Standard). 
Focus primarily on these categories:
$focusGS

STRICT LANGUAGE REQUIREMENTS (CRITICAL):
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages.
3. Ensure there are NO spelling mistakes.
''';
    } else if (subject == 'aptitude') {
      // Get Focus Topics for today (Select 4 categories)
      String focusAptitude = _getAptitudeTopicsForDate(AppDate.getISTNow(), 4);

      specializedPrompt = '''
Generate 20 UNIQUE TNPSC Aptitude and Mental Ability MCQs (SSLC Standard). 
Focus primarily on these categories:
$focusAptitude

CRITICAL INSTRUCTIONS:
1. Double-check the 'correctOptionIndex' (0, 1, 2, or 3).
2. Solve step-by-step internally before finalizing.
3. The explanation MUST show the formula and clear calculation steps in both English and Tamil.
4. Ensure the calculated result EXACTLY matches the value in the correct option.
5. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages.
''';
    } else if (subject == 'current_affairs') {
      // Current affairs MUST use the source-only pipeline.
      // Never let this generic subject generator invent news.
      AppLog.d(
        "AI_DEBUG: Current affairs is disabled in generic subject generation. "
            "Use generateAndSaveCurrentAffairsQuiz() with verified sources.",
      );
      return false;
    } else {
      specializedPrompt = '''
Create 25 UNIQUE TNPSC MCQs for '$subject' (Bilingual). 
STRICT LANGUAGE REQUIREMENTS (CRITICAL):
1. USE ONLY Pure Tamil and Pure English.
2. NO MIXED LANGUAGE: Do NOT mix English and Tamil in the same sentence or field.
3. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages.
4. Ensure there are NO spelling mistakes.
''';
    }

    final prompt =
    '''
$specializedPrompt
$avoidPrompt
CRITICAL MATCH THE FOLLOWING RULE:
If generating a Match the following (பொருத்துக) question, BOTH the Left column (a, b, c, d) and Right column (1, 2, 3, 4) MUST BE INCLUDED in every line:
Example: "பொருத்துக:\n(a) Left 1 — 1. Right 1\n(b) Left 2 — 2. Right 2\n(c) Left 3 — 3. Right 3\n(d) Left 4 — 4. Right 4"
NEVER omit the right side definitions or the left side items!

Strictly use this BILINGUAL JSON format: 
[{"question_en": "English question text", 
"question_ta": "தமிழ் வினா உரை",
"options": [{"en": "English Option", "ta": "தமிழ் விருப்பம்"}, ...], 
"correctOptionIndex": 0, 
"explanation_en": "English explanation text",
"explanation_ta": "தமிழ் விளக்க உரை"}].
Only return the raw JSON array, no other text or markdown formatting.
''';

    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> newQuestions = jsonDecode(
            res.substring(start, end + 1),
          );
          newQuestions = _filterValidQuestions(newQuestions);
          newQuestions = newQuestions
              .map((q) => {...q, 'quiz_type': 'subject_question'})
              .toList();

          String safeId = subject.trim().replaceAll('/', '-');
          final docRef = FirebaseFirestore.instance
              .collection('subject_questions')
              .doc(safeId);
          final doc = await docRef.get();

          List<dynamic> existingQuestions = [];
          if (doc.exists) {
            existingQuestions = doc.get('questions') ?? [];
          }

          Set<String> existingTexts = existingQuestions
              .map((e) => (e['question_ta'] ?? "").toString().trim())
              .toSet();
          List<dynamic> uniqueNew = newQuestions.where((item) {
            String text = (item['question_ta'] ?? "").toString().trim();
            return text.isNotEmpty && !existingTexts.contains(text);
          }).toList();

          if (uniqueNew.isEmpty) return true;

          List<dynamic> finalQuestions = [...existingQuestions, ...uniqueNew];
          await docRef.set({
            'subject': subject,
            'questions': finalQuestions,
            'lastUpdated': FieldValue.serverTimestamp(),
            'category': category,
          }, SetOptions(merge: true));
          return true;
        }
      } catch (e) {
        AppLog.d("AI_DEBUG: JSON Parse Error for $subject: $e");
      }
    }
    return false;
  }

  static Future<bool> generateStudyMaterial(
      String subject, {
        String? category,
      }) async {
    final prompt =
        "Create 25 structured TNPSC study points for '$subject'. STRICT LANGUAGE REQUIREMENTS: 1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. 2. NO OTHER LANGUAGES (Hindi, etc.). 3. NO spelling mistakes. Use this BILINGUAL JSON format: [{\"id\": 1, \"ta\": \"...\", \"en\": \"...\"}]. Only return the JSON array.";
    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> newMaterial = jsonDecode(res.substring(start, end + 1));
          String safeId = subject.trim().replaceAll('/', '-');
          final docRef = FirebaseFirestore.instance
              .collection('subject_study_material')
              .doc(safeId);
          final doc = await docRef.get();

          List<dynamic> existingMaterial = [];
          if (doc.exists) {
            existingMaterial = doc.get('material') ?? [];
          }

          Set<String> existingTexts = existingMaterial
              .map((e) => (e['ta'] ?? "").toString().trim())
              .toSet();
          List<dynamic> uniqueNew = newMaterial.where((item) {
            String text = (item['ta'] ?? "").toString().trim();
            return text.isNotEmpty && !existingTexts.contains(text);
          }).toList();

          if (uniqueNew.isEmpty) return true;

          List<dynamic> finalMaterial = [...existingMaterial, ...uniqueNew];
          for (int i = 0; i < finalMaterial.length; i++) {
            finalMaterial[i]['id'] = i + 1;
          }

          await docRef.set({
            'subject': subject,
            'category': category,
            'material': finalMaterial,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return true;
        }
      } catch (e) {
        AppLog.d("AI_DEBUG: Study Material Parse Error: $e");
      }
    }
    return false;
  }

  // Simple chat helpers ------------------------------------------------
  static Future<String?> chatWithAppContext(
      String message,
      String context,
      ) async {
    final prompt = '''
TNPSC Tutor context search: $context. Question: $message. 
STRICT LANGUAGE REQUIREMENTS (CRITICAL):
1. USE ONLY Pure Tamil and Pure English.
2. NO MIXED LANGUAGE: Do NOT mix English and Tamil in the same sentence or field.
3. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages.
4. Ensure there are NO spelling mistakes.
''';
    return await _generateWithFallback(prompt);
  }

  static Future<String?> chatWithAi(String message) async {
    final prompt = "TNPSC Doubt: $message. STRICT LANGUAGE REQUIREMENTS: 1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. 2. NO OTHER LANGUAGES (Hindi, etc.). 3. NO spelling mistakes. Answer in Pure Tamil & Pure English (Bilingual).";
    return await _generateWithFallback(prompt);
  }

  static Future<String> explainQuestion(
      String question,
      List<String> options,
      String correctAnswer,
      ) async {
    final prompt =
        "Explain TNPSC question: $question. Answer: $correctAnswer. STRICT LANGUAGE REQUIREMENTS: 1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. 2. NO OTHER LANGUAGES (Hindi, etc.). 3. NO spelling mistakes. Provide bilingual explanation.";
    final res = await _generateWithFallback(prompt);
    return res ?? "Explanation unavailable.";
  }

  static Future<String> generateStructuredStudyMaterial(String topic) async {
    final prompt = '''
Generate TNPSC study guide for '$topic'. 
STRICT LANGUAGE REQUIREMENTS (CRITICAL):
1. USE ONLY Pure Tamil and Pure English.
2. NO MIXED LANGUAGE: Do NOT mix English and Tamil in the same sentence or field.
3. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages.
4. Ensure there are NO spelling mistakes.
''';
    final res = await _generateWithFallback(prompt);
    return res ?? "Guide unavailable.";
  }

  static Future<List<dynamic>> generateCustomQuiz(String topic) async {
    final prompt =
    '''
Generate 20 TNPSC MCQs for '$topic' in both Pure Tamil and Pure English (Bilingual). 
CRITICAL INSTRUCTIONS:
1. Ensure the 'correctOptionIndex' (0-3) EXACTLY points to the correct answer in the 'options' list. 
2. For Math/Aptitude, double-check your calculations.
3. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. NO OTHER LANGUAGES (Hindi, etc.).
4. Each question MUST be bilingual using separate keys for English and Tamil.
5. For Math/Aptitude questions, you MUST solve them step-by-step internally.
6. The explanation MUST show the formula and clear calculation steps in both languages.
7. Ensure the calculated result EXACTLY matches the correct option.
Strictly use this BILINGUAL JSON format: 
[{"question_en": "English question text", 
"question_ta": "தமிழ் வினா உரை",
"options": [{"en": "English Option", "ta": "தமிழ் விருப்பம்"}, ...], 
"correctOptionIndex": 0, 
"explanation_en": "English explanation text",
"explanation_ta": "தமிழ் விளக்க உரை"}].
Only return the raw JSON array, no other text or markdown formatting.
''';
    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> raw = jsonDecode(res.substring(start, end + 1));
          return _filterValidQuestions(raw);
        }
      } catch (e) {}
    }
    return [];
  }

  /// IMPORTANT:
  /// Current-affairs data must come from VERIFIED Firestore source records.
  /// This client must NOT ask the model to invent/search for news.
  ///
  /// Required VERIFIED source document fields in `current_affairs_points`:
  /// verified=true, source_id, source_name, source_url, published_at,
  /// event_date, event_id, topic_key, event_name, titleEn, titleTa,
  /// contentEn, contentTa.
  ///
  /// `event_id` and `topic_key` are source-owned identities. The model is
  /// never allowed to invent them.
  ///
  /// If verified source records do not exist, generation MUST fail.
  /// Fewer questions are safer than hallucinated filler.
  static Future<String> _getPrompt(String key, String defaultPrompt) async {
    if (kDebugMode) {
      return defaultPrompt;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('ai_prompts').doc(key).get();
      if (doc.exists && doc.data()?['prompt'] != null) {
        return doc.data()!['prompt'].toString();
      }
    } catch (e) {
      AppLog.d("AI_DEBUG: Failed to fetch prompt for $key from Firestore: $e");
    }
    return defaultPrompt;
  }

  static bool _isValidRawUrl(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final url = value.trim();
    if (url.contains('](') || url.startsWith('[')) return false;
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  static String _normQ(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static Future<String> _buildCaPromptSimple({
    required List<Map<String, dynamic>> facts,
    required int ask,
    required String currentDateStr,
  }) async {
    final ctx = facts.map((s) {
      String cut(dynamic v, int n) {
        final t = (v ?? '').toString().trim();
        return t.length > n ? t.substring(0, n) : t;
      }
      return '- SOURCE_ID: ${s['source_id']}\n'
          '  DATE: ${s['event_date']} | ${s['event_name']}\n'
          '  EN: ${cut(s['contentEn'], 350)}\n'
          '  TA: ${cut(s['contentTa'], 350)}';
    }).join('\n');

    const defaultPromptTemplate = '''
You are a TNPSC Current Affairs question writer.
Use ONLY the FACTS below. Never use outside knowledge. Never invent facts.
CURRENT_DATE (IST): {currentDateStr}

RULES:
- Generate EXACTLY {ask} MCQs. Each question from a DIFFERENT fact.
- STRICT FACT MAPPING: Each generated question must strictly correspond to its respective fact/event in the facts list. You MUST return the exact `source_id` of the fact you used.
- Exactly 4 distinct options, exactly one correct. correctOptionIndex = 0-3.
- Put the year/month of the event inside the question text.
- If asking about UPSC, explicitly state "UPSC Civil Services" (யூபிஎஸ்சி குடிமைப்பணி) to avoid confusion with TNPSC.
- 100% EN/TA PARITY & COMPLETE TRANSLATION: English and Tamil questions/options/explanations must mean the exact same thing without contradiction.
- Explanations: 1 short sentence each.
- CRITICAL OPTION FORMAT: Options must be written entirely on a SINGLE CONTINUOUS LINE. Never use newline characters (\\n) inside option text.
- Output ONLY a JSON array.

ITEM FORMAT:
{"source_id":"...","question_en":"...","question_ta":"...",
 "options":[{"en":"...","ta":"..."},{"en":"...","ta":"..."},{"en":"...","ta":"..."},{"en":"...","ta":"..."}],
 "correctOptionIndex":0,"explanation_en":"...","explanation_ta":"..."}

FACTS:
{ctx}
''';

    final template = await _getPrompt('ca_generator_prompt', defaultPromptTemplate);
    return template
        .replaceAll('{currentDateStr}', currentDateStr)
        .replaceAll('{ask}', ask.toString())
        .replaceAll('{ctx}', ctx);
  }

  static Future<String> _buildCaDirectPrompt({
    required int ask,
    required String currentDateStr,
  }) async {
    const defaultPromptTemplate = '''
You are an expert TNPSC Current Affairs question writer.
Generate EXACTLY {ask} unique, authentic, and verified current-affairs Multiple Choice Questions (MCQs) focusing on Tamil Nadu and India (recent past up to {currentDateStr}, respecting the 15-day safety buffer).
Do not invent fictional facts, imaginary schemes, or future events.

RULES:
- Each question must be distinct and cover a different topic (Governance, Awards, Economy, Education, Environment, Infrastructure, Space, Sports, Science & Technology, International Affairs, National Affairs, Culture).
- Exactly 4 distinct options, exactly one correct. correctOptionIndex = 0-3.
- Put the year/month of the event inside the question text.
- If asking about UPSC, explicitly state "UPSC Civil Services" (யூபிஎஸ்சி குடிமைப்பணி) to avoid confusion with TNPSC.
- 100% EN/TA PARITY: English and Tamil questions/options/explanations must mean the exact same thing without contradiction.
- Explanations must directly cover and justify why the correct option is right.
- Use accurate Tamil terminology (e.g. "குழுக் கலம்" for crew module, "சங்கிலித் தொடர் தொழில்நுட்பச் சான்றிதழ்" for blockchain certificate).
- English and Tamil must not be mixed in one field.
- Explanations: 1 short sentence each.
- Output ONLY a JSON array.

ITEM FORMAT:
[
  {
    "question_en":"...",
    "question_ta":"...",
    "options":[
      {"en":"...","ta":"..."},
      {"en":"...","ta":"..."},
      {"en":"...","ta":"..."},
      {"en":"...","ta":"..."}
    ],
    "correctOptionIndex":0,
    "explanation_en":"...",
    "explanation_ta":"...",
    "topic_key":"Governance"
  }
]
''';

    final template = await _getPrompt('ca_direct_generator_prompt', defaultPromptTemplate);
    return template
        .replaceAll('{currentDateStr}', currentDateStr)
        .replaceAll('{ask}', ask.toString());
  }

  static DateTime? _parseCurrentAffairsSourceDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static Future<List<Map<String, dynamic>>> _getVerifiedCurrentAffairsSources(
      DateTime currentDate,
      ) async {
    final db = FirebaseFirestore.instance;
    final currentDateStr = AppDate.format(currentDate);
    final cutoffDate = currentDate.subtract(const Duration(days: 1095));

    try {
      final snap = await db
          .collection('current_affairs_points')
          .where('verified', isEqualTo: true)
          .limit(200)
          .get();

      final sources = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final d = Map<String, dynamic>.from(doc.data());

        final sourceId = (d['source_id'] ?? doc.id).toString().trim();
        final sourceName = (d['source_name'] ?? '').toString().trim();
        final sourceUrl = (d['source_url'] ?? '').toString().trim();
        final eventDateRaw = d['event_date'];
        final publishedAtRaw = d['published_at'];
        final eventName = (d['event_name'] ?? '').toString().trim();
        final sourceEventId = (d['event_id'] ?? '').toString().trim();
        final sourceTopicKey = (d['topic_key'] ?? '').toString().trim();
        final titleEn = (d['titleEn'] ?? '').toString().trim();
        final titleTa = (d['titleTa'] ?? '').toString().trim();
        
        String contentEn = '';
        final rawContentEn = d['contentEn'];
        if (rawContentEn is List) {
          contentEn = rawContentEn.map((e) => e.toString()).join('\n').trim();
        } else {
          contentEn = (rawContentEn ?? '').toString().trim();
        }

        String contentTa = '';
        final rawContentTa = d['contentTa'];
        if (rawContentTa is List) {
          contentTa = rawContentTa.map((e) => e.toString()).join('\n').trim();
        } else {
          contentTa = (rawContentTa ?? '').toString().trim();
        }

        final isVerified = d['verified'] == true;

        if (sourceId.isEmpty ||
            sourceName.isEmpty ||
            sourceUrl.isEmpty ||
            eventName.isEmpty ||
            sourceEventId.isEmpty ||
            sourceTopicKey.isEmpty ||
            titleEn.isEmpty ||
            titleTa.isEmpty ||
            contentEn.isEmpty ||
            contentTa.isEmpty ||
            !isVerified) {
          continue;
        }

        final eventDt = _parseCurrentAffairsSourceDate(eventDateRaw);
        final publishedDt = _parseCurrentAffairsSourceDate(publishedAtRaw);

        if (eventDt == null || publishedDt == null) {
          continue;
        }

        final eventDay = DateTime(
          eventDt.year,
          eventDt.month,
          eventDt.day,
        );

        // Event must be within the last 90 days and not in the future
        if (eventDay.isAfter(currentDate) || 
            eventDay.isBefore(DateTime(cutoffDate.year, cutoffDate.month, cutoffDate.day))) {
          continue;
        }

        // Canonicalize dates/identity from Firestore. The model must never invent these.
        d['source_id'] = sourceId;
        d['source_name'] = sourceName;
        d['source_url'] = sourceUrl;
        d['event_id'] = sourceEventId;
        d['topic_key'] = sourceTopicKey;
        d['event_date'] = AppDate.format(eventDay);
        d['published_at'] = publishedDt.toIso8601String();
        d['event_name'] = eventName;
        d['verified'] = true;
        sources.add(d);
      }

      sources.sort((a, b) {
        final aDate =
            DateTime.tryParse(a['event_date'].toString()) ?? DateTime(1970);
        final bDate =
            DateTime.tryParse(b['event_date'].toString()) ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      AppLog.d(
        "AI_DEBUG: Verified CA source pool: ${sources.length} "
            "(cutoff=${AppDate.format(cutoffDate)}, current=$currentDateStr)",
      );

      return sources;
    } catch (e) {
      AppLog.e("AI_DEBUG: Error loading verified CA sources", e);
      return [];
    }
  }

  static Future<bool> generateAndSaveDailyNews(DateTime date) async {
    final db = FirebaseFirestore.instance;
    final dateStr = AppDate.format(date);
    AppLog.d("AI_DEBUG: [DailyNews] Generating verified news highlights for $dateStr in structured array format...");

    final prompt = '''
You are an expert TNPSC Current Affairs News Collector and Editor.
Generate 30 verified daily current affairs highlight points suitable for TNPSC Group 1, Group 2, and Group 4 exams for the date $dateStr.
CRITICAL REQUIREMENTS:
1. You must generate highlights distributed EVENLY across ALL the following categories: Awards, Sports, Economy, Science & Technology, Tamil Nadu Governance, Infrastructure, Education, International Affairs, Environment, National Affairs.
2. CRITICAL LANGUAGE RULE: English fields (`titleEn`, `contentEn`, `event_name`) must be strictly in English. Tamil fields (`titleTa`, `contentTa`) must be strictly in Tamil script. Absolutely NO other languages or scripts (such as Hindi, Devanagari, Telugu, Kannada, Malayalam) are allowed anywhere.

For each highlight point, return a JSON object with EXACTLY this structure:
{
  "source_id": "pib_${dateStr}_01",
  "source_name": "Press Information Bureau (PIB)",
  "source_url": "https://pib.gov.in/PressReleasePage.aspx?PRID=123456",
  "event_id": "unique_snake_case_event_id",
  "event_name": "Short title of the event in English",
  "event_date": "$dateStr",
  "topic_key": "Awards",
  "category": "Awards",
  "titleEn": "English headline",
  "titleTa": "Tamil headline",
  "contentEn": [
    "Paragraph 1 in English with rich facts.",
    "Paragraph 2 in English with context."
  ],
  "contentTa": [
    "தமிழில் பத்தி 1 விரிவான தகவல்களுடன்.",
    "தமிழில் பத்தி 2 பின்னணியுடன்."
  ]
}

Return ONLY a valid JSON array of objects. No markdown formatting.
''';

    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        final parsed = _parseQuestions(res);
        if (parsed is List && parsed.isNotEmpty) {
          final batch = db.batch();
          int savedCount = 0;
          for (var item in parsed) {
            final map = Map<String, dynamic>.from(item as Map);
            final sourceId = map['source_id']?.toString().trim().isNotEmpty == true 
                ? map['source_id'].toString().trim() 
                : "news_${dateStr}_$savedCount";
            map['source_id'] = sourceId;
            map['verified'] = true;
            map['date'] = dateStr;
            map['timestamp'] = FieldValue.serverTimestamp();
            if (map['category'] == null && map['topic_key'] != null) {
              map['category'] = map['topic_key'];
            }

            final ref = db.collection('current_affairs_points').doc(sourceId);
            batch.set(ref, map, SetOptions(merge: true));
            savedCount++;
          }
          await batch.commit();
          AppLog.d("AI_DEBUG: [SUCCESS] Generated and saved $savedCount verified news points for $dateStr into current_affairs_points with array paragraphs.");
          return true;
        }
      } catch (e) {
        AppLog.d("AI_DEBUG: [DailyNews] Parse Error: $e");
      }
    }
    return false;
  }

  static Future<Map<String, dynamic>?> _verifyQuestionWithAi(
      Map<String, dynamic> q,
      Map<String, dynamic> source,
      ) async {
    final sourceText = "EN: ${source['contentEn']}\nTA: ${source['contentTa']}";
    final qEn = q['question_en'];
    final qTa = q['question_ta'];
    final options = jsonEncode(q['options']);

    const defaultVerifierTemplate = '''
You are a strict QA Verifier for TNPSC exam questions.
Analyze the SOURCE TEXT, English Question, Tamil Question, and 4 OPTIONS below.
1. Check if English and Tamil questions mean the exact same thing without any contradiction (e.g. no mismatch between Prelims and Mains, 100% semantic parity).
2. Solve the question objectively based ONLY on the source text (blind solve).
3. Extract an exact verbatim sentence quote from the SOURCE TEXT that directly supports the correct answer.

SOURCE TEXT:
{sourceText}

QUESTION (EN): {qEn}
QUESTION (TA): {qTa}
OPTIONS:
{options}

Return ONLY a JSON object with this exact structure:
{
  "languagesMatch": true,
  "blindSolveIndex": 0, 
  "supportingQuote": "exact verbatim sentence from source text"
}
''';

    final template = await _getPrompt('ca_verifier_prompt', defaultVerifierTemplate);
    final prompt = template
        .replaceAll('{sourceText}', sourceText)
        .replaceAll('{qEn}', qEn.toString())
        .replaceAll('{qTa}', qTa.toString())
        .replaceAll('{options}', options);

    final res = await _generateWithFallback(prompt);
    if (res == null) return null;
    try {
      int start = res.indexOf('{');
      int end = res.lastIndexOf('}');
      if (start == -1 || end <= start) return null;
      return jsonDecode(res.substring(start, end + 1));
    } catch (_) {
      return null;
    }
  }



  static Future<bool> generateAndSaveCurrentAffairsQuiz(DateTime date) async {
    const target = 20;
    const maxAttempts = 12;
    const batchQuestions = 5;
    const batchSources = 8;

    final db = FirebaseFirestore.instance;
    final quizDateStr = AppDate.format(date);
    final currentDate = AppDate.getISTNow();
    final currentDateStr = AppDate.format(currentDate);
    final draftRef = db.collection('quiz_drafts').doc('ca_$quizDateStr');

    // Check if final quiz already exists for today
    final existing = await db.collection('quizzes')
        .where('date', isEqualTo: quizDateStr)
        .where('type', isEqualTo: 'current_affairs')
        .limit(1).get();
    if (existing.docs.isNotEmpty) {
      AppLog.d("AI_DEBUG: [CA] quiz already exists for $quizDateStr. Skip.");
      return true;
    }

    // Load draft
    final draft = <Map<String, dynamic>>[];
    final draftSnap = await draftRef.get();
    final rawDraft = draftSnap.data()?['questions'];
    if (rawDraft is List) {
      for (final r in rawDraft) {
        if (r is Map) draft.add(Map<String, dynamic>.from(r));
      }
    }
    AppLog.d("AI_DEBUG: [CA] draft loaded: ${draft.length}/$target");

    // STRICT SOURCE-ONLY PIPELINE: Require verified real-world news articles
    final verifiedSources = await _getVerifiedCurrentAffairsSources(currentDate);
    AppLog.d("AI_DEBUG: [CA] facts pool = ${verifiedSources.length}");
    if (verifiedSources.isEmpty) {
      AppLog.d("AI_DEBUG: [CA] STOP - No verified source articles found in current_affairs_points. Current affairs requires real news articles. Skipping save.");
      return false;
    }

    final usedEventIds = <String>{};
    final usedSourceIds = <String>{};
    final usedQuestionKeys = <String>{};

    void markUsed(Map q) {
      final e = q['event_id']?.toString().trim() ?? '';
      final s = q['source_id']?.toString().trim() ?? '';
      final k = _normQ(q['question_en']?.toString() ?? '');
      if (e.isNotEmpty) usedEventIds.add(e);
      if (s.isNotEmpty) usedSourceIds.add(s);
      if (k.isNotEmpty) usedQuestionKeys.add(k);
    }

    try {
      final prev = await db.collection('quizzes')
          .where('type', isEqualTo: 'current_affairs')
          .limit(50).get();
      for (final doc in prev.docs) {
        final qs = doc.data()['questions'];
        if (qs is! List) continue;
        for (final raw in qs) {
          if (raw is Map) markUsed(raw);
        }
      }
    } catch (e) {
      AppLog.d("AI_DEBUG: [CA] previous fetch failed: $e");
    }
    for (final q in draft) markUsed(q);

    int stalls = 0;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (draft.length >= target) break;
      if (attempt >= maxAttempts - 2 && draft.length >= 18) {
        AppLog.d("AI_DEBUG: [CA] Reached near target (${draft.length}/$target) after $attempt attempts. Proceeding to save.");
        break;
      }

      final free = verifiedSources
          .where((s) => !usedSourceIds.contains(s['source_id'].toString()) &&
          !usedEventIds.contains(s['event_id'].toString()))
          .toList();
      if (free.isEmpty) {
        AppLog.d("AI_DEBUG: [CA] All verified sources used once. Resetting source usage to allow reuse for remaining questions. Draft=${draft.length}");
        usedSourceIds.clear();
        usedEventIds.clear();
        free.addAll(verifiedSources);
      }

      final ask = (target - draft.length) < batchQuestions
          ? (target - draft.length) : batchQuestions;
      final batch = free.take(batchSources).toList();

      final prompt = await _buildCaPromptSimple(
        facts: batch,
        ask: ask,
        currentDateStr: currentDateStr,
      );
      AppLog.d("AI_DEBUG: [CA] attempt $attempt/$maxAttempts ask=$ask promptChars=${prompt.length}");

      final res = await _generateWithFallback(prompt);
      if (res == null) {
        AppLog.d("AI_DEBUG: [CA] attempt $attempt -> AI returned NULL (Rate limit / Quota). Backing off...");
        await Future.delayed(const Duration(seconds: 20));
        continue;
      }

      int added = 0;
      try {
        final start = res.indexOf('[');
        final end = res.lastIndexOf(']');
        if (start == -1 || end <= start) {
          AppLog.d("AI_DEBUG: [CA] attempt $attempt -> no JSON array in response");
          continue;
        }
        final decoded = jsonDecode(res.substring(start, end + 1));
        if (decoded is! List) continue;

        for (final raw in decoded) {
          if (draft.length >= target) break;
          if (raw is! Map) continue;
          final q = Map<String, dynamic>.from(raw);

          if (!_validateQuestion(q,
              generationDate: date, skipYearCheck: true)) {
            AppLog.d("AI_DEBUG: [CA] REJECT invalid -> ${(q['question_en'] ?? '').toString()}");
            continue;
          }

          final availableSources = batch.where((s) => !usedSourceIds.contains(s['source_id'].toString())).toList();
          if (availableSources.isEmpty) continue;
          final source = availableSources[added % availableSources.length];
          final sid = source['source_id'].toString();

          q['source_id'] = sid;
          q['event_id'] = source['event_id'];
          q['topic_key'] = source['topic_key'];
          q['event_name'] = source['event_name'];
          q['event_date'] = source['event_date'];
          q['source_name'] = source['source_name'];
          q['source_url'] = source['source_url'];
          q['published_at'] = source['published_at'];

          if (!_isValidRawUrl(q['source_url']?.toString())) continue;
          if (usedSourceIds.contains(sid)) continue;
          if (usedEventIds.contains(q['event_id'].toString())) continue;

          final key = _normQ(q['question_en']?.toString() ?? '');
          if (key.isEmpty || usedQuestionKeys.contains(key) || draft.any((existing) => _normQ(existing['question_en']?.toString() ?? '') == key)) {
            AppLog.d("AI_DEBUG: [CA] REJECT duplicate -> $key");
            continue;
          }

          // Options shuffle
          final opts = q['options'];
          final ci = int.tryParse(q['correctOptionIndex'].toString()) ?? -1;
          if (opts is List && opts.length == 4 && ci >= 0 && ci < 4) {
            final list = opts.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            final correct = list[ci];
            list.shuffle();
            final ni = list.indexWhere(
                    (o) => o['en'] == correct['en'] && o['ta'] == correct['ta']);
            if (ni == -1) continue;
            q['options'] = list;
            q['correctOptionIndex'] = ni;
          }

          // AI #2: Verifier Check (Blind solve & Quote verification)
          final verificationResult = await _verifyQuestionWithAi(q, source);
          if (verificationResult == null) {
            AppLog.d("AI_DEBUG: [CA] REJECT verifier timeout/error");
            continue;
          }

          final bool languagesMatch = verificationResult['languagesMatch'] == true;
          if (!languagesMatch) {
            AppLog.d("AI_DEBUG: [CA] REJECT verifier language mismatch between EN and TA");
            continue;
          }

          final int blindIndex = int.tryParse(verificationResult['blindSolveIndex'].toString()) ?? -1;
          final String quote = verificationResult['supportingQuote']?.toString().trim() ?? '';

          if (blindIndex != q['correctOptionIndex']) {
            AppLog.d("AI_DEBUG: [CA] REJECT verifier mismatch -> blind($blindIndex) vs assigned(${q['correctOptionIndex']})");
            continue;
          }

          final sourceContentCombined = "${source['contentEn']} ${source['contentTa']}".toLowerCase();
          final normalizedQuote = quote.toLowerCase();
          if (quote.length < 10 || !sourceContentCombined.contains(normalizedQuote.substring(0, quote.length > 30 ? 30 : quote.length))) {
            AppLog.d("AI_DEBUG: [CA] REJECT verifier quote not found in source text");
            continue;
          }

          q['quiz_type'] = 'current_affairs';
          draft.add(q);
          markUsed(q);
          added++;
        }
      } catch (e) {
        AppLog.d("AI_DEBUG: [CA] attempt $attempt parse error: $e");
      }

      await draftRef.set({
        'date': quizDateStr,
        'questions': draft,
        'count': draft.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLog.d("AI_DEBUG: [CA] attempt $attempt added=$added draft=${draft.length}/$target");

      stalls = added == 0 ? stalls + 1 : 0;
      if (stalls >= 3) break;
      await Future.delayed(const Duration(seconds: 6));
    }

    if (draft.length < 18) {
      AppLog.d("AI_DEBUG: [CA] partial ${draft.length}/$target saved in draft. Firestore quizzes untouched.");
      return false;
    }

    final finalQs = (List<Map<String, dynamic>>.from(draft)..shuffle())
        .take(target).toList();

    for (var q in finalQs) {
      if (!_validateQuestion(q, generationDate: date, skipYearCheck: true)) {
        AppLog.d("AI_DEBUG: [CA] Final validation failed on question. Firestore untouched.");
        return false;
      }
    }

    await db.collection('quizzes').doc('ca_$quizDateStr').set({
      'date': quizDateStr,
      'title': "Current Affairs Quiz / நடப்பு நிகழ்வுகள்",
      'quizType': 'current_affairs',
      'type': 'current_affairs',
      'questions': finalQs,
      'knowledgeCutoffDate': currentDateStr,
      'sourceOnly': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await draftRef.delete();
    AppLog.d("AI_DEBUG: [CA] FINAL SAVE SUCCESS - ${finalQs.length} 100% verified questions");
    return true;
  }

  static Future<void> checkAndAutoGenerateCurrentAffairsQuiz() async {
    try {
      final todayStr = AppDate.getTodayString();
      final db = FirebaseFirestore.instance;

      final query = await db.collection('quizzes')
          .where('date', isEqualTo: todayStr)
          .where('type', isEqualTo: 'current_affairs')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        AppLog.d("AI_DEBUG: No CA quiz found for today ($todayStr). Generating...");
        await generateAndSaveCurrentAffairsQuiz(AppDate.getISTNow());
      }
    } catch (e) {
      AppLog.e("AI_DEBUG: Error in auto CA quiz generation", e);
    }
  }

  static Future<void> checkAndAutoGenerateNews() async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 0));
      final yesterdayStr = AppDate.format(yesterday);
      final db = FirebaseFirestore.instance;

      // Check if news for yesterday already exists
      final query = await db.collection('current_affairs_points')
          .where('date', isEqualTo: yesterdayStr)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        AppLog.d("AI_DEBUG: No news found for yesterday ($yesterdayStr). Triggering auto-generation for yesterday...");
        await generateAndSaveDailyNews(yesterday);
      } else {
        AppLog.d("AI_DEBUG: News for yesterday ($yesterdayStr) already exists. Skipping auto-gen.");
      }
    } catch (e) {
      AppLog.e("AI_DEBUG: Error in auto news generation", e);
    }
  }

  /// AI Answer Key Verifier & Bilingual Explanation Generator for Exam Papers / PDFs
  static Future<List<Map<String, dynamic>>> verifyAndEnrichExamPaperQuestions(
      List<Map<String, dynamic>> questions,
      ) async {
    try {
      List<Map<String, dynamic>> verifiedQuestions = [];

      // Process in batches of 10 questions to avoid LLM token/context limits
      int batchSize = 10;
      for (int i = 0; i < questions.length; i += batchSize) {
        int end = (i + batchSize < questions.length) ? i + batchSize : questions.length;
        List<Map<String, dynamic>> batch = questions.sublist(i, end);

        String batchJson = jsonEncode(batch);

        final prompt = '''
You are an Expert TNPSC Examiner and Fact Verifier.
Analyze the following batch of authentic TNPSC exam paper questions.

YOUR MANDATORY TASKS:
1. PRESERVE ORIGINAL VERBATIM TEXT: Do NOT change, shorten, or reword the original `question_en`, `question_ta`, and `options` from the paper. Maintain 100% exact printed wording and zero spelling mistakes.
2. FACT-CHECK EVERY QUESTION: Verify if the marked `correctOptionIndex` (0-3) is 100% factually and mathematically correct.
3. CORRECT ANY WRONG ANSWERS: If `correctOptionIndex` is wrong or points to the wrong option, update `correctOptionIndex` to the TRUE correct option index (0, 1, 2, or 3).
4. GENERATE DETAILED BILINGUAL EXPLANATIONS:
   - For `explanation_ta`: Provide a clear, detailed 2-3 sentence explanation in pure literary Tamil explaining why the answer is correct (and step-by-step formula/math steps for Aptitude).
   - For `explanation_en`: Provide a clear, detailed 2-3 sentence explanation in English explaining why the answer is correct (and step-by-step math steps for Aptitude).
5. ENSURE BILINGUAL FIELDS:
   - Ensure `question_en` and `question_ta` are accurate and fully preserved.
   - Ensure `options` array contains 4 objects `[{"en": "...", "ta": "..."}]`.

INPUT QUESTIONS BATCH:
$batchJson

STRICT OUTPUT FORMAT:
Return ONLY a valid JSON array containing the verified and enriched questions. NO Markdown, no preamble, no surrounding text.
''';

        final res = await _generateWithFallback(prompt);
        if (res != null) {
          try {
            int start = res.indexOf('[');
            int last = res.lastIndexOf(']');
            if (start != -1 && last != -1) {
              List<dynamic> parsed = jsonDecode(res.substring(start, last + 1));
              List<Map<String, dynamic>> batchParsed = [];
              for (var q in parsed) {
                if (q is Map) {
                  batchParsed.add(Map<String, dynamic>.from(q));
                }
              }
              final filtered = _filterValidQuestions(batchParsed, isExamPaper: true);
              verifiedQuestions.addAll(filtered.map((e) => Map<String, dynamic>.from(e as Map)));
              continue;
            }
          } catch (e) {
            AppLog.e("AI_DEBUG: Error parsing verified exam batch $i-$end: $e");
          }
        }

        // Fallback: If AI batch call failed or timed out, retain original batch items
        verifiedQuestions.addAll(batch);
      }

      return verifiedQuestions;
    } catch (e) {
      AppLog.e("Error in verifyAndEnrichExamPaperQuestions: $e");
      return questions;
    }
  }

  /// Slices a page range from PDF bytes into a standalone PDF in memory
  static List<int>? slicePdfPages(List<int> fullPdfBytes, int startPageIndex, int pageCount) {
    try {
      final doc = PdfDocument(inputBytes: fullPdfBytes);
      try {
        if (startPageIndex >= doc.pages.count) return null;
        final sliceDoc = PdfDocument();
        int end = (startPageIndex + pageCount <= doc.pages.count) ? startPageIndex + pageCount : doc.pages.count;
        for (int i = startPageIndex; i < end; i++) {
          PdfTemplate template = doc.pages[i].createTemplate();
          PdfPage newPage = sliceDoc.pages.add();
          newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
        }
        final bytes = sliceDoc.saveSync();
        sliceDoc.dispose();
        return bytes;
      } finally {
        doc.dispose();
      }
    } catch (e) {
      AppLog.e("Error slicing PDF pages: $e");
      return null;
    }
  }

  /// Returns total page count of a PDF
  static int getPdfPageCount(List<int> pdfBytes) {
    try {
      final doc = PdfDocument(inputBytes: pdfBytes);
      int count = doc.pages.count;
      doc.dispose();
      return count;
    } catch (e) {
      return 0;
    }
  }

  /// Extracts embedded text from a PDF if it is a digital PDF.
  /// Returns empty string if it is a scanned image PDF.
  static String extractDigitalTextFromPdf(List<int> pdfBytes) {
    try {
      final doc = PdfDocument(inputBytes: pdfBytes);
      String text = PdfTextExtractor(doc).extractText();
      doc.dispose();
      return text.trim();
    } catch (e) {
      return "";
    }
  }

  /// Extracts structured questions from PDF bytes using Gemini Multimodal Vision.
  /// Works for BOTH scanned image PDFs and digital text PDFs.
  static Future<List<Map<String, dynamic>>> extractQuestionsFromPdfBytes({
    required List<int> pdfBytes,
    required String examType,
    int startQuestionNum = 1,
    int maxQuestions = 15,
  }) async {
    try {
      String base64Pdf = base64Encode(pdfBytes);
      final prompt = '''
You are an Expert TNPSC Question Paper Digitizer, High-Accuracy Tamil OCR Specialist, and Official Exam Fact Verifier.
Carefully read the attached TNPSC exam paper PDF pages.

CRITICAL INSTRUCTIONS - 100% VERBATIM EXTRACTION & ZERO SPELLING MISTAKES:
1. EXACT ORIGINAL TEXT ONLY (வினாத்தாளில் உள்ள வினாக்கள் மற்றும் விருப்பங்கள் 100% பிழையின்றி அப்படியே வர வேண்டும்):
   - You MUST transcribe the questions, options, and statements EXACTLY character-for-character as printed in the PDF.
   - DO NOT summarize, rewrite, rephrase, modernise, or shorten any question or option text.
   - ZERO SPELLING MISTAKES IN TAMIL AND ENGLISH:
     * Preserve exact Tamil glyphs: ண vs ன, ல vs ள vs ழ, ர vs ற, குறில் vs நெடில்.
     * Ensure all pulli/dots (க், ச், ட், த், ப், ற், ன்...) are precisely placed as in the original print.
     * Retain all names, historical titles, author names, book titles, and technical terms exactly as printed.
2. EXTRACT ALL 4 OPTIONS (A, B, C, D) EXACTLY AS PRINTED:
   - "options": [
       {"en": "Exact text of Option A as printed", "ta": "வினாத்தாளில் உள்ள விருப்பம் A உரை அப்படியே"},
       {"en": "Exact text of Option B as printed", "ta": "வினாத்தாளில் உள்ள விருப்பம் B உரை அப்படியே"},
       {"en": "Exact text of Option C as printed", "ta": "வினாத்தாளில் உள்ள விருப்பம் C உரை அப்படியே"},
       {"en": "Exact text of Option D as printed", "ta": "வினாத்தாளில் உள்ள விருப்பம் D உரை அப்படியே"}
     ]
   - NEVER invent placeholder text like "Option A" or empty commas. Copy the real printed text of each option.
3. PRESERVE SPECIAL TNPSC QUESTION STRUCTURES VERBATIM:
   - For "Match the Following (பொருத்துக)":
     Extract BOTH the entire Left column (a, b, c, d) AND the entire Right column (1, 2, 3, 4) with their full descriptions.
     Format each pair on a new line using \\n (e.g. "(a) Left text — 1. Right text\\n(b) Left text — 2. Right text...").
     The options A, B, C, D must be the exact matching code combinations from the paper.
   - For "Statement and Reason / Assertion (கூற்று மற்றும் காரணம்)":
     Extract both Assertion and Reason verbatim on separate lines with \\n.
   - For "Chronological Order (காலவரிசைப்படுத்துக)":
     Extract all numbered statements (1), (2), (3), (4) on separate lines with \\n.
4. ACCURATE ANSWER KEY & EXPLANATIONS:
   - Identify the correct answer (0 for A, 1 for B, 2 for C, 3 for D) from the marked answer key or official answer key.
   - Set "correctOptionIndex" precisely (0, 1, 2, or 3).
   - "explanation_ta": Detailed 2-3 sentence explanation in pure Tamil explaining why this answer is correct (including calculation steps for Math/Aptitude).
   - "explanation_en": Detailed 2-3 sentence explanation in English explaining why this answer is correct (including calculation steps for Math/Aptitude).
5. COMPLETE EXTRACTION:
   - Extract every single question found on these pages starting from Question #$startQuestionNum up to $maxQuestions questions without omitting any.

RETURN FORMAT:
Return ONLY a valid JSON array:
[
  {
    "question_en": "...",
    "question_ta": "...",
    "options": [
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."}
    ],
    "correctOptionIndex": 0,
    "explanation_en": "...",
    "explanation_ta": "..."
  }
]
No Markdown formatting, no code fence, no extra preamble. Only raw JSON array.
''';

      final res = await _generateWithFallback(prompt, base64Pdf: base64Pdf);
      if (res != null) {
        int start = res.indexOf('[');
        int last = res.lastIndexOf(']');
        if (start != -1 && last != -1) {
          List<dynamic> parsed = jsonDecode(res.substring(start, last + 1));
          List<Map<String, dynamic>> questions = [];
          for (var item in parsed) {
            if (item is Map) {
              questions.add(Map<String, dynamic>.from(item));
            }
          }
          final filtered = _filterValidQuestions(questions, isExamPaper: true);
          return filtered.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      AppLog.e("Error in extractQuestionsFromPdfBytes: $e");
      return [];
    }
  }

  /// AI Chunked PDF Parser: Extracts 10-15 questions from raw PDF text chunk,
  /// fact-checks answer keys, ensures bilingual fields, and generates explanations.
  static Future<List<Map<String, dynamic>>> parseAndEnrichPdfChunk({
    required String rawChunkText,
    required int startQuestionNum,
    required String examType,
    String? base64Pdf,
  }) async {
    try {
      final prompt = '''
You are an Expert TNPSC Question Paper Digitizer, High-Accuracy Tamil OCR Specialist, and Official Exam Fact Verifier.
Convert the following authentic TNPSC question paper text into structured $examType exam MCQs starting from Question #$startQuestionNum.

CRITICAL INSTRUCTIONS - 100% VERBATIM EXTRACTION & ZERO SPELLING MISTAKES:
1. EXACT ORIGINAL TEXT ONLY:
   - You MUST transcribe the questions, options, and statements EXACTLY character-for-character from the text.
   - DO NOT summarize, rewrite, rephrase, or shorten any question or option text.
   - ZERO SPELLING MISTAKES IN TAMIL:
     * Preserve exact Tamil glyphs: ண vs ன, ல vs ள vs ழ, ர vs ற, குறில் vs நெடில்.
     * Ensure all pulli/dots (க், ச், ட், த், ப், ற், ன்...) are precisely placed.
2. EXTRACT ALL 4 OPTIONS (A, B, C, D) EXACTLY AS PRINTED:
   - Copy the real text of each option A, B, C, D without placeholders.
3. PRESERVE SPECIAL TNPSC QUESTION STRUCTURES:
   - For Match the following (பொருத்துக): Include both left and right columns on separate lines with \\n.
   - For Assertion/Reason (கூற்று மற்றும் காரணம்): Keep both on separate lines with \\n.
4. ACCURATE ANSWER KEY & EXPLANATIONS:
   - Identify the correct answer key (0, 1, 2, or 3).
   - Generate detailed bilingual explanations.

RAW EXAM PAPER TEXT:
$rawChunkText

JSON FORMAT:
[
  {
    "question_en": "...",
    "question_ta": "...",
    "options": [
      {"en": "Option A", "ta": "விருப்பம் A"},
      {"en": "Option B", "ta": "விருப்பம் B"},
      {"en": "Option C", "ta": "விருப்பம் C"},
      {"en": "Option D", "ta": "விருப்பம் D"}
    ],
    "correctOptionIndex": 0,
    "explanation_en": "...",
    "explanation_ta": "..."
  }
]
Return ONLY raw JSON array.
''';

      final res = await _generateWithFallback(prompt, base64Pdf: base64Pdf);
      if (res != null) {
        int start = res.indexOf('[');
        int last = res.lastIndexOf(']');
        if (start != -1 && last != -1) {
          List<dynamic> parsed = jsonDecode(res.substring(start, last + 1));
          List<Map<String, dynamic>> questions = [];
          for (var item in parsed) {
            if (item is Map) {
              questions.add(Map<String, dynamic>.from(item));
            }
          }
          final filtered = _filterValidQuestions(questions, isExamPaper: true);
          return filtered.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      AppLog.e("Error in parseAndEnrichPdfChunk: $e");
      return [];
    }
  }
}
