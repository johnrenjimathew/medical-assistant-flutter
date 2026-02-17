import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medicine_reminder/models/medicine.dart';

class MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;

  const MedicineCard({
    super.key,
    required this.medicine,
    this.onTap,
    this.onLongPress,
    this.onEdit,
  });

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// ✅ FIXED: Better title row with flexible layout
              Row(
                children: [
                  // Medicine name - takes available space, allows wrapping
                  Expanded(
                    child: Tooltip(
                      message: medicine.name, // Shows full name on long press
                      child: Text(
                        medicine.name,
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 26, // Reduced from 32 to 26
                        ),
                        maxLines: 2, // Allow 2 lines for longer names
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Type chip - fixed size
                  Chip(
                    label: Text(
                      medicine.type,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14, // Slightly smaller
                      ),
                    ),
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  
                  // Edit button
                  IconButton(
                    icon: const Icon(Icons.edit, size: 28),
                    tooltip: 'Edit Medicine',
                    onPressed: onEdit,
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Dosage
              Text(
                'Dosage: ${medicine.dosage}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 20, // Reduced from 24 to 20
                ),
              ),

              const SizedBox(height: 8),

              // Notes (if exists)
              if (medicine.notes != null && medicine.notes!.isNotEmpty) ...[
                Text(
                  'Notes: ${medicine.notes!}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],

              /// ✅ FIXED: Days shown as individual chips instead of long text
              Text(
                'Schedule:',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 20, // Reduced from 24 to 20
                ),
              ),
              const SizedBox(height: 6),
              
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: medicine.daysOfWeek.map((day) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      day,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w600,
                        fontSize: 16, // Readable but not huge
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),

              // Times
              Text(
                'Reminder Times:',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 20, // Reduced from 24 to 20
                ),
              ),
              const SizedBox(height: 6),
              
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: medicine.reminderTimes.map((time) {
                  return Chip(
                    avatar: const Icon(Icons.access_time, size: 18),
                    label: Text(
                      _formatTime(time),
                      style: const TextStyle(
                        fontSize: 16, // Readable but compact
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: Colors.green[100],
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),

              /// ✅ FIXED: Date range with line break if needed
              Text(
                'Duration:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('MMM d, yyyy').format(medicine.startDate)} - ${DateFormat('MMM d, yyyy').format(medicine.endDate)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                  fontSize: 16, // Slightly smaller for dates
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}