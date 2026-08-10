import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;
import 'package:tnpsc_group_book/utils/app_date.dart';
import '../utils/app_log.dart';
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
    // Deterministic selection based on day of month + year to ensure rotation
    int seed = date.day + date.month + date.year;
    List<Map<String, dynamic>> selected = [];
    
    for (int i = 0; i < count; i++) {
      int index = (seed + i) % _languageTopics.length;
      selected.add(_languageTopics[index]);
    }

    return selected.map((t) => "- ${t['title']}: ${t['desc']}").join("\n");
  }

  static String _getAptitudeTopicsForDate(DateTime date, int count) {
    int seed = date.day + (date.month * 2) + date.year; // Different seed than language
    List<Map<String, dynamic>> selected = [];
    
    for (int i = 0; i < count; i++) {
      int index = (seed + i) % _aptitudeTopics.length;
      selected.add(_aptitudeTopics[index]);
    }

    return selected.map((t) => "- ${t['title']}: ${t['desc']}").join("\n");
  }

  static String _getGsTopicsForDate(DateTime date, int count) {
    int seed = date.day + (date.month * 3) + date.year; // Different seed
    List<Map<String, dynamic>> selected = [];
    
    for (int i = 0; i < count; i++) {
      int index = (seed + i) % _gsTopics.length;
      selected.add(_gsTopics[index]);
    }

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
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-pro',
    ];
  }

  static Future<String?> _generateWithFallback(String prompt) async {
    // 0. Check Sticky Config First
    final sticky = HiveService.getStickyAiConfig();
    if (sticky != null) {
      String sKey = sticky['key'] ?? "";
      String sModel = sticky['model'] ?? "";
      String sVersion = sticky['version'] ?? "";
      
      if (sKey.isNotEmpty && sModel.isNotEmpty && sVersion.isNotEmpty) {
        AppLog.d("AI_DEBUG: Using Sticky Config - Model: $sModel, Version: $sVersion");
        final res = await _tryModelRequest(sKey, sModel, sVersion, prompt);
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

      // 3. Try each model (v1beta then v1)
      bool keyFailed = false;
      for (String version in ['v1beta', 'v1']) { // Try v1beta first for newer models
        if (keyFailed) break;
        for (String modelName in finalModelsToTry) {
          final res = await _tryModelRequest(apiKey, modelName, version, prompt, onKeyInvalid: () => keyFailed = true);
          if (res != null) {
            // SUCCESS! Save this as the sticky config for the rest of the day
            AppLog.d("AI_DEBUG: Saving new Sticky Config: $modelName on $version");
            await HiveService.saveStickyAiConfig(apiKey, modelName, version);
            return res;
          }
          if (keyFailed) break;
        }
      }
      // If we reach here and keyFailed is true, the outer loop continues to next API key
    }
    return null;
  }

  static Future<String?> _tryModelRequest(String apiKey, String modelName, String version, String prompt, {Function? onKeyInvalid}) async {
    int retries = 0;
    const int maxRetries = 2;

    while (retries <= maxRetries) {
      try {
        AppLog.d("AI_DEBUG: REST Call - Trying $modelName on $version (Attempt ${retries + 1})...");
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/$version/models/$modelName:generateContent?key=$apiKey',
        );

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt},
                    ],
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
                  'temperature': 0.9,
                  'topP': 0.95,
                  'topK': 40,
                  'maxOutputTokens': 8192,
                },
              }),
            )
            .timeout(const Duration(seconds: 90));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidate = data['candidates'][0];
          if (candidate['finishReason'] != 'STOP') {
            AppLog.d("AI_DEBUG: Model finished with reason: ${candidate['finishReason']}");
            return null; // Try next model
          }

          String? text = candidate['content']['parts'][0]['text'];
          if (text != null) {
            text = text.trim();
            final jsonRegex = RegExp(r'\[.*\]|\{.*\}', dotAll: true);
            final match = jsonRegex.stringMatch(text);
            if (match != null) {
              text = match.trim();
            }

            try {
              jsonDecode(text);
              return text;
            } catch (e) {
              AppLog.d("AI_DEBUG: JSON Decode failed for: ${text.substring(0, text.length > 50 ? 50 : text.length)}...");
              return null; // Try next model
            }
          }
        } else if (response.statusCode == 429) {
          AppLog.d("AI_DEBUG: Rate limit reached (429). Retrying after backoff...");
          await Future.delayed(Duration(seconds: 2 * (retries + 1)));
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

  static Future<bool> generateAndSaveDailyQuiz(DateTime date) async {
    // If we're generating for 'today' or 'tomorrow', we should ensure the input date is interpreted correctly.
    // To be safe, we format the passed date object using en_US.
    final dateStr = AppDate.format(date);

    // Get topics from last 30 days to avoid repeats
    String recentContext = await _getRecentQuizContext('quizzes', 30);

    // Get Focus Topics for the day (Select 4 Language, 3 Aptitude, 3 GS)
    String focusTopics = _getLanguageTopicsForDate(date, 4);
    String focusAptitude = _getAptitudeTopicsForDate(date, 3);
    String focusGS = _getGsTopicsForDate(date, 3);

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
30. Validate every answer before returning JSON.

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
Generate exactly 10 UNIQUE TNPSC General Language MCQs. 
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
Generate exactly 6 UNIQUE TNPSC General Studies MCQs.
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
Generate exactly 4 UNIQUE TNPSC Aptitude & Mental Ability MCQs.
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
    // Daily quiz generation with quiz_type tagging
    List<dynamic> allQuestions = [];

    // Helper to fetch questions and tag them with a quiz_type
    Future<void> fetchAndTag(
      String prompt,
      String quizType,
      int expectedCount,
    ) async {
      final res = await _generateWithFallback(prompt);
      if (res != null) {
        try {
          // Note: _generateWithFallback already trims and handles code blocks
          List q = jsonDecode(res);

          // Validation: Trim if more, fail if less
          if (q.length > expectedCount) q = q.sublist(0, expectedCount);
          if (q.length < expectedCount) {
            AppLog.d(
              "AI_DEBUG: Count mismatch for $quizType. Got ${q.length}, expected $expectedCount",
            );
            return;
          }

          allQuestions.addAll(
            q.map((item) => {...item, 'quiz_type': quizType}),
          );
        } catch (e) {
          AppLog.d("AI_DEBUG: JSON Decode Error in fetchAndTag ($quizType): $e");
        }
      }
    }

    // Fetch each category and tag appropriately
    await fetchAndTag(promptTamil, 'general_tamil', 10);
    await fetchAndTag(promptGS, 'general_studies', 6);
    await fetchAndTag(promptAptitude, 'aptitude', 4);

    if (allQuestions.length != 20) return false; // Ensure exactly 20 total

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
      await FirebaseFirestore.instance.collection('quizzes').add(quizData);
    }
    return true;
  }

  static Future<bool> generateAndSaveMockQuiz(DateTime date) async {
    final dateStr = AppDate.format(date);

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
30. Validate every answer before returning JSON.

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
    List<dynamic> allQuestions = [];

    // Helper for batched generation
    Future<bool> fetchBatch(String prompt, String quizType, int expectedCount) async {
      AppLog.d("AI_DEBUG: Generating $expectedCount $quizType Questions...");
      final res = await _generateWithFallback(prompt);
      if (res != null) {
        try {
          List<dynamic> batch = jsonDecode(res);
          if (batch.length > expectedCount) batch = batch.sublist(0, expectedCount);
          if (batch.length == expectedCount) {
            allQuestions.addAll(
              batch.map((q) => {...q, 'quiz_type': quizType}),
            );
            return true;
          } else {
            AppLog.d("AI_DEBUG: $quizType batch count mismatch. Got ${batch.length}, expected $expectedCount");
          }
        } catch (e) {
          AppLog.d("AI_DEBUG: $quizType JSON Parse Error: $e");
        }
      }
      return false;
    }

    // 1️⃣ Tamil questions - Split into 2 batches to prevent timeout
    final promptTamil1 = promptTamil.replaceFirst("exactly 25", "exactly 13");
    final promptTamil2 = promptTamil.replaceFirst("exactly 25", "exactly 12");

    if (!await fetchBatch(promptTamil1, 'general_tamil', 13)) return false;
    if (!await fetchBatch(promptTamil2, 'general_tamil', 12)) return false;

    // 2️⃣ General Studies - 1 batch
    if (!await fetchBatch(promptGS, 'general_studies', 15)) return false;

    // 3️⃣ Aptitude - 1 batch
    if (!await fetchBatch(promptAptitude, 'aptitude', 10)) return false;

    // --------------------------------------------------------------------
    if (allQuestions.length == 50) {
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
        await FirebaseFirestore.instance.collection('mock_tests').add(quizData);
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
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC Current Affairs (நடப்பு நிகழ்வுகள்) MCQs. 
Focus on important events from the last 6 months, including Government Schemes, Awards, Sports, and Books.

STRICT LANGUAGE REQUIREMENTS (CRITICAL):
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages.
3. Ensure there are NO spelling mistakes.
''';
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

          if (questions.length < 20) return false;

          final docRef = FirebaseFirestore.instance.collection('room_predefined_quizzes').doc(subject);

          // AI_DEBUG: Sliding Window Logic (Max 1500 questions)
          // 1. Fetch existing pool to maintain size
          final snap = await docRef.get();
          List<dynamic> existingQs = [];
          if (snap.exists) {
            existingQs = List.from(snap.get('questions') ?? []);
          }

          // 2. Prepare new questions
          List<dynamic> sanitizedNewQs = questions.map((q) => {
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

          // STRICT VALIDATION: Ensure exactly 'count' questions
          if (allQuestions.length != count) {
            AppLog.d(
              "AI_DEBUG: Count mismatch. Got ${allQuestions.length}, expected $count. Retrying logic...",
            );
            // If too many, trim. If too few, this attempt failed.
            if (allQuestions.length > count) {
              allQuestions = allQuestions.sublist(0, count);
            } else {
              return false;
            }
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
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC Current Affairs (நடப்பு நிகழ்வுகள்) MCQs. 
Focus on important events from the last 6 months, including Government Schemes, Awards, Sports, and Books.

STRICT LANGUAGE REQUIREMENTS (CRITICAL):
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages.
3. Ensure there are NO spelling mistakes.
''';
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
        if (start != -1 && end != -1)
          return jsonDecode(res.substring(start, end + 1));
      } catch (e) {}
    }
    return [];
  }

  static Future<bool> generateAndSaveDailyNews(DateTime date) async {
    final dateStr = AppDate.format(date);
    
    final prompt = '''
Generate 10 important Current Affairs news items for TNPSC exams for the date $dateStr.
Focus on Tamil Nadu events, National news, Awards, and Sports.

STRICT LANGUAGE REQUIREMENTS (CRITICAL):
1. USE ONLY Pure Tamil and Pure English.
2. NO MIXED LANGUAGE: Do not mix English and Tamil in the same sentence.
3. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Sanskrit, or any other languages. No Hindi words in brackets.
4. Ensure there are NO spelling mistakes in Tamil or English.

Strictly use this BILINGUAL JSON format:
[
  {
    "titleEn": "English Title",
    "titleTa": "தமிழ் தலைப்பு",
    "contentEn": "Detailed news content in English (2-10 concise bullet points)",
    "contentTa": "செய்தியின் விரிவான விளக்கம் தமிழில் (2-10 முக்கியமான குறிப்புகள் - point by point)",
    "category": "Tamil Nadu / National / International / Sports"
  }
]
Only return the raw JSON array. No preamble, no markdown, no explanation.
''';

    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> newsItems = jsonDecode(res.substring(start, end + 1));
          final db = FirebaseFirestore.instance;
          
          for (var item in newsItems) {
            await db.collection('current_affairs_points').add({
              ...item,
              'date': dateStr,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
          return true;
        }
      } catch (e) {
        AppLog.d("AI_DEBUG: News Generation Parse Error: $e");
      }
    }
    return false;
  }

  static Future<void> checkAndAutoGenerateNews() async {
    try {
      final todayStr = AppDate.getTodayString();
      final db = FirebaseFirestore.instance;
      
      // Check if news for today already exists
      final query = await db.collection('current_affairs_points')
          .where('date', isEqualTo: todayStr)
          .limit(1)
          .get();
          
      if (query.docs.isEmpty) {
        AppLog.d("AI_DEBUG: No news found for today ($todayStr). Triggering auto-generation...");
        await generateAndSaveDailyNews(AppDate.getISTNow());
      } else {
        AppLog.d("AI_DEBUG: News for today ($todayStr) already exists. Skipping auto-gen.");
      }
    } catch (e) {
      AppLog.e("AI_DEBUG: Error in auto news generation", e);
    }
  }
}
