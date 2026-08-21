import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/app_log.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../widgets/app_logo.dart';
import '../main.dart';
import 'login_screen.dart';

import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../firebase_options.dart';

class SplashScreen extends StatefulWidget {
const SplashScreen({super.key});

@override
State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
bool _started = false;
bool _navigating = false;

@override
void initState() {
super.initState();

AppLog.d('========================================');
AppLog.d('SPLASH: initState');
AppLog.d('========================================');

WidgetsBinding.instance.addPostFrameCallback((_) {
_start();
});
}

Future<void> _start() async {
if (_started) {
AppLog.d('SPLASH: Already started. Ignoring.');
return;
}

_started = true;

AppLog.d('========================================');
AppLog.d('SPLASH: START');
AppLog.d('========================================');

try {
// =========================================================
// STEP 1
// Make absolutely sure Firebase is initialized.
// =========================================================

AppLog.d('SPLASH: Checking Firebase initialization...');

if (Firebase.apps.isEmpty) {
AppLog.d('SPLASH: Firebase not initialized. Initializing now...');

await Firebase.initializeApp(
options: DefaultFirebaseOptions.currentPlatform,
);

AppLog.d('SPLASH: Firebase.initializeApp() SUCCESS');
} else {
AppLog.d(
'SPLASH: Firebase already initialized. '
'Apps count = ${Firebase.apps.length}',
);
}

    // =========================================================
    // STEP 2 & 3 & 4
    // Parallelize Service Init and Auth check
    // =========================================================

    AppLog.d('SPLASH: Starting parallel initialization...');

    User? user;
    
    await Future.wait([
      // Init Services
      initializeServices().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLog.e('SPLASH: initializeServices timeout.');
        },
      ),
      // Auth Check with a shorter, smarter wait
      () async {
        user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          AppLog.d('SPLASH: Waiting for Auth session restore...');
          // Give it a bit of time but not too much
          await Future.delayed(const Duration(milliseconds: 800));
          user = FirebaseAuth.instance.currentUser;
        }
      }(),
    ]);

    AppLog.d('SPLASH: currentUser = ${user?.uid ?? "NULL"}');

    // =========================================================
    // STEP 5
    // Remove native splash.
    // =========================================================

    try {
      FlutterNativeSplash.remove();
      AppLog.d('SPLASH: Native splash removed.');
    } catch (e) {
      AppLog.e('SPLASH: Native splash remove error: $e');
    }

    if (!mounted) return;

    // =========================================================
    // STEP 6 & 7
    // Navigation Decision
    // =========================================================

    if (user == null) {
      AppLog.d('SPLASH: NO USER FOUND -> LOGIN SCREEN');
      _navigateToLogin();
      return;
    }

    AppLog.d('SPLASH: EXISTING USER FOUND. Refreshing data in parallel...');

    // =========================================================
    // STEP 8 & 9
    // Parallelize Firestore refresh and FCM token save
    // =========================================================

    try {
      final firestoreService = FirestoreService();
      
      await Future.wait([
        firestoreService.getUserData(forceRefresh: true).timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            AppLog.e('SPLASH: Firestore refresh timeout.');
            return null;
          },
        ),
        NotificationService.saveFCMToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            AppLog.e('SPLASH: FCM token timeout.');
          },
        ),
      ]);
      
      AppLog.d('SPLASH: Background data refresh complete.');
    } catch (e, stack) {
      AppLog.e('SPLASH: Data refresh error: $e', e, stack);
    }

    if (!mounted) return;

    // =========================================================
    // STEP 10
    // Navigate to MainWrapper.
    // =========================================================

    _navigateToHome();
} catch (e, stack) {
AppLog.e(
'========================================',
e,
stack,
);

AppLog.e(
'SPLASH ERROR: $e',
e,
stack,
);

AppLog.e(
'SPLASH STACK: $stack',
);

// Try removing native splash.
try {
FlutterNativeSplash.remove();
} catch (_) {}

if (!mounted) return;

// =========================================================
// IMPORTANT:
// Before sending user to Login, check Firebase Auth one
// final time.
// =========================================================

try {
User? finalUser;

if (Firebase.apps.isNotEmpty) {
finalUser = FirebaseAuth.instance.currentUser;
}

AppLog.d(
'SPLASH FINAL AUTH CHECK: '
'${finalUser?.uid ?? "NULL"}',
);

if (finalUser != null) {
_navigateToHome();
} else {
_navigateToLogin();
}
} catch (authError, authStack) {
AppLog.e(
'SPLASH FINAL AUTH CHECK ERROR: $authError',
authError,
authStack,
);

_navigateToLogin();
}
}
}

// =============================================================
// Navigate to Home
// =============================================================

void _navigateToHome() {
if (!mounted) {
AppLog.d(
'SPLASH: Cannot navigate Home - not mounted.',
);
return;
}

if (_navigating) {
AppLog.d(
'SPLASH: Navigation already running.',
);
return;
}

_navigating = true;

AppLog.d(
'SPLASH: NAVIGATING -> MAIN WRAPPER',
);

Navigator.of(context).pushReplacement(
PageRouteBuilder(
pageBuilder: (
context,
animation,
secondaryAnimation,
) {
return const MainWrapper();
},
transitionsBuilder: (
context,
animation,
secondaryAnimation,
child,
) {
return FadeTransition(
opacity: animation,
child: child,
);
},
transitionDuration: const Duration(
milliseconds: 500,
),
),
);
}

// =============================================================
// Navigate to Login
// =============================================================

void _navigateToLogin() {
if (!mounted) {
AppLog.d(
'SPLASH: Cannot navigate Login - not mounted.',
);
return;
}

if (_navigating) {
AppLog.d(
'SPLASH: Navigation already running.',
);
return;
}

_navigating = true;

AppLog.d(
'SPLASH: NAVIGATING -> LOGIN',
);

Navigator.of(context).pushReplacement(
PageRouteBuilder(
pageBuilder: (
context,
animation,
secondaryAnimation,
) {
return const LoginScreen();
},
transitionsBuilder: (
context,
animation,
secondaryAnimation,
child,
) {
return FadeTransition(
opacity: animation,
child: child,
);
},
transitionDuration: const Duration(
milliseconds: 500,
),
),
);
}

@override
Widget build(BuildContext context) {
return ValueListenableBuilder<String>(
valueListenable: AppLanguage.languageNotifier,
builder: (context, lang, child) {
return Scaffold(
backgroundColor: const Color(0xFF02091A),
body: SizedBox(
width: double.infinity,
height: double.infinity,
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
// =================================================
// LOGO
// =================================================

Stack(
alignment: Alignment.center,
children: [
Container(
width: 180,
height: 180,
decoration: BoxDecoration(
shape: BoxShape.circle,
gradient: RadialGradient(
colors: [
AppTheme.secondaryColor.withValues(
alpha: 0.20,
),
AppTheme.secondaryColor.withValues(
alpha: 0.05,
),
Colors.transparent,
],
),
),
),

const AppLogo(
size: 150,
borderRadius: 0,
showShadow: false,
),
],
),

const SizedBox(height: 15),

// =================================================
// APP TITLE
// =================================================

Text(
AppLanguage.getString('app_title'),
textAlign: TextAlign.center,
style: AppTheme.getStyle(
fontSize: 36,
fontWeight: FontWeight.bold,
color: Colors.white,
).copyWith(
letterSpacing: 2,
),
),

const SizedBox(height: 10),

// =================================================
// TAGLINE
// =================================================

Text(
AppLanguage.getString('tagline'),
textAlign: TextAlign.center,
style: AppTheme.getStyle(
fontSize: 16,
color: Colors.white70,
),
),

const SizedBox(height: 30),

// =================================================
// LOADING
// =================================================

const SizedBox(
width: 25,
height: 25,
child: CircularProgressIndicator(
strokeWidth: 2,
color: Colors.white70,
),
),
],
),
),
);
},
);
}
}