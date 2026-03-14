import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medicine_reminder/models/reminder.dart';
import 'package:medicine_reminder/repositories/reminder_history_repository.dart';
import 'package:medicine_reminder/repositories/medicine_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ReminderHistoryRepository _repository = ReminderHistoryRepository();
  List<Reminder> _reminderHistory = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  final MedicineRepository _medicineRepository = MedicineRepository();

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final explicitHistory = await _repository.getHistory();
      final activeMedicines = await _medicineRepository.getAllMedicines();

      if (!mounted) return;

      final now = DateTime.now();
      final List<Reminder> interpolatedHistory = List.from(explicitHistory);

      // Interpolate missed reminders
      for (final med in activeMedicines) {
        // Skip medicines that haven't started or already ended before the selected date.
        // History screen relies on _getRemindersForDate iterating through _reminderHistory.
        // We'll interpolate for the last 30 days up to today to keep it reasonable.
        final startDate = DateTime(now.year, now.month, now.day - 30);
        final endDate = now;

        var currentDate = startDate;
        while (currentDate.isBefore(endDate) ||
            currentDate.isAtSameMomentAs(endDate)) {
          // Check if medicine was active on this date
          final medStartDateOnly = DateTime(
              med.startDate.year, med.startDate.month, med.startDate.day);
          final medEndDateOnly =
              DateTime(med.endDate.year, med.endDate.month, med.endDate.day);

          if (!currentDate.isBefore(medStartDateOnly) &&
              !currentDate.isAfter(medEndDateOnly)) {
            // Check if it's scheduled for this day of week
            // Force 'en_US' locale so day abbreviations always match stored strings
            final weekdayName =
                DateFormat('E', 'en_US').format(currentDate); // e.g., 'Mon'
            if (med.daysOfWeek.contains(weekdayName)) {
              for (final timeInMinutes in med.reminderTimes) {
                final scheduledTime = DateTime(
                  currentDate.year,
                  currentDate.month,
                  currentDate.day,
                  timeInMinutes ~/ 60,
                  timeInMinutes % 60,
                );

                // Only count as missed if the scheduled time is actually in the past
                if (scheduledTime.isBefore(now)) {
                  // Check if there's an explicit record for this exact scheduled time
                  final hasRecord = explicitHistory.any((r) =>
                      r.medicineId == med.id &&
                      r.scheduledDate.year == currentDate.year &&
                      r.scheduledDate.month == currentDate.month &&
                      r.scheduledDate.day == currentDate.day &&
                      r.time.hour == scheduledTime.hour &&
                      r.time.minute == scheduledTime.minute);

                  if (!hasRecord) {
                    interpolatedHistory.add(Reminder(
                      id: 'auto-missed-${med.id}-${scheduledTime.millisecondsSinceEpoch}', // Faux ID
                      medicineId: med.id,
                      medicineName: med.name,
                      dosage: med.dosage,
                      time: scheduledTime,
                      scheduledDate: currentDate,
                      isTaken: false, // Ignored = Missed
                    ));
                  }
                }
              }
            }
          }
          currentDate = currentDate.add(const Duration(days: 1));
        }
      }

      setState(() {
        _reminderHistory = interpolatedHistory;
        _isLoading = false;
      });

      debugPrint(
          'Loaded ${explicitHistory.length} explicit and ${interpolatedHistory.length - explicitHistory.length} interpolated reminder records');
    } catch (e) {
      debugPrint('Error loading history: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // Filter reminders by selected date
  List<Reminder> _getRemindersForDate(DateTime date) {
    return _reminderHistory.where((reminder) {
      return reminder.scheduledDate.year == date.year &&
          reminder.scheduledDate.month == date.month &&
          reminder.scheduledDate.day == date.day;
    }).toList()
      ..sort((a, b) => b.time.compareTo(a.time)); // Most recent first
  }

  // Navigate to previous day
  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  // Navigate to next day
  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  // Jump to today
  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final todaysReminders = _getRemindersForDate(_selectedDate);
    final takenCount = todaysReminders.where((r) => r.isTaken).length;
    final missedCount = todaysReminders.where((r) => !r.isTaken).length;
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Medicine History',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        actions: [
          // ✅ Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // ✅ Date Navigator
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left, size: 32),
                                onPressed: _previousDay,
                                tooltip: 'Previous Day',
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      DateFormat('EEEE').format(_selectedDate),
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                    Text(
                                      DateFormat('MMMM d, yyyy')
                                          .format(_selectedDate),
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, size: 32),
                                onPressed: _nextDay,
                                tooltip: 'Next Day',
                              ),
                            ],
                          ),
                          if (!isToday) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _goToToday,
                              icon: const Icon(Icons.today),
                              label: const Text('Jump to Today'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Summary Stats
                  if (todaysReminders.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Card(
                              color: Colors.green[50],
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        color: Colors.green, size: 32),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$takenCount',
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(
                                            color: Colors.green,
                                          ),
                                    ),
                                    Text(
                                      'Taken',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Card(
                              color: Colors.red[50],
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  children: [
                                    const Icon(Icons.cancel,
                                        color: Colors.red, size: 32),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$missedCount',
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(
                                            color: Colors.red,
                                          ),
                                    ),
                                    Text(
                                      'Missed',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Reminder List
                  Expanded(
                    child: todaysReminders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No reminders for this date',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Use the arrows to navigate',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: todaysReminders.length,
                            itemBuilder: (context, index) {
                              final reminder = todaysReminders[index];
                              return _buildReminderCard(reminder);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  // Build individual reminder card
  Widget _buildReminderCard(Reminder reminder) {
    final isTaken = reminder.isTaken;
    final cardColor = isTaken ? Colors.green[50] : Colors.red[50];
    final iconColor = isTaken ? Colors.green : Colors.red;
    final icon = isTaken ? Icons.check_circle : Icons.cancel;
    final statusText = isTaken ? 'Taken' : 'Missed';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: iconColor.withValues(
              alpha: 0.3), // ✅ FIXED: withOpacity → withValues
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Status Icon
            Icon(
              icon,
              color: iconColor,
              size: 48,
            ),
            const SizedBox(width: 16),

            // Medicine Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.medicineName,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dosage: ${reminder.dosage}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Time: ${DateFormat('h:mm a').format(reminder.time)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                  ),
                ],
              ),
            ),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
