import 'package:flutter/material.dart';
import 'package:medicine_reminder/screens/home_screen.dart';
import 'package:medicine_reminder/services/notification_service.dart';
import 'package:medicine_reminder/services/stt_service.dart';
import 'package:medicine_reminder/services/tts_service.dart';
import 'package:medicine_reminder/widgets/accessibility_wrapper.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await NotificationService().init();
  await TtsService().init();
  await SttService().init();
  
  runApp(const MedicineReminderApp());
}

class MedicineReminderApp extends StatelessWidget {
  const MedicineReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      
      title: 'Medicine Reminder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 20),
          bodyMedium: TextStyle(fontSize: 18),
        ),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
          backgroundColor: Colors.white,
        ).copyWith(
          secondary: Colors.green,
        ),
      ),
      home: const AccessibilityWrapper(
        child: HomeScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
