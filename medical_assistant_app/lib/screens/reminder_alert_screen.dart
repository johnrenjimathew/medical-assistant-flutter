import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medicine_reminder/widgets/large_button.dart';
import 'package:medicine_reminder/services/notification_service.dart';
import 'package:medicine_reminder/repositories/reminder_history_repository.dart';
import 'package:medicine_reminder/models/reminder.dart';
import 'package:medicine_reminder/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderAlertScreen extends StatelessWidget {
  final String medicineId; // <--- NEW FIELD
  final String medicineName;
  final String dosage;
  final String time;

  const ReminderAlertScreen({
    super.key,
    required this.medicineId, // <--- NEW REQUIRED PARAMETER
    required this.medicineName,
    required this.dosage,
    required this.time,
  });

  DateTime _parseScheduledDateTime(String value) {
    final now = DateTime.now();
    try {
      final parsedTime = DateFormat('h:mm a').parseStrict(value);
      return DateTime(
        now.year,
        now.month,
        now.day,
        parsedTime.hour,
        parsedTime.minute,
      );
    } catch (_) {
      return now;
    }
  }

  Future<void> _saveHistory({
    required bool isTaken,
  }) async {
    final scheduledTime = _parseScheduledDateTime(time);
    final scheduledDate = DateTime(
      scheduledTime.year,
      scheduledTime.month,
      scheduledTime.day,
    );

    final reminder = Reminder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      medicineId: medicineId,
      medicineName: medicineName,
      dosage: dosage,
      time: scheduledTime,
      scheduledDate: scheduledDate,
      isTaken: isTaken,
    );

    final repository = ReminderHistoryRepository();
    await repository.insertHistory(reminder);
  }

  @override
  Widget build(BuildContext context) {
    final TtsService ttsService = TtsService();
    
    // Speak the reminder when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ttsService.textToSpeech(
        'Time to take your $medicineName. Dosage: $dosage.'
      );
    });

    return Scaffold(
      backgroundColor: Colors.red[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.notifications_active,
                size: 100,
                color: Colors.red,
              ),
              const SizedBox(height: 30),
              Text(
                'Medicine Reminder',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Time: $time',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.medication,
                      size: 60,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      medicineName,
                      style: Theme.of(context).textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Dosage: $dosage',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: LargeButton(
                      text: 'Snooze',
                      icon: Icons.snooze,
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final snoozeMinutes = prefs.getInt('snoozeDuration') ?? 10;
                        final snoozeTime =
                            DateTime.now().add(Duration(minutes: snoozeMinutes));
                        final snoozeTimeLabel =
                            DateFormat('h:mm a').format(snoozeTime);
                        final snoozeId = DateTime.now()
                                .millisecondsSinceEpoch
                                .remainder(0x7fffffff) ^
                            medicineId.hashCode;

                        await NotificationService().scheduleNotification(
                          id: snoozeId & 0x7fffffff,
                          title: 'Medicine Reminder',
                          body: 'Take $medicineName ($dosage)',
                          scheduledTime: snoozeTime,
                          payload:
                              '$medicineId|$medicineName|$dosage|$snoozeTimeLabel',
                        );

                        ttsService.textToSpeech(
                          'Snoozed for $snoozeMinutes minutes',
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      backgroundColor: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: LargeButton(
                      text: 'Taken',
                      icon: Icons.check_circle,
                      onPressed: () async {
                        await _saveHistory(isTaken: true);
                        ttsService.textToSpeech('Medicine marked as taken');
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LargeButton(
                text: 'Mark as Missed',
                icon: Icons.cancel,
                onPressed: () async {
                  await _saveHistory(isTaken: false);
                  ttsService.textToSpeech('Medicine marked as missed');
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                backgroundColor: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
