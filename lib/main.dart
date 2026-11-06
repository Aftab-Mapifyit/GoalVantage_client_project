import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/revenue_cat_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'theme/colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init('market_cache');

  if (Firebase.apps.isEmpty) {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
  }

  debugPrint('🔥 ACTIVE FIREBASE PROJECT ID: ${Firebase.app().options.projectId}');

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  var newOddsEnabled = true;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    try {
      final settings = await FirebaseFirestore.instance.collection('user_settings').doc(uid).get();
      final data = settings.data();
      newOddsEnabled = (data?['pushNotifications'] ?? true) == true &&
          (data?['predictionAlerts'] ?? true) == true;
    } catch (error) {
      debugPrint('Could not load notification preferences: $error');
    }
  }
  await NotificationService.instance.initialize(subscribeToOdds: newOddsEnabled);
  await RevenueCatService.instance.initialize();

  runApp(const AuraTradesApp());
}

class AuraTradesApp extends StatelessWidget {
  const AuraTradesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PitchIQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        // Update AppColors static palette
        final appColors = Theme.of(context).extension<AppColors>()!;
        AppColors.setCurrent(appColors);

        // Update GoalVantageColors static palette
        final pitchColors = Theme.of(context).extension<GoalVantageColors>()!;
        GoalVantageColors.setCurrent(pitchColors);

        return child!;
      },
      // home: const GoalVantageHomeScreen(),
      home: const SplashScreen(),
    );
  }
}
