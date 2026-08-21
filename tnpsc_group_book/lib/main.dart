import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import 'firebase_options.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/subject_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/profile_screen.dart';

// Utils
import 'utils/app_theme.dart';
import 'utils/app_language.dart';
import 'utils/app_icons.dart';
import 'utils/app_log.dart';

// Services
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'services/reward_service.dart';
import 'services/tts_service.dart';
import 'services/deep_link_service.dart';
import 'services/firestore_service.dart';
import 'services/version_service.dart';

// Widgets
import 'widgets/lazy_indexed_stack.dart';
import 'widgets/error_state_widget.dart';
import 'widgets/app_rating_dialog.dart';


// ============================================================
// GLOBAL SCAFFOLD MESSENGER
// ============================================================

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();


// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  // ----------------------------------------------------------
  // Flutter initialization
  // ----------------------------------------------------------

  final WidgetsBinding binding =
  WidgetsFlutterBinding.ensureInitialized();

  // Keep native splash until Flutter is ready.
  FlutterNativeSplash.preserve(
    widgetsBinding: binding,
  );

  // ----------------------------------------------------------
  // Global Flutter error handler
  // ----------------------------------------------------------

  FlutterError.onError = (FlutterErrorDetails details) {
    AppLog.e(
      'GLOBAL_FLUTTER_ERROR: ${details.exception}',
      details.exception,
      details.stack,
    );
  };

  // ----------------------------------------------------------
  // Global platform error handler
  // ----------------------------------------------------------

  PlatformDispatcher.instance.onError = (
      Object error,
      StackTrace stack,
      ) {
    AppLog.e(
      'GLOBAL_PLATFORM_ERROR: $error',
      error,
      stack,
    );

    return true;
  };

  // Initialize localized date formatting and preferred orientations in parallel
  // Also start Firebase and Hive initialization immediately
  bool firebaseReady = false;

  try {
    await Future.wait([
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
      initializeDateFormatting('ta', null),
      initializeDateFormatting('en', null),
      () async {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          firebaseReady = true;
          AppLog.d('MAIN: Firebase.initializeApp() SUCCESS');
        } catch (e, stack) {
          AppLog.e('MAIN: FIREBASE INITIALIZATION FAILED: $e', e, stack);
        }
      }(),
      () async {
        try {
          await HiveService.init();
          AppLog.d('MAIN: Hive initialization SUCCESS');
        } catch (e, stack) {
          AppLog.e('MAIN: Hive initialization FAILED: $e', e, stack);
        }
      }(),
    ]);
  } catch (e) {
    AppLog.e('MAIN: Parallel initialization error: $e');
  }

  // ==========================================================
  // APP LANGUAGE / THEME
  // ==========================================================

  try {
    AppLanguage.init();
    AppTheme.init();

    AppLog.d(
      'MAIN: App preferences initialized',
    );
  } catch (e, stack) {
    AppLog.e(
      'MAIN: App preferences initialization FAILED: $e',
      e,
      stack,
    );
  }

  // ==========================================================
  // RUN APP
  // ==========================================================

  AppLog.d(
    'MAIN: runApp()',
  );

  runApp(
    TNPSCPrepApp(
      firebaseReady: firebaseReady,
    ),
  );
}


// ============================================================
// BACKGROUND SERVICES
// ============================================================

Future<void> initializeServices() async {
  AppLog.d(
    '========================================',
  );

  AppLog.d(
    'INITIALIZE SERVICES: START',
  );

  AppLog.d(
    '========================================',
  );

  // ----------------------------------------------------------
  // Verify Firebase
  // ----------------------------------------------------------

  try {
    final firebaseApp = Firebase.app();

    AppLog.d(
      'SERVICES: Firebase ready = ${firebaseApp.name}',
    );
  } catch (e, stack) {
    AppLog.e(
      'SERVICES: Firebase NOT READY: $e',
      e,
      stack,
    );

    // Very important:
    // Do not silently continue if Firebase is unavailable.
    rethrow;
  }

  // ----------------------------------------------------------
  // Firestore settings
  // ----------------------------------------------------------

  try {
    FirebaseFirestore.instance.settings =
    const Settings(
      persistenceEnabled: true,
      cacheSizeBytes:
      Settings.CACHE_SIZE_UNLIMITED,
    );

    AppLog.d(
      'SERVICES: Firestore configured',
    );
  } catch (e, stack) {
    AppLog.e(
      'SERVICES: Firestore settings error: $e',
      e,
      stack,
    );
  }

  // ----------------------------------------------------------
  // Start background services
  // ----------------------------------------------------------

  _initServicesInBackground();

  AppLog.d(
    'SERVICES: Critical initialization COMPLETE',
  );
}


// ============================================================
// BACKGROUND INITIALIZATION
// ============================================================

Future<void> _initServicesInBackground() async {
  try {
    // Give UI time to become interactive.
    await Future.delayed(
      const Duration(milliseconds: 800),
    );

    // --------------------------------------------------------
    // Notification Service
    // --------------------------------------------------------

    try {
      await NotificationService.init();

      AppLog.d(
        'BACKGROUND: NotificationService initialized',
      );
    } catch (e, stack) {
      AppLog.e(
        'BACKGROUND: NotificationService error: $e',
        e,
        stack,
      );
    }

    // --------------------------------------------------------
    // Reward / Ads
    // --------------------------------------------------------

    try {
      await RewardService.handleConsentAndInit();

      AppLog.d(
        'BACKGROUND: RewardService initialized',
      );
    } catch (e, stack) {
      AppLog.e(
        'BACKGROUND: RewardService error: $e',
        e,
        stack,
      );
    }

    // --------------------------------------------------------
    // TTS
    // --------------------------------------------------------

    try {
      TtsService.init();

      AppLog.d(
        'BACKGROUND: TTS initialized',
      );
    } catch (e, stack) {
      AppLog.e(
        'BACKGROUND: TTS error: $e',
        e,
        stack,
      );
    }

    // --------------------------------------------------------
    // Deep Link
    // --------------------------------------------------------

    try {
      DeepLinkService().init();

      AppLog.d(
        'BACKGROUND: DeepLink initialized',
      );
    } catch (e, stack) {
      AppLog.e(
        'BACKGROUND: DeepLink error: $e',
        e,
        stack,
      );
    }

    AppLog.d(
      'BACKGROUND: All background services completed',
    );
  } catch (e, stack) {
    AppLog.e(
      'BACKGROUND: Unexpected error: $e',
      e,
      stack,
    );
  }
}


// ============================================================
// TNPSC APP
// ============================================================

class TNPSCPrepApp extends StatelessWidget {
  final bool firebaseReady;

  const TNPSCPrepApp({
    super.key,
    required this.firebaseReady,
  });

  @override
  Widget build(BuildContext context) {
    // --------------------------------------------------------
    // Global error UI
    // --------------------------------------------------------

    ErrorWidget.builder =
        (FlutterErrorDetails details) {
      return ValueListenableBuilder<String>(
        valueListenable:
        AppLanguage.languageNotifier,
        builder: (
            context,
            lang,
            child,
            ) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
            AppTheme.themeNotifier.value,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ta'),
              Locale('en'),
            ],
            locale: AppLanguage.getLocale(),
            home: AppErrorWidget(
              isFullScreen: true,
              onRetry: () {
                SystemNavigator.pop();
              },
            ),
          );
        },
      );
    };

    // --------------------------------------------------------
    // Theme
    // --------------------------------------------------------

    return ValueListenableBuilder<ThemeMode>(
      valueListenable:
      AppTheme.themeNotifier,
      builder: (
          context,
          currentMode,
          child,
          ) {
        return ValueListenableBuilder<String>(
          valueListenable:
          AppLanguage.languageNotifier,
          builder: (
              context,
              lang,
              child,
              ) {
            return ValueListenableBuilder<double>(
              valueListenable:
              AppTheme.fontSizeFactorNotifier,
              builder: (
                  context,
                  fontSizeFactor,
                  child,
                  ) {
                return MaterialApp(
                  title: AppLanguage.getString(
                    'app_title',
                  ),

                  scaffoldMessengerKey:
                  scaffoldMessengerKey,

                  debugShowCheckedModeBanner:
                  false,

                  theme:
                  AppTheme.lightTheme,

                  darkTheme:
                  AppTheme.darkTheme,

                  themeMode:
                  currentMode,

                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('ta'),
                    Locale('en'),
                  ],
                  locale: AppLanguage.getLocale(),

                  // ------------------------------------------------
                  // IMPORTANT:
                  // SplashScreen handles Auth session.
                  // ------------------------------------------------

                  home: const SplashScreen(),
                );
              },
            );
          },
        );
      },
    );
  }
}


// ============================================================
// MAIN WRAPPER
// ============================================================

class MainWrapper extends StatefulWidget {
  const MainWrapper({
    super.key,
  });

  @override
  State<MainWrapper> createState() =>
      _MainWrapperState();
}


// ============================================================
// MAIN WRAPPER STATE
// ============================================================

class _MainWrapperState
    extends State<MainWrapper>
    with WidgetsBindingObserver {

  int _selectedIndex = 0;

  bool _isExiting = false;

  DateTime _lastBackgroundCheck =
  DateTime.now();

  // ----------------------------------------------------------
  // Screens
  // ----------------------------------------------------------

  final List<Widget> _screens = const [
    HomeScreen(),
    SubjectScreen(),
    LeaderboardScreen(),
    ProfileScreen(),
  ];

  // ----------------------------------------------------------
  // INIT
  // ----------------------------------------------------------

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addObserver(this);

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _runPeriodicChecks();
    });
  }

  // ----------------------------------------------------------
  // PERIODIC CHECKS
  // ----------------------------------------------------------

  Future<void> _runPeriodicChecks() async {
    if (!mounted) return;

    try {
      VersionService.checkForUpdate(
        context,
      );
    } catch (e, stack) {
      AppLog.e(
        'MAIN WRAPPER: Version check error: $e',
        e,
        stack,
      );
    }

    try {
      await FirestoreService()
          .updateStreak();
      
      // AI_DEBUG: Check for app rating prompt (every 5 streak days)
      if (!HiveService.isAppRated()) {
        final userBox = Hive.box(HiveService.userBoxName);
        int streak = userBox.get('streak', defaultValue: 0) as int;
        if (streak > 0 && streak % 5 == 0) {
          if (mounted) {
            AppRatingDialog.show(context);
          }
        }
      }
    } catch (e, stack) {
      AppLog.e(
        'MAIN WRAPPER: Streak update error: $e',
        e,
        stack,
      );
    }

    try {
      NotificationService
          .reschedulePersonalizedReminders();
    } catch (e, stack) {
      AppLog.e(
        'MAIN WRAPPER: Reminder error: $e',
        e,
        stack,
      );
    }

    _lastBackgroundCheck =
        DateTime.now();
  }

  // ----------------------------------------------------------
  // DISPOSE
  // ----------------------------------------------------------

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(this);

    super.dispose();
  }

  // ----------------------------------------------------------
  // APP LIFECYCLE
  // ----------------------------------------------------------

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    super.didChangeAppLifecycleState(
      state,
    );

    // --------------------------------------------------------
    // RESUMED
    // --------------------------------------------------------

    if (state ==
        AppLifecycleState.resumed) {
      final now = DateTime.now();

      if (now
          .difference(
        _lastBackgroundCheck,
      )
          .inMinutes >=
          15) {
        AppLog.d(
          'MAIN WRAPPER: Resumed after >15 minutes',
        );

        _runPeriodicChecks();
      } else {
        AppLog.d(
          'MAIN WRAPPER: Resumed quickly',
        );
      }
    }

    // --------------------------------------------------------
    // PAUSED
    // --------------------------------------------------------

    else if (state ==
        AppLifecycleState.paused) {
      _lastBackgroundCheck =
          DateTime.now();

      AppLog.d(
        'MAIN WRAPPER: App paused',
      );
    }
  }

  // ----------------------------------------------------------
  // BACK NAVIGATION
  // ----------------------------------------------------------

  Future<void> _handleBackNavigation() async {
    AppLog.d(
      'MAIN WRAPPER: Back pressed. '
          'Index=$_selectedIndex '
          'Exiting=$_isExiting',
    );

    if (_isExiting) {
      return;
    }

    // --------------------------------------------------------
    // If not Home → Home
    // --------------------------------------------------------

    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });

      return;
    }

    // --------------------------------------------------------
    // Home → Exit dialog
    // --------------------------------------------------------

    _isExiting = true;

    final shouldPop =
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark =
            Theme.of(context)
                .brightness ==
                Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark
              ? const Color(0xFF101F42)
              : Colors.white,

          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(20),
          ),

          title: Text(
            AppLanguage.getString(
              'exit_app_title',
            ),
            style:
            AppTheme.getStyle(
              fontSize: 20,
              fontWeight:
              FontWeight.bold,
              color: isDark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),

          content: Text(
            AppLanguage.getString(
              'exit_app_desc',
            ),
            style:
            AppTheme.getStyle(
              fontSize: 16,
              color: isDark
                  ? Colors.white70
                  : Colors.black54,
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                _isExiting = false;

                Navigator.pop(
                  context,
                  false,
                );
              },
              child: Text(
                AppLanguage.getString(
                  'no',
                ),
                style:
                AppTheme.getStyle(
                  fontSize: 14,
                  color:
                  Colors.grey[600],
                ),
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                AppTheme
                    .primaryColor,
                foregroundColor:
                Colors.white,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
              ),
              child: Text(
                AppLanguage.getString(
                  'yes',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldPop == true) {
      AppLog.d(
        'MAIN WRAPPER: Exiting application',
      );

      SystemNavigator.pop();
    } else {
      _isExiting = false;
    }
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable:
      AppLanguage.languageNotifier,
      builder: (
          context,
          lang,
          child,
          ) {
        final isDark =
            Theme.of(context)
                .brightness ==
                Brightness.dark;

        return PopScope(
          canPop: false,

          onPopInvokedWithResult: (
              didPop,
              result,
              ) {
            if (didPop) return;

            _handleBackNavigation();
          },

          child: Scaffold(
            // ------------------------------------------------
            // BODY
            // ------------------------------------------------

            body: LazyIndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),

            // ------------------------------------------------
            // BOTTOM NAVIGATION
            // ------------------------------------------------

            bottomNavigationBar:
            Container(
              decoration:
              BoxDecoration(
                color: isDark
                    ? AppTheme
                    .darkBgColor
                    : Colors.white,

                boxShadow: [
                  BoxShadow(
                    blurRadius: 20,
                    color: Colors.black
                        .withOpacity(
                      0.1,
                    ),
                  ),
                ],
              ),

              child: SafeArea(
                child: Padding(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),

                  child: GNav(
                    rippleColor:
                    Colors.grey[300]!,

                    hoverColor:
                    Colors.grey[100]!,

                    gap: 8,

                    activeColor:
                    AppTheme
                        .secondaryColor,

                    iconSize:
                    AppTheme
                        .getScaledIconSize(
                      24,
                    ),

                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),

                    duration:
                    const Duration(
                      milliseconds: 400,
                    ),

                    tabBackgroundColor:
                    AppTheme
                        .secondaryColor
                        .withOpacity(
                      0.1,
                    ),

                    color: Colors.grey,

                    selectedIndex:
                    _selectedIndex,

                    tabs: [
                      GButton(
                        icon:
                        AppIcons.home,
                        text:
                        AppLanguage
                            .getString(
                          'home',
                        ),
                      ),

                      GButton(
                        icon:
                        AppIcons.books,
                        text:
                        AppLanguage
                            .getString(
                          'book',
                        ),
                      ),

                      GButton(
                        icon:
                        AppIcons
                            .leaderboard,
                        text:
                        AppLanguage
                            .getString(
                          'rank',
                        ),
                      ),

                      GButton(
                        icon:
                        AppIcons.profile,
                        text:
                        AppLanguage
                            .getString(
                          'profile',
                        ),
                      ),
                    ],

                    onTabChange: (
                        index,
                        ) {
                      if (!mounted) {
                        return;
                      }

                      setState(() {
                        _selectedIndex =
                            index;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}