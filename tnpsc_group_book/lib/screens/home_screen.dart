import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tnpsc_group_book/services/deep_link_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subject.dart';
import '../utils/app_log.dart';
import '../utils/app_theme.dart';
import '../utils/app_icons.dart';
import '../utils/app_date.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/hive_service.dart';
import 'quiz_screen.dart';
import 'sub_topic_screen.dart';
import 'mistake_bank_screen.dart';
import 'bookmark_screen.dart';
import 'ai_smart_prep_screen.dart';
import 'ai_tutor_screen.dart';
import 'topic_detail_screen.dart';
import 'leaderboard_screen.dart';
import '../widgets/streak_badge.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/version_service.dart';
import '../services/tts_service.dart';
import 'room_setup_screen.dart';
import '../services/content_sync_service.dart';
import '../services/ai_service.dart';
import '../models/news_item.dart';
import 'news_detail_screen.dart';
import '../services/reward_service.dart';
import '../widgets/native_ad_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Future<DocumentSnapshot?>? _userDataFuture;
  bool _isCheckingNews = false;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _firestoreService.getUserData();
    _checkInitialSync();
    _ensurePointsRestored();
    _checkAutoNews();
    // AI_DEBUG: Check clipboard on home screen entry for room codes
    DeepLinkService().checkClipboard();
    // Silently purge old leaderboard data after a delay to not affect startup performance
    Future.delayed(const Duration(seconds: 5), () {
       _firestoreService.checkAndPerformSilentMaintenance();
    });
  }

  Future<void> _checkAutoNews() async {
    if (!mounted) return;
    setState(() => _isCheckingNews = true);
    // Wait a bit to not interfere with initial UI load
    await Future.delayed(const Duration(seconds: 2));
    await AiService.checkAndAutoGenerateNews();
    if (mounted) {
      setState(() => _isCheckingNews = false);
    }
  }

  Future<void> _ensurePointsRestored() async {
    // If local points are 0, try a background refresh to see if user has cloud points
    final userBox = Hive.box(HiveService.userBoxName);
    int localPoints = userBox.get('totalScore', defaultValue: 0) as int;
    
    if (localPoints == 0 && FirebaseAuth.instance.currentUser != null) {
      AppLog.d("AI_DEBUG: Local points are 0. Triggering background restoration...");
      await _firestoreService.getUserData(forceRefresh: true);
      if (mounted) setState(() {});
    }
  }

  Future<void> _checkInitialSync() async {
    bool required = await ContentSyncService.isSyncRequired();
    if (required) {
      // AI_DEBUG: Silent Background Sync - No overlay shown
      ContentSyncService.performInitialSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return SafeArea(
          child: FutureBuilder<DocumentSnapshot?>(
              future: _userDataFuture,
              builder: (context, snapshot) {
                String userName = AppLanguage.getString('user_fallback');
                int streak = 0;
                int totalPoints = 0;

                if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  userName = data['name'] ?? AppLanguage.getString('user_fallback');
                  streak = data['streak'] ?? 0;
                  totalPoints = data['totalScore'] ?? 0;

                  String lastActive = data['lastActiveDate'] ?? "";
                  String today = AppDate.getTodayString();
                  if (lastActive != "" && lastActive != today) {
                    try {
                      DateTime lastDate = AppDate.parse(lastActive);
                      DateTime istNow = AppDate.getISTNow();
                      int diff = DateTime(istNow.year, istNow.month, istNow.day).difference(lastDate).inDays;
                      if (diff > 1) streak = 0;
                    } catch (_) {}
                  }
                } else {
                  var cachedData = HiveService.getCachedUserData();
                  if (cachedData != null) {
                    userName = cachedData['name'] ?? AppLanguage.getString('user_fallback');
                    streak = cachedData['streak'] ?? 0;
                    totalPoints = cachedData['totalScore'] ?? 0;

                    String lastActive = cachedData['lastActiveDate'] ?? "";
                    String today = AppDate.getTodayString();
                    if (lastActive != "" && lastActive != today) {
                      try {
                        DateTime lastDate = AppDate.parse(lastActive);
                        DateTime istNow = AppDate.getISTNow();
                        int diff = DateTime(istNow.year, istNow.month, istNow.day).difference(lastDate).inDays;
                        if (diff > 1) streak = 0;
                      } catch (_) {}
                    }
                  }
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section (Greeting & Stats)
                          RepaintBoundary(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${AppLanguage.getString('greeting')},",
                                          style: AppTheme.getStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : AppTheme.textMainColor,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                "$userName! 👋",
                                                style: AppTheme.getStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : AppTheme.textMainColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (streak >= 7) ...[
                                              const SizedBox(width: 2),
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 4.0),
                                                child: StreakBadge(streak: streak),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          AppLanguage.getString('ready_to_crack'),
                                          style: AppTheme.getStyle(
                                            fontSize: 14,
                                            color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      ValueListenableBuilder(
                                        valueListenable: Hive.box(HiveService.userBoxName).listenable(),
                                        builder: (context, box, child) {
                                          int s = box.get('streak', defaultValue: streak) as int;
                                          // Broken streak check for real-time Hive listener
                                          String lastActive = box.get('lastActiveDate', defaultValue: "") as String;
                                          String today = AppDate.getTodayString();
                                          if (lastActive != "" && lastActive != today) {
                                            try {
                                              DateTime lastDate = AppDate.parse(lastActive);
                                              DateTime istNow = AppDate.getISTNow();
                                              int diff = DateTime(istNow.year, istNow.month, istNow.day).difference(lastDate).inDays;
                                              if (diff > 1) s = 0;
                                            } catch (_) {}
                                          }

                                          return _buildHeaderStat(
                                            icon: Icons.local_fire_department_rounded,
                                            label: "$s ${AppLanguage.getString('days')}",
                                            colors: [Colors.orange, Colors.deepOrange],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      ValueListenableBuilder(
                                          valueListenable: Hive.box(
                                            HiveService.userBoxName,
                                          ).listenable(),
                                          builder: (context, box, child) {
                                            int points =
                                            box.get('totalScore', defaultValue: totalPoints) as int;
                                            return _buildHeaderStat(
                                              icon: Icons.stars_rounded,
                                              label: "$points pts",
                                              colors: [Colors.blue, Colors.indigo],
                                            );})
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Listening Now Mini Player
                          ValueListenableBuilder<String?>(
                            valueListenable: TtsService.currentTextNotifier,
                            builder: (context, playingText, _) {
                              if (playingText == null) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                child: RepaintBoundary(child: _buildMiniPlayer(context, playingText, isDark)),
                              );
                            },
                          ),

                          // Main Content
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Daily Quiz Highlight
                                RepaintBoundary(
                                  child: ValueListenableBuilder(
                                    valueListenable: Hive.box(HiveService.userBoxName).listenable(keys: ['dailyquiz_last_completed_date']),
                                    builder: (context, box, child) {
                                      return _buildDailyQuizCard(context, isDark);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: RepaintBoundary(
                                    child: Row(
                                          children: [
                                            _buildQuickActionCard(context, title: AppLanguage.getString('mistake_bank'), icon: "📝", color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MistakeBankScreen()))),
                                            const SizedBox(width: 12),
                                            _buildQuickActionCard(context, title: AppLanguage.getString('saved_quizzes'), icon: "🔖", color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BookmarkScreen()))),
                                            const SizedBox(width: 12),
                                            _buildQuickActionCard(context, title: AppLanguage.getString('group_test_lobby'), icon: "👥", color: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RoomSetupScreen()))),
                                          ],
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Current Affairs Section
                                RepaintBoundary(child: _buildCurrentAffairsSection(context, isDark)),
                                const SizedBox(height: 32),

                                // Smart Weak Area Analysis Card
                                RepaintBoundary(child: _buildSmartWeakAreaAnalysis(context, isDark)),
                                const SizedBox(height: 50),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        );
      },
    );
  }

  Widget _buildMiniPlayer(BuildContext context, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withValues(alpha: 0.8), AppTheme.primaryColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        children: [
          const AppIcon(Icons.spatial_audio_off_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLanguage.getString('listening_now'),
                  style: AppTheme.getStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.getStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => TtsService.stop(),
            icon: const AppIcon(Icons.stop_circle_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat({required IconData icon, required String label, required List<Color> colors}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyQuizCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? AppTheme.primaryColorLight : AppTheme.secondaryColorLight,width: 0.6),
        gradient: LinearGradient(
          colors: [isDark ? AppTheme.primaryColorGlass : AppTheme.primaryColorLight, isDark ? AppTheme.secondaryColorGlass : AppTheme.secondaryColorLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("🧠", style: AppTheme.getStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  AppLanguage.getString('daily_quiz'),
                  style: AppTheme.getStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppLanguage.getString('today_quiz_ready'),
            style: AppTheme.getStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: HiveService.isDailyQuizDone()
                ? null
                : () => _showQuizInfoBottomSheet(context, AppLanguage.getString('daily_quiz'), isDark),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.7),
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 5,
              ),
              child: Text(
                HiveService.isDailyQuizDone() ? AppLanguage.getString('completed') : AppLanguage.getString('start_quiz'),
                style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showQuizInfoBottomSheet(BuildContext context, String quizTitle, bool isDark) {
    bool isDaily = quizTitle == AppLanguage.getString('daily_quiz') || quizTitle == "Daily Quiz";
    int questionCount = isDaily ? 20 : 50;
    int bonusPoints = 20;
    int adPoints = 15; // Average/Initial ad bonus

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                quizTitle,
                style: AppTheme.getStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textMainColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLanguage.languageNotifier.value == 'ta' 
                  ? "இந்தத் தேர்வில் நீங்கள் எவ்வளவு பாயிண்ட்டுகள் எடுக்கலாம்?"
                  : "How many points can you earn in this quiz?",
                style: AppTheme.getStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 32),
              _buildInfoRow(
                icon: Icons.check_circle_rounded,
                color: Colors.green,
                label: AppLanguage.languageNotifier.value == 'ta' ? "சரியான பதில்" : "Correct Answer",
                value: "+2 pts",
              ),
              const Divider(height: 32),
              _buildInfoRow(
                icon: Icons.auto_awesome_rounded,
                color: Colors.orange,
                label: AppLanguage.languageNotifier.value == 'ta' ? "முழுமை செய்தற்கான போனஸ்" : "Completion Bonus",
                value: "+$bonusPoints pts",
              ),
              const Divider(height: 32),
              _buildInfoRow(
                icon: Icons.play_circle_fill_rounded,
                color: Colors.blue,
                label: AppLanguage.languageNotifier.value == 'ta' ? "விளம்பரம் பார்த்தால்" : "With Reward Ad",
                value: "+$adPoints pts",
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    if (await VersionService.isUpdateRequired()) {
                      if (context.mounted) VersionService.showUpdateDialogIfNeeded(context);
                      return;
                    }
                    if (context.mounted) {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => QuizScreen(subjectTitle: quizTitle)
                        )
                      ).then((_) => setState(() {}));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    AppLanguage.getString('start_quiz'),
                    style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow({required IconData icon, required Color color, required String label, required String value}) {
    bool isDark = AppTheme.themeNotifier.value == ThemeMode.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: AppTheme.getStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.textMainColor,
            ),
          ),
        ),
        Text(
          value,
          style: AppTheme.getStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(BuildContext context, {required String title, required String icon, required Color color, required VoidCallback onTap}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: AppTheme.getStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTheme.getStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : color.darken(),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartWeakAreaAnalysis(BuildContext context, bool isDark) {
    bool isTamil = AppLanguage.languageNotifier.value == 'ta';
    
    final tamilPerf = HiveService.getCategoryPerformance('general_tamil');
    final gsPerf = HiveService.getCategoryPerformance('general_studies');
    final aptitudePerf = HiveService.getCategoryPerformance('aptitude');

    // Determine weakest area(s)
    List<String> weakestCategories = [];
    double lowestPercent = 101;

    void checkWeakest(String key, Map<String, dynamic> perf) {
      double correctPercent = perf['correctPercent'];
      if (correctPercent < lowestPercent) {
        lowestPercent = correctPercent;
        weakestCategories = [key];
      } else if (correctPercent == lowestPercent) {
        weakestCategories.add(key);
      }
    }

    checkWeakest("general_tamil", tamilPerf);
    checkWeakest("general_studies", gsPerf);
    checkWeakest("aptitude", aptitudePerf);

    bool hasAnyAttempt = tamilPerf['total'] > 0 || gsPerf['total'] > 0 || aptitudePerf['total'] > 0;

    String recommendation = "";
    Color boxColor = Colors.blue;
    IconData boxIcon = Icons.rocket_launch_rounded;

    if (hasAnyAttempt && weakestCategories.isNotEmpty && lowestPercent < 75) {
      List<String> catNames = [];
      for (var cat in weakestCategories) {
        if (cat == 'general_tamil') catNames.add(isTamil ? 'பொது தமிழ்' : 'General Tamil');
        else if (cat == 'general_studies') catNames.add(isTamil ? 'பொது அறிவு' : 'General Studies');
        else if (cat == 'aptitude') catNames.add(isTamil ? 'கணிதத் திறன்' : 'Aptitude');
      }

      String joinedNames = catNames.join(', ');
      if (catNames.length > 1) {
        recommendation = AppLanguage.getString('focus_recommendation_plural').replaceAll('{categories}', joinedNames);
      } else {
        recommendation = AppLanguage.getString('focus_recommendation').replaceAll('{category}', joinedNames);
      }
      boxColor = Colors.orange;
      boxIcon = Icons.lightbulb_outline_rounded;
    } else if (hasAnyAttempt && lowestPercent >= 75 && lowestPercent <= 100) {
      recommendation = AppLanguage.getString('excellent_work');
      boxColor = Colors.green;
      boxIcon = Icons.emoji_events_outlined;
    } else {
      recommendation = AppLanguage.getString('start_prep_recommendation');
      boxColor = Colors.blue;
      boxIcon = Icons.rocket_launch_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strength Insights
        Text(
          AppLanguage.getString('your_strength'),
          style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppTheme.secondaryColor : AppTheme.textMainColor),
        ),
        const SizedBox(height: 16),
        // Group the progress items one-by-one with clear separation
        _buildHomeCategoryProgress(
          context,
          categoryKey: "general_tamil",
          correct: tamilPerf['correct']!,
          total: tamilPerf['total']!,
          icon: Icons.translate_rounded,
          color: Colors.blue,
        ),
        _buildHomeCategoryProgress(
          context,
          categoryKey: "general_studies",
          correct: gsPerf['correct']!,
          total: gsPerf['total']!,
          icon: Icons.school_rounded,
          color: Colors.purple,
        ),
        _buildHomeCategoryProgress(
          context,
          categoryKey: "aptitude",
          correct: aptitudePerf['correct']!,
          total: aptitudePerf['total']!,
          icon: Icons.calculate_rounded,
          color: Colors.orange,
        ),
        
        if (recommendation.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: boxColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: boxColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  boxIcon, 
                  color: boxColor, 
                  size: 24
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    recommendation,
                    style: AppTheme.getStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? boxColor.withValues(alpha: 0.9) : boxColor.darken(0.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHomeCategoryProgress(
    BuildContext context, {
    required String categoryKey,
    required int correct,
    required int total,
    required IconData icon,
    required Color color,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isTamil = AppLanguage.languageNotifier.value == 'ta';

    // Calculate stats
    int attempted = total;
    int wrong = attempted - correct;
    double correctPercentage = attempted > 0 ? (correct / attempted) * 100 : 0;

    // Determine progress color based on overall accuracy (same as before)
    double accuracy = correctPercentage;
    Color progressColor = Colors.redAccent;
    if (accuracy >= 75) {
      progressColor = Colors.green;
    } else if (accuracy >= 50) {
      progressColor = Colors.orange;
    }

    // Category name localization
    String categoryName = "";
    if (categoryKey == 'general_tamil')
      categoryName = isTamil ? 'பொது தமிழ்' : 'General Tamil';
    else if (categoryKey == 'general_studies')
      categoryName = isTamil ? 'பொது அறிவு' : 'General Studies';
    else if (categoryKey == 'aptitude')
      categoryName = isTamil ? 'கணிதத் திறன் & மனத்திறன்' : 'Aptitude & Mental Ability';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.only(left: 20,right: 20,top: 15,bottom: 15),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: accuracy / 100),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with icon, name and percentage (Mastery style)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      categoryName,
                      style: AppTheme.getStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textMainColor,
                      ),
                      // maxLines: 1,
                      // overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    "${(value * 100).toInt()}%",
                    style: AppTheme.getStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Progress bar (Mastery style)
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: progressColor.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    isTamil ? "$correct / $total சரி" : "$correct / $total Correct",
                    style: AppTheme.getStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentAffairsSection(BuildContext context, bool isDark) {
    bool isTamil = AppLanguage.languageNotifier.value == 'ta';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              isTamil ? "இன்றைய நடப்பு நிகழ்வுகள்" : "Daily Current Affairs",
              style: AppTheme.getStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.secondaryColor : AppTheme.textMainColor,
              ),
            ),
            if (_isCheckingNews) ...[
              const SizedBox(width: 8),
              const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
            ]
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('current_affairs_points')
              .orderBy('timestamp', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    isTamil ? "செய்திகள் எதுவும் இல்லை" : "No news available",
                    style: AppTheme.getStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                shrinkWrap: true,
                itemCount: snapshot.data!.docs.length + 1, // +1 for the Ad card
                itemBuilder: (context, index) {
                  if (index == snapshot.data!.docs.length) {
                    return _buildHorizontalAdCard(isDark);
                  }
                  try {
                    NewsItem news = NewsItem.fromFirestore(snapshot.data!.docs[index]);
                    return _buildNewsCard(context, news, isDark, isTamil);
                  } catch (e) {
                    return const SizedBox.shrink();
                  }
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNewsCard(BuildContext context, NewsItem news, bool isDark, bool isTamil) {
    String title = isTamil ? news.titleTa : news.titleEn;
    return GestureDetector(
      onTap: () {
        RewardService.showInterstitialAd(
          onDismissed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NewsDetailScreen(newsItem: news),
              ),
            );
          },
        );
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
              ? [Colors.indigo.shade500.withOpacity(0.2), Colors.cyan.shade100.withOpacity(0.2)]
              : [Colors.white, Colors.blue.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white24 : Colors.blue.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.secondaryColor.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    news.category,
                    style: AppTheme.getStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.secondaryColor : AppTheme.primaryColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  AppDate.getDisplayDate(news.timestamp),
                  style: AppTheme.getStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87,fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.getStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.textMainColor,
                ),
              ),
            ),
            // const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.play_circle_fill_rounded, color: isDark ? AppTheme.secondaryColor : AppTheme.primaryColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  isTamil ? "விளம்பரம் மற்றும் செய்தி" : "Ad & News",
                  style: AppTheme.getStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.secondaryColor : AppTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalAdCard(bool isDark) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.blue.shade50),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: NativeAdWidget(isSmall: false,  refreshIntervalSeconds: 90),
        ),
      ),
    );
  }

  Widget _buildMasteryRow(String label, double targetProgress, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: targetProgress),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label, 
                    style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text("${(value * 100).toInt()}%", style: AppTheme.getStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ],
        );
      },
    );
  }
}

void openSubject(BuildContext context, Subject subject) {
  if (subject.topics.isNotEmpty) {
    showSubjectTopicsBottomSheet(context, subject);
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TopicDetailScreen(
          topic: subject.title,
          category: "General",
        ),
      ),
    );
  }
}

void showSubjectTopicsBottomSheet(BuildContext context, Subject subject) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      bool isDark = Theme.of(context).brightness == Brightness.dark;
      
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.glassWhite(context),
              border: Border(
                top: BorderSide(color: AppTheme.glassBorder(context), width: 0),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        subject.title,
                        style: AppTheme.getStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textMainColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: AppIcon(AppIcons.close, color: isDark ? Colors.white : Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppLanguage.getString('select_category'),
                  style: AppTheme.getStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                ...subject.topics.asMap().entries.map((entry) {
                  int idx = entry.key;
                  String topic = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        if (subject.getSubTopics(idx).isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubTopicScreen(subject: subject, topicIndex: idx),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TopicDetailScreen(
                                topic: topic,
                                category: subject.title,
                              ),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: subject.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: subject.color.withOpacity(0.2), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                topic,
                                style: AppTheme.getStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppTheme.textMainColor,
                                ),
                              ),
                            ),
                            AppIcon(AppIcons.forward, color: subject.color, size: 18),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openSubject(context, subject),
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.glassWhite(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.glassBorder(context), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: subject.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(subject.icon, color: subject.color, size: 28),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        subject.title,
                        textAlign: TextAlign.center,
                        style: AppTheme.getStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textMainColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subject.subtitle,
                        textAlign: TextAlign.center,
                        style: AppTheme.getStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textSecondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final String title;
  final String subject;
  final String edition;

  const _BookCard({
    required this.title,
    required this.subject,
    required this.edition,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 60,
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : Colors.black,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "PDF",
                      style: AppTheme.getStyle(
                        color: isDark ? Colors.black : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.getStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subject,
            style: AppTheme.getStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            edition,
            style: AppTheme.getStyle(
              fontSize: 10,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

extension ColorExtension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsv = HSVColor.fromColor(this);
    final hsvDark = hsv.withValue((hsv.value - amount).clamp(0.0, 1.0));
    return hsvDark.toColor();
  }
}
