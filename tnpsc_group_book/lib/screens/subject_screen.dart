import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/ai_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/subject.dart';
import '../utils/app_theme.dart';
import '../utils/app_icons.dart';
import '../utils/app_date.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/hive_service.dart';
import 'topic_detail_screen.dart';
import 'sub_topic_screen.dart';
import 'mock_test_screen.dart';
import 'mistake_bank_screen.dart';
import 'bookmark_screen.dart';
import 'history_screen.dart';
import 'ai_smart_prep_screen.dart';
import 'ai_tutor_screen.dart';
import 'quiz_screen.dart';
import 'leaderboard_screen.dart';
import 'room_setup_screen.dart';
import '../models/news_item.dart';
import 'news_detail_screen.dart';
import '../services/reward_service.dart';
import '../widgets/streak_badge.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/native_ad_widget.dart';
import '../services/version_service.dart';

extension ColorExtension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsv = HSVColor.fromColor(this);
    final hsvDark = hsv.withValue((hsv.value - amount).clamp(0.0, 1.0));
    return hsvDark.toColor();
  }
}

class SubjectScreen extends StatefulWidget {
  const SubjectScreen({super.key});

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Future<DocumentSnapshot?>? _userDataFuture;
  bool _isCheckingNews = false;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _firestoreService.getUserData();
    _checkNews();
  }

  Future<void> _checkNews() async {
    setState(() => _isCheckingNews = true);
    try {
      await AiService.checkAndAutoGenerateNews();
    } catch (_) {}
    if (mounted) setState(() => _isCheckingNews = false);
  }

  void _showQuizInfoBottomSheet(BuildContext context, String quizTitle, bool isDark) {
    int bonusPoints = 20;
    int adPoints = 15;

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
              const SizedBox(height: 50),
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
                } else {
                  var cachedData = HiveService.getCachedUserData();
                  if (cachedData != null) {
                    userName = cachedData['name'] ?? AppLanguage.getString('user_fallback');
                    streak = cachedData['streak'] ?? 0;
                    totalPoints = cachedData['totalScore'] ?? 0;
                  }
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Stats Row
                          Padding(
                            padding: const EdgeInsets.only(left: 20.0, right: 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "${AppLanguage.getString('greeting')}, $userName!  👋",
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
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Text(
                                    AppLanguage.getString('ready_to_crack'),
                                    style: AppTheme.getStyle(
                                      fontSize: 16,
                                      color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Divider(endIndent: 20, indent: 20, color: isDark ? Colors.white : AppTheme.textMainColor, thickness: 0.25),

                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
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
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: Text(
                              AppLanguage.getString('subjects'),
                              style: AppTheme.getStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? AppTheme.secondaryColor : AppTheme.textMainColor),
                            ),
                          ),
                        ]),
                      ),
                    ),

                    // Subjects Grid
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 7,
                          mainAxisSpacing: 7,
                          childAspectRatio: 0.82,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final subject = tnpscSubjects[index];
                            return AnimationConfiguration.staggeredGrid(
                              position: index,
                              duration: const Duration(milliseconds: 375),
                              columnCount: 3,
                              child: ScaleAnimation(
                                child: FadeInAnimation(
                                  child: RepaintBoundary(child: _SubjectCard(subject: subject)),
                                ),
                              ),
                            );
                          },
                          childCount: (tnpscSubjects.length ~/ 3) * 3,
                        ),
                      ),
                    ),

                    if (tnpscSubjects.length % 3 != 0)
                      SliverPadding(
                        padding: const EdgeInsets.only(left: 10, right: 10, top: 7),
                        sliver: SliverToBoxAdapter(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double itemWidth = (constraints.maxWidth - (2 * 7)) / 3;
                              final int startIndex = (tnpscSubjects.length ~/ 3) * 3;
                              final int remainingCount = tnpscSubjects.length % 3;
                              
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(remainingCount, (i) {
                                  final index = startIndex + i;
                                  final subject = tnpscSubjects[index];
                                  return Padding(
                                    padding: EdgeInsets.only(left: i > 0 ? 7 : 0),
                                    child: SizedBox(
                                      width: itemWidth,
                                      child: AspectRatio(
                                        aspectRatio: 0.82,
                                        child: AnimationConfiguration.staggeredGrid(
                                          position: index,
                                          duration: const Duration(milliseconds: 375),
                                          columnCount: 3,
                                          child: ScaleAnimation(
                                            child: FadeInAnimation(
                                              child: RepaintBoundary(child: _SubjectCard(subject: subject)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        child: NativeAdWidget(isSmall: true),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 50)),
                  ],
                );
              },
            ),
          );
      },
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
                    return NativeAdWidget(
                      isSmall: false, 
                      refreshIntervalSeconds: 90,
                      width: 280,
                      height: 180,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.blue.shade50),
                      ),
                    );
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

  Widget _buildHeaderStat({required IconData icon, required String label, required List<Color> colors}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors.first.withAlpha(77), blurRadius: 8)],
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

  Widget _buildHorizontalExamCard(BuildContext context, String key, String icon, Color color) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MockTestScreen(category: key))),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
              ? [color.withAlpha(51), color.withAlpha(102)]
              : [color.withOpacity(0.7), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: Colors.white.withAlpha(26)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Text(icon, style: AppTheme.getStyle(fontSize: 24)),
            ),
            const SizedBox(height: 8),
            Text(
              AppLanguage.getString(key),
              textAlign: TextAlign.center,
              style: AppTheme.getStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  const _SubjectCard({required this.subject, Key? key}) : super(key: key);

  void _showTopicsBottomSheet(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
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
                  Flexible(
                    child: Text(
                      AppLanguage.getString('select_category'),
                      style: AppTheme.getStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                      ),
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
                          if (topic == 'இலக்கணம்1') {
                            // Directly open quiz for Grammar topic
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuizScreen(
                                  subjectTitle: subject.title,
                                  topicKey: subject.getTopicKey(idx),
                                  category: subject.title,
                                  categoryKey: subject.titleTa,
                                ),
                              ),
                            );
                          } else if (subject.getSubTopics(idx).isNotEmpty) {
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
                                  topicKey: subject.getTopicKey(idx),
                                  category: subject.title,
                                  categoryKey: subject.titleTa,
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
                            color: subject.color.withAlpha(26),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: subject.color.withAlpha(51), width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  topic,
                                  style: AppTheme.getStyle(
                                    fontSize: 18,
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (subject.topics.isNotEmpty) {
          _showTopicsBottomSheet(context);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TopicDetailScreen(
                topic: subject.title,
                topicKey: subject.titleTa,
                category: "General",
                categoryKey: "General",
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: subject.color.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(subject.icon, color: subject.color, size: 24),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        subject.title,
                        textAlign: TextAlign.center,
                        style: AppTheme.getStyle(
                          fontSize: 13,
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
                          fontSize: 10,
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
