import 'package:sqflite/sqflite.dart';
import '../models/medicine.dart';
import '../services/database_service.dart';
import 'package:medicine_reminder/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class MedicineRepository {
  final DatabaseService _dbService = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  
  int _notificationCounter = 0;

  /* -------------------- INSERT -------------------- */

  Future<void> insertMedicine(Medicine medicine) async {
    final db = await _dbService.database;

    await db.insert(
      'medicines',
      medicine.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notificationCounter = 0;

    await _scheduleAllRecurringNotifications(medicine);
  }

  /* -------------------- FETCH -------------------- */

  Future<List<Medicine>> getAllMedicines() async {
    final db = await _dbService.database;

    final medicineMaps = await db.query('medicines');
    final List<Medicine> medicines = [];

    for (final map in medicineMaps) {
      final medicineId = map['id'] as String;

      // Load reminder_times for this medicine
      final reminderRows = await db.query(
        'reminder_times',
        where: 'medicineId = ?',
        whereArgs: [medicineId],
      );

      // Extract reminderTimes and daysOfWeek
      final Set<int> reminderTimes = {};
      final Set<String> daysOfWeek = {};

      for (final row in reminderRows) {
        reminderTimes.add(row['time'] as int);
        daysOfWeek.add(row['day'] as String);
      }

      // Create fully populated Medicine
      medicines.add(
        Medicine(
          id: map['id'] as String,
          name: map['name'] as String,
          dosage: map['dosage'] as String,
          type: map['type'] as String,
          notes: map['notes'] as String?,
          startDate: DateTime.parse(map['startDate'] as String),
          endDate: DateTime.parse(map['endDate'] as String),
          reminderTimes: reminderTimes.toList()..sort(),
          daysOfWeek: daysOfWeek.toList(),
        ),
      );
    }

    return medicines;
  }

  Future<List<Medicine>> getAllMedicinesWithReminders() async {
    return getAllMedicines();
  }

  Future<List<Medicine>> getActiveMedicines() async {
    final allMedicines = await getAllMedicines();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return allMedicines
        .where((medicine) {
          final startDate = DateTime(
            medicine.startDate.year,
            medicine.startDate.month,
            medicine.startDate.day,
          );
          final endDate = DateTime(
            medicine.endDate.year,
            medicine.endDate.month,
            medicine.endDate.day,
          );
          return !startDate.isAfter(today) && !endDate.isBefore(today);
        })
        .toList();
  }

  Future<List<Medicine>> getCompletedMedicines() async {
    final db = await _dbService.database;

    final medicineMaps = await db.query('medicines');
    final List<Medicine> completedMedicines = [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final map in medicineMaps) {
      final endDate = DateTime.parse(map['endDate'] as String);

      // Only completed medicines
      final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
      if (!endDateOnly.isBefore(today)) continue;

      final medicineId = map['id'] as String;

      // Load reminder_times for this medicine
      final reminderRows = await db.query(
        'reminder_times',
        where: 'medicineId = ?',
        whereArgs: [medicineId],
      );

      final Set<int> reminderTimes = {};
      final Set<String> daysOfWeek = {};

      for (final row in reminderRows) {
        reminderTimes.add(row['time'] as int);
        daysOfWeek.add(row['day'] as String);
      }

      completedMedicines.add(
        Medicine(
          id: map['id'] as String,
          name: map['name'] as String,
          dosage: map['dosage'] as String,
          type: map['type'] as String,
          notes: map['notes'] as String?,
          startDate: DateTime.parse(map['startDate'] as String),
          endDate: endDate,
          reminderTimes: reminderTimes.toList()..sort(),
          daysOfWeek: daysOfWeek.toList(),
        ),
      );
    }

    // Sort by most recently completed first
    completedMedicines.sort(
      (a, b) => b.endDate.compareTo(a.endDate),
    );

    return completedMedicines;
  }

  /* -------------------- UPDATE -------------------- */

  Future<void> updateMedicine({
    required Medicine oldMedicine,
    required Medicine updatedMedicine,
  }) async {
    final db = await _dbService.database;

    await _cancelNotificationsForMedicine(oldMedicine.id);

    await db.update(
      'medicines',
      updatedMedicine.toMap(),
      where: 'id = ?',
      whereArgs: [updatedMedicine.id],
    );

    await db.delete(
      'reminder_times',
      where: 'medicineId = ?',
      whereArgs: [updatedMedicine.id],
    );

    _notificationCounter = 0;

    await _scheduleAllRecurringNotifications(updatedMedicine);
  }

  /* -------------------- DELETE -------------------- */

  Future<void> deleteMedicine(Medicine medicine) async {
    final db = await _dbService.database;

    await _cancelNotificationsForMedicine(medicine.id);

    await db.delete(
      'reminder_times',
      where: 'medicineId = ?',
      whereArgs: [medicine.id],
    );

    await db.delete(
      'medicines',
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  /* -------------------- NOTIFICATION SCHEDULING  -------------------- */

  Future<void> _scheduleAllRecurringNotifications(Medicine medicine) async {
    final db = await _dbService.database;
    
    debugPrint('');
    debugPrint('[Notifications] ========================================');
    debugPrint('[Notifications] Scheduling ALL notifications for: ${medicine.name}');
    debugPrint('[Notifications] Period: ${DateFormat('MMM d').format(medicine.startDate)} - ${DateFormat('MMM d, yyyy').format(medicine.endDate)}');
    debugPrint('[Notifications] Days: ${medicine.daysOfWeek.join(', ')}');
    debugPrint('[Notifications] Times per day: ${medicine.reminderTimes.length}');
    debugPrint('[Notifications] ========================================');

    int totalScheduled = 0;

    // Loop through each selected day of the week
    for (final day in medicine.daysOfWeek) {
      // Loop through each reminder time for that day
      for (final time in medicine.reminderTimes) {
        
        final scheduledCount = await _scheduleRecurringNotificationsForDayTime(
          medicine: medicine,
          dayOfWeek: day,
          timeInMinutes: time,
          db: db,
        );
        
        totalScheduled += scheduledCount;
      }
    }

    debugPrint('');
    debugPrint(' TOTAL NOTIFICATIONS SCHEDULED: $totalScheduled');
    debugPrint(' ========================================');
    debugPrint('');
  }

  Future<int> _scheduleRecurringNotificationsForDayTime({
    required Medicine medicine,
    required String dayOfWeek,
    required int timeInMinutes,
    required Database db,
  }) async {
    final int targetWeekday = _getWeekdayIndex(dayOfWeek);
    final DateTime now = DateTime.now();
    
    // Start from the medicine start date (or today if already started)
    DateTime currentDate = medicine.startDate.isAfter(now) 
        ? medicine.startDate 
        : now;
    
    currentDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
    
    int occurrenceCount = 0;
    
    while (currentDate.isBefore(medicine.endDate) || 
           currentDate.isAtSameMomentAs(DateTime(
             medicine.endDate.year, 
             medicine.endDate.month, 
             medicine.endDate.day
           ))) {
      
      if (currentDate.weekday == targetWeekday) {
        
        DateTime scheduledTime = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          timeInMinutes ~/ 60,
          timeInMinutes % 60,
        );
        
        if (scheduledTime.isAfter(now)) {
          final int notificationId = await _generateUniqueNotificationId(
            db: db,
            medicine: medicine,
            dayOfWeek: dayOfWeek,
            timeInMinutes: timeInMinutes,
            scheduledTime: scheduledTime,
          );
          
          await db.insert('reminder_times', {
            'medicineId': medicine.id,
            'time': timeInMinutes,
            'day': dayOfWeek,
            'notificationId': notificationId,
          });
          
          final timeString = _formatTime(timeInMinutes);
          final payload = '${medicine.id}|${medicine.name}|${medicine.dosage}|$timeString';
          
          try {
            await _notificationService.scheduleNotification(
              id: notificationId,
              title: 'Medicine Reminder',
              body: 'Take ${medicine.name} (${medicine.dosage})',
              scheduledTime: scheduledTime,
              payload: payload,
            );
            
            occurrenceCount++;
            debugPrint('  [OK] #$occurrenceCount: ${DateFormat('MMM d, yyyy').format(scheduledTime)} at $timeString (ID: $notificationId)');
            
          } catch (e) {
            debugPrint('  [Error] Failed to schedule: $e');
          }
        }
      }
      
      // Move to next day
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    if (occurrenceCount > 0) {
      debugPrint('[Summary] Scheduled $occurrenceCount notifications for $dayOfWeek at ${_formatTime(timeInMinutes)}');
    }
    
    return occurrenceCount;
  }

  Future<int> _generateUniqueNotificationId({
    required Database db,
    required Medicine medicine,
    required String dayOfWeek,
    required int timeInMinutes,
    required DateTime scheduledTime,
  }) async {
    final seed =
        '${medicine.id}|$dayOfWeek|$timeInMinutes|${scheduledTime.toIso8601String()}';
    int candidate = seed.hashCode & 0x7fffffff;
    if (candidate == 0) candidate = 1;

    while (true) {
      final existing = await db.query(
        'reminder_times',
        columns: ['id'],
        where: 'notificationId = ?',
        whereArgs: [candidate],
        limit: 1,
      );
      if (existing.isEmpty) return candidate;
      candidate = (candidate + 1 + (_notificationCounter++ % 97)) & 0x7fffffff;
      if (candidate == 0) candidate = 1;
    }
  }

  /* -------------------- NOTIFICATION HELPERS -------------------- */

  /// Cancel all notifications associated with a medicine ID
  Future<void> _cancelNotificationsForMedicine(String medicineId) async {
    final db = await _dbService.database;

    // Fetch all stored notification IDs for this medicine
    final rows = await db.query(
      'reminder_times',
      columns: ['notificationId'],
      where: 'medicineId = ?',
      whereArgs: [medicineId],
    );

    debugPrint('[Cleanup] Cancelling ${rows.length} notifications for medicine $medicineId');

    for (final row in rows) {
      final int? id = row['notificationId'] as int?;
      if (id != null) {
        await _notificationService.cancelNotification(id);
      }
    }
  }

  /// Helper to format time in minutes to readable string
  String _formatTime(int timeInMinutes) {
    final hour = timeInMinutes ~/ 60;
    final minute = timeInMinutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Convert day name to weekday index (1 = Monday, 7 = Sunday)
  int _getWeekdayIndex(String day) {
    switch (day) {
      case 'Mon': return 1;
      case 'Tue': return 2;
      case 'Wed': return 3;
      case 'Thu': return 4;
      case 'Fri': return 5;
      case 'Sat': return 6;
      case 'Sun': return 7;
      default: return 1;
    }
  }

  Future<Medicine> getMedicineWithReminders(String medicineId) async {
    final db = await _dbService.database;

    final medicineMaps = await db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [medicineId],
    );

    if (medicineMaps.isEmpty) {
      throw Exception('Medicine not found');
    }

    final medicineMap = medicineMaps.first;

    final reminderRows = await db.query(
      'reminder_times',
      where: 'medicineId = ?',
      whereArgs: [medicineId],
    );

    final Set<int> reminderTimes = {};
    final Set<String> daysOfWeek = {};

    for (final row in reminderRows) {
      reminderTimes.add(row['time'] as int);
      daysOfWeek.add(row['day'] as String);
    }

    return Medicine(
      id: medicineMap['id'] as String,
      name: medicineMap['name'] as String,
      dosage: medicineMap['dosage'] as String,
      type: medicineMap['type'] as String,
      notes: medicineMap['notes'] as String?,
      startDate: DateTime.parse(medicineMap['startDate'] as String),
      endDate: DateTime.parse(medicineMap['endDate'] as String),
      reminderTimes: reminderTimes.toList()..sort(),
      daysOfWeek: daysOfWeek.toList(),
    );
  }
}

