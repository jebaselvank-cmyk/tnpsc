import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tnpsc_group_book/utils/app_icons.dart';
import '../models/subject.dart';
import '../models/question.dart';
import '../services/hive_service.dart';
import '../utils/app_log.dart';
import '../utils/app_theme.dart';
import '../utils/app_date.dart';
import '../utils/app_language.dart';
import '../services/firestore_service.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'admin_panel_screen.dart';
import '../widgets/streak_badge.dart';
import '../widgets/share_poster.dart';
import '../widgets/app_rating_dialog.dart';
import 'avatar_selection_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/credential_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  /// Static method to trigger share poster from anywhere
  static Future<void> triggerShare(BuildContext context) async {
    final state = context.findAncestorStateOfType<_ProfileScreenState>();
    if (state != null) {
      await state._shareAppWithRandomQuiz();
    }
  }

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final FirestoreService _firestoreService = FirestoreService();
  final user = FirebaseAuth.instance.currentUser;
  String _appVersion = "1.0.0";
  Future<List<dynamic>>? _profileDataFuture;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _profileDataFuture = Future.wait([
      _firestoreService.getUserData(),
      _firestoreService.getUserGlobalRank(),
    ]);
    if (_isAdmin) {
      if (HiveService.shouldRefreshSharePool()) {
        _refreshShareQuizPool();
      }
    }
  }

  void _refreshData() {
    if (!mounted) return;
    setState(() {
      _profileDataFuture = Future.wait([
        _firestoreService.getUserData(forceRefresh: true),
        _firestoreService.getUserGlobalRank(),
      ]);
    });
  }

  Future<void> _refreshShareQuizPool() async {
    try {
      final pool = await _firestoreService.fetchLargeShareQuizPool(200);
      if (pool.isNotEmpty) {
        await HiveService.saveShareQuizPool(pool);
      }
    } catch (e) {
      AppLog.e("Error refreshing share quiz pool: $e");
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      AppLog.e("Error loading app version: $e");
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLanguage.getString('error_launch_url'))),
          );
        }
      }
    } catch (e) {
      AppLog.e("Launch Error: $e");
    }
  }

  bool get _isAdmin {
    return user?.phoneNumber == '+918754236411' ||
        user?.email == 'adminjeba@gmail.com' ||
        user?.email == 'kjebaselvan987@gmail.com';
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        return Column(
          children: [
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                left: 20,
                right: 20,
                bottom: 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const AppIcon(AppIcons.back, color: Colors.transparent),
                    onPressed: () {},
                  ),
                  Text(
                    AppLanguage.getString('profile'),
                    style: AppTheme.getStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: isDark ? Colors.white : AppTheme.textMainColor,
                    ),
                  ),
                  IconButton(
                    icon: const AppIcon(AppIcons.settings),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: AppTheme.themeNotifier,
                builder: (context, currentMode, _) {
                  return FutureBuilder<List<dynamic>>(
                    future: _profileDataFuture,
                    builder: (context, snapshot) {
                      final userDataDoc = snapshot.data?[0] as DocumentSnapshot?;
                      final int globalRank = snapshot.data?[1] as int? ?? 0;
                      final userData = userDataDoc?.data() as Map<String, dynamic>?;

                      final String name = userData?['name'] ?? user?.displayName ?? AppLanguage.getString('user_fallback');
                      final String email = userData?['email'] ?? user?.email ?? AppLanguage.getString('no_email_linked');
                      final String rankVal = globalRank > 0 ? globalRank.toString() : "--";

                      final int totalPoints = userData?['totalScore'] ?? 0;

                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        children: [
                          const SizedBox(height: 10),
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppTheme.accentColor, width: 2),
                                      ),
                                      child: CircleAvatar(
                                        radius: 40,
                                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                        backgroundImage: (userData?['avatar'] != null && userData!['avatar']!.isNotEmpty)
                                            ? NetworkImage(userData!['avatar']!)
                                            : (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                                                ? NetworkImage(user!.photoURL!)
                                                : NetworkImage("https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(name)}${userData?['gender'] == 'female' ? '-female' : userData?['gender'] == 'male' ? '-male' : ''}&backgroundColor=b6e3f4,c0aede,d1d4f9"),
                                        child: (userData?['avatar'] == null && (user?.photoURL == null || user!.photoURL!.isEmpty))
                                            ? Text(
                                                name.isNotEmpty ? name[0].toUpperCase() : "?",
                                                style: AppTheme.getStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white10),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => AvatarSelectionScreen(
                                                currentAvatar: userData?['avatar'] ?? user?.photoURL ?? "",
                                                currentPoints: totalPoints,
                                              ),
                                            ),
                                          );
                                          if (result == true) {
                                            _refreshData();
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: isDark ? AppTheme.darkSurfaceColor : Colors.white, width: 2),
                                          ),
                                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: AppTheme.getStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : AppTheme.textMainColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if ((userData?['streak'] ?? 0) >= 7) ...[
                                      const SizedBox(width: 3),
                                      StreakBadge(streak: userData?['streak'] ?? 0),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: AppTheme.getStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              ValueListenableBuilder(
                                valueListenable: Hive.box(HiveService.userBoxName).listenable(),
                                builder: (context, box, child) {
                                  int count = box.get('quizzesCompleted', defaultValue: 0) as int;
                                  return _buildStatBox(context, AppLanguage.getString('quizzes'), "$count", Colors.blue);
                                },
                              ),
                              const SizedBox(width: 16),
                              ValueListenableBuilder(
                                valueListenable: Hive.box(HiveService.userBoxName).listenable(),
                                builder: (context, box, child) {
                                  int points = box.get('totalScore', defaultValue: 0) as int;
                                  return _buildStatBox(context, AppLanguage.getString('points'), "$points", Colors.green);
                                },
                              ),
                              const SizedBox(width: 16),
                              _buildStatBox(context, AppLanguage.getString('rank'), rankVal, Colors.orange),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            AppLanguage.getString('quick_settings'),
                            style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            color: isDark ? Theme.of(context).cardColor : Colors.white,
                            child: Column(
                              children: [
                                ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                                    child: const AppIcon(Icons.language_rounded, color: Colors.blue),
                                  ),
                                  title: const Text("தமிழ் / English"),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        lang == 'ta' ? "தமிழ்" : "English",
                                        style: AppTheme.getStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.secondaryColor,
                                        ),
                                      ),
                                      Switch(
                                        value: lang == 'en',
                                        activeThumbColor: AppTheme.secondaryColor,
                                        inactiveThumbColor: AppTheme.secondaryColor,
                                        onChanged: (val) => AppLanguage.changeLanguage(val ? 'en' : 'ta'),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.pink.withValues(alpha: 0.1), shape: BoxShape.circle),
                                    child: const AppIcon(Icons.face_retouching_natural_rounded, color: Colors.pink),
                                  ),
                                  title: Text(lang == 'ta' ? 'பாலினம்' : 'Gender'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildGenderChip('male', lang == 'ta' ? 'ஆண்' : 'Male', userData?['gender']),
                                      const SizedBox(width: 8),
                                      _buildGenderChip('female', lang == 'ta' ? 'பெண்' : 'Female', userData?['gender']),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), shape: BoxShape.circle),
                                    child: const AppIcon(Icons.dark_mode_rounded, color: Colors.purple),
                                  ),
                                  title: Text(AppLanguage.getString('dark_theme')),
                                  trailing: Switch(
                                    value: currentMode == ThemeMode.dark || (currentMode == ThemeMode.system && isDark),
                                    activeThumbColor: AppTheme.secondaryColor,
                                    onChanged: (val) => AppTheme.setThemeMode(val ? ThemeMode.dark : ThemeMode.light),
                                  ),
                                ),
                                const Divider(height: 1),
                                ValueListenableBuilder<double>(
                                  valueListenable: AppTheme.fontSizeFactorNotifier,
                                  builder: (context, fontSizeFactor, _) {
                                    return ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                                        child: const AppIcon(Icons.format_size_rounded, color: Colors.orange),
                                      ),
                                      title: Text(AppLanguage.getString('font_size')),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: fontSizeFactor > 0.81 ? () => AppTheme.setFontSizeFactor(fontSizeFactor - 0.1) : null,
                                            icon: const AppIcon(Icons.remove_circle_outline_rounded),
                                          ),
                                          Text("${(fontSizeFactor * 100).round()}%", style: AppTheme.getStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                          IconButton(
                                            onPressed: fontSizeFactor < 1.39 ? () => AppTheme.setFontSizeFactor(fontSizeFactor + 0.1) : null,
                                            icon: const AppIcon(Icons.add_circle_outline_rounded),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            AppLanguage.getString('more'),
                            style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            color: isDark ? Theme.of(context).cardColor : Colors.white,
                            child: Column(
                              children: [
                                if (_isAdmin) ...[
                                  ListTile(
                                    leading: const AppIcon(Icons.admin_panel_settings_rounded, color: Colors.blueGrey),
                                    title: Text(AppLanguage.getString('admin_panel')),
                                    trailing: const AppIcon(Icons.chevron_right_rounded, color: Colors.grey),
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelScreen())),
                                  ),
                                  const Divider(height: 1),
                                ],
                                ListTile(
                                  leading: const AppIcon(Icons.update, color: Colors.grey),
                                  title: Text(AppLanguage.getString('app_version')),
                                  trailing: Text(_appVersion, style: AppTheme.getStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w600)),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const AppIcon(Icons.info_outline_rounded, color: Colors.grey),
                                  title: Text(AppLanguage.getString('about_app')),
                                  trailing: const AppIcon(Icons.chevron_right_rounded, color: Colors.grey),
                                  onTap: () => _launchURL('https://tnpscmasterapp.blogspot.com/2026/06/about-app.html'),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const AppIcon(Icons.privacy_tip_outlined, color: Colors.grey),
                                  title: Text(AppLanguage.getString('privacy_policy')),
                                  trailing: const AppIcon(Icons.chevron_right_rounded, color: Colors.grey),
                                  onTap: () => _launchURL('https://tnpscmasterapp.blogspot.com/2026/06/privacy-policy.html'),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const AppIcon(Icons.chat_bubble_rounded, color: Colors.green, size: 28),
                                  title: Text(AppLanguage.getString('join_whatsapp'), style: AppTheme.getStyle(fontSize: 16, color: Colors.green)),
                                  trailing: const AppIcon(Icons.chevron_right_rounded, color: Colors.grey),
                                  onTap: () => _launchURL('https://chat.whatsapp.com/EgLPBuTBIccIhHGglPXGN9?s=sw&p=a&mlu=0'),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const AppIcon(Icons.send_rounded, color: Colors.lightBlue),
                                  title: Text(AppLanguage.getString('join_telegram'), style: AppTheme.getStyle(fontSize: 16, color: Colors.lightBlue)),
                                  trailing: const AppIcon(Icons.chevron_right_rounded, color: Colors.grey),
                                  onTap: () => _launchURL('https://t.me/+HDW2ssG3H9s4MzM1'),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const AppIcon(Icons.share_rounded, color: Colors.blueAccent),
                                  title: Text(lang == 'ta' ? 'நண்பர்களுடன் பகிர்க' : 'Share with Friends', style: AppTheme.getStyle(fontSize: 16, color: Colors.blueAccent)),
                                  trailing: _isSharing 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
                                    : const AppIcon(Icons.chevron_right_rounded, color: Colors.grey),
                                  onTap: _isSharing ? null : _shareAppWithRandomQuiz,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const AppIcon(Icons.star_rounded, color: Colors.amber),
                                  title: Text(lang == 'ta' ? 'மதிப்பிடவும்' : 'Rate Us', style: AppTheme.getStyle(fontSize: 16, color: Colors.amber)),
                                  trailing: const AppIcon(Icons.chevron_right_rounded, color: Colors.grey),
                                  onTap: () => AppRatingDialog.show(context),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const AppIcon(AppIcons.logout_rounded, color: Colors.redAccent),
                                  title: Text(AppLanguage.getString('logout'), style: AppTheme.getStyle(fontSize: 16, color: Colors.redAccent)),
                                  onTap: () async {
                                    bool? confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(AppLanguage.getString('logout_confirm_title')),
                                        content: Text(AppLanguage.getString('logout_confirm_desc')),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLanguage.getString('cancel'))),
                                          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(AppLanguage.getString('logout'), style: AppTheme.getStyle(fontSize: 15, color: Colors.redAccent, fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;
                                    final email = FirebaseAuth.instance.currentUser?.email;
                                    if (email != null) await CredentialStorage.clearPassword(email);
                                    await HiveService.resetSessionLeaderboardFetched();
                                    await FirebaseAuth.instance.signOut();
                                    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatBox(BuildContext context, String title, String value, Color color) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(
          children: [
            Text(value, textAlign: TextAlign.center, style: AppTheme.getStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : color)),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center, style: AppTheme.getStyle(fontSize: 12, color: isDark ? Colors.white70 : AppTheme.textSecondaryColor)),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAppWithRandomQuiz() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      await HiveService.resetSharedQuizHistoryIfNeeded();
      List<Question> pool = HiveService.getShareQuizPool();
      if (pool.isEmpty) pool = defaultRoomQuestions;
      if (pool.isEmpty) {
        if (mounted) setState(() => _isSharing = false);
        return;
      }
      int slotSeed = AppDate.getSlotSeed();
      final question = pool[slotSeed % pool.length];
      Subject subject = tnpscSubjects[0]; 
      String qSub = (question.subject ?? question.quizType ?? "").toLowerCase();
      try {
        subject = tnpscSubjects.firstWhere((s) => s.titleEn.toLowerCase().contains(qSub) || s.titleTa.toLowerCase().contains(qSub) || qSub.contains(s.titleEn.toLowerCase()));
      } catch (_) {}
      final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
        Material(
          color: Colors.black,
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData().copyWith(textScaler: const TextScaler.linear(0.9)),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: SharePoster(question: question, subject: subject, dayIndex: (slotSeed % 7) + 1)),
            ),
          ),
        ),
        pixelRatio: 5.0,
        delay: const Duration(milliseconds: 500),
      );
      if (imageBytes != null && mounted) _showSharePreviewDialog(imageBytes);
    } catch (e) {
      AppLog.e("Error sharing app: $e");
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _showSharePreviewDialog(Uint8List imageBytes) async {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String shareText = AppLanguage.languageNotifier.value == 'ta'
        ? "இந்தக் கேள்வியை உங்களால் தீர்க்க முடியுமா? TNPSC தேர்வுகளுக்குத் தயாராக இந்த ஆப்பை உடனே பதிவிறக்கம் செய்யுங்கள்! 📚\n\nபதிவிறக்கம்: https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book"
        : "Can you solve this? Download the app now to prepare for TNPSC exams! 📚\n\nDownload: https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book";
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(color: isDark ? AppTheme.darkSurfaceColor : Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppLanguage.languageNotifier.value == 'ta' ? "முன்னோட்டம்" : "Share Preview", style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textMainColor)),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                  ),
                  Flexible(child: Container(margin: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)), child: ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.memory(imageBytes, fit: BoxFit.contain)))),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            final directory = await getTemporaryDirectory();
                            final imagePath = await File('${directory.path}/share_quiz.png').create();
                            await imagePath.writeAsBytes(imageBytes);
                            final result = await Share.shareXFiles([XFile(imagePath.path)], text: shareText);
                            if (result.status == ShareResultStatus.success && HiveService.canEarnShareRewardToday()) {
                                await _firestoreService.incrementUserPoints(50);
                                await HiveService.markShareRewardEarnedToday();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLanguage.languageNotifier.value == 'ta' ? "வாழ்த்துக்கள்! பகிர்ந்ததற்காக 50 புள்ளிகள் கிடைத்தன!" : "Congratulations! You earned 50 points for sharing!"), backgroundColor: Colors.green));
                                  setState(() {});
                                }
                            }
                          } catch (e) { AppLog.e("Error sharing from dialog: $e"); }
                        },
                        icon: const Icon(Icons.share_rounded, size: 20),
                        label: Text(AppLanguage.languageNotifier.value == 'ta' ? "இப்போதே பகிர்க" : "Share Now"),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderChip(String type, String label, String? currentGender) {
    bool isSelected = currentGender == type;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(label, style: AppTheme.getStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54))),
      selected: isSelected,
      onSelected: (val) async {
        if (val) {
          await _firestoreService.updateGender(type);
          _refreshData();
        }
      },
      selectedColor: AppTheme.secondaryColor,
      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      showCheckmark: false,
    );
  }
}
