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
// STEP 2
// Initialize remaining services.
//
// IMPORTANT:
// Firebase is already ready before initializeServices()
// is called.
// =========================================================

AppLog.d('SPLASH: Starting initializeServices()...');

try {
await initializeServices().timeout(
const Duration(seconds: 10),
onTimeout: () {
AppLog.e(
'SPLASH: initializeServices timeout. '
'Continuing anyway.',
);
},
);

AppLog.d('SPLASH: initializeServices completed.');
} catch (e, stack) {
AppLog.e(
'SPLASH: initializeServices error: $e',
e,
stack,
);

// Do NOT stop the app here.
// Firebase is already initialized.
}

// =========================================================
// STEP 3
// IMPORTANT:
// FirebaseAuth is accessed ONLY after Firebase.initializeApp.
// =========================================================

AppLog.d('SPLASH: Checking Firebase Auth session...');

User? user;

try {
user = FirebaseAuth.instance.currentUser;

AppLog.d(
'SPLASH: currentUser = '
'${user?.uid ?? "NULL"}',
);

AppLog.d(
'SPLASH: currentUser email = '
'${user?.email ?? "NULL"}',
);
} catch (e, stack) {
AppLog.e(
'SPLASH: FirebaseAuth currentUser error: $e',
e,
stack,
);

user = null;
}

// =========================================================
// STEP 4
// Give Firebase Auth a short time to restore persisted
// session if currentUser is temporarily null.
//
// This is important when app is completely closed and
// reopened.
// =========================================================

if (user == null) {
AppLog.d(
'SPLASH: currentUser is NULL. '
'Waiting for Firebase Auth session restore...',
);

try {
await Future.delayed(
const Duration(milliseconds: 1500),
);

user = FirebaseAuth.instance.currentUser;

AppLog.d(
'SPLASH: After 1.5 sec currentUser = '
'${user?.uid ?? "NULL"}',
);

AppLog.d(
'SPLASH: After 1.5 sec email = '
'${user?.email ?? "NULL"}',
);
} catch (e, stack) {
AppLog.e(
'SPLASH: Auth restore check failed: $e',
e,
stack,
);
}
}

// =========================================================
// STEP 5
// Remove native splash.
// =========================================================

try {
FlutterNativeSplash.remove();
AppLog.d('SPLASH: Native splash removed.');
} catch (e) {
AppLog.e(
'SPLASH: Native splash remove error: $e',
);
}

if (!mounted) {
AppLog.d('SPLASH: Widget no longer mounted.');
return;
}

// =========================================================
// STEP 6
// USER NOT LOGGED IN
// =========================================================

if (user == null) {
AppLog.d(
'SPLASH: NO USER FOUND -> LOGIN SCREEN',
);

_navigateToLogin();
return;
}

// =========================================================
// STEP 7
// USER ALREADY LOGGED IN
// =========================================================

AppLog.d(
'========================================',
);

AppLog.d(
'SPLASH: EXISTING USER FOUND',
);

AppLog.d(
'SPLASH: UID = ${user.uid}',
);

AppLog.d(
'SPLASH: EMAIL = ${user.email}',
);

AppLog.d(
'SPLASH: Going directly to MainWrapper',
);

AppLog.d(
'========================================',
);

// =========================================================
// STEP 8
// Refresh Firestore user data.
//
// IMPORTANT:
// Failure here should NOT send user to Login.
// =========================================================

try {
final firestoreService = FirestoreService();

AppLog.d(
'SPLASH: Refreshing Firestore user data...',
);

await firestoreService
    .getUserData(forceRefresh: true)
    .timeout(
const Duration(seconds: 8),
onTimeout: () {
AppLog.e(
'SPLASH: Firestore refresh timeout.',
);
return null;
},
);

AppLog.d(
'SPLASH: Firestore user data refreshed.',
);
} catch (e, stack) {
AppLog.e(
'SPLASH: Firestore refresh failed: $e',
e,
stack,
);

// Continue to MainWrapper.
}

// =========================================================
// STEP 9
// Refresh FCM token.
// =========================================================

try {
AppLog.d(
'SPLASH: Saving FCM token...',
);

await NotificationService.saveFCMToken().timeout(
const Duration(seconds: 5),
);

AppLog.d(
'SPLASH: FCM token saved.',
);
} catch (e, stack) {
AppLog.e(
'SPLASH: FCM token error: $e',
e,
stack,
);

// Continue anyway.
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