import 'package:medicine_reminder/services/database_service.dart';
import 'package:medicine_reminder/models/reminder.dart';

class ReminderHistoryRepository {
  final _dbService = DatabaseService();

  Future<void> insertHistory(Reminder reminder) async {
    final db = await _dbService.database;

    await db.insert(
      'reminder_history',
      {
        'id': reminder.id,
        'medicineId': reminder.medicineId,
        'medicineName': reminder.medicineName,
        'dosage': reminder.dosage,
        'scheduledDate': reminder.scheduledDate.toIso8601String(),
        'time': reminder.time.toIso8601String(),
        'isTaken': reminder.isTaken ? 1 : 0,
      },
    );
  }

  Future<List<Reminder>> getHistory() async {
    final db = await _dbService.database;

    final maps = await db.query(
      'reminder_history',
      orderBy: 'scheduledDate DESC',
    );

    return maps.map((map) => Reminder.fromMap(map)).toList();
  }
}
