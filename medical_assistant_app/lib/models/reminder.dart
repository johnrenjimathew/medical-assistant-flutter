class Reminder {
  final String id;
  final String medicineId;
  final String medicineName;
  final DateTime time;
  final String dosage;
  bool isTaken;
  final DateTime scheduledDate;

  Reminder({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.time,
    required this.dosage,
    this.isTaken = false,
    required this.scheduledDate,
  });

  /// Convert Reminder to Map for database storage
  /// Note: SQLite doesn't support boolean, so we store as INTEGER (0 or 1)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'time': time.toIso8601String(),
      'dosage': dosage,
      'isTaken': isTaken ? 1 : 0,  // Convert bool to int for SQLite
      'scheduledDate': scheduledDate.toIso8601String(),
    };
  }

  /// ✅ FIX: Convert Map from database to Reminder object
  /// Handles the int → bool conversion for isTaken field
  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as String,
      medicineId: map['medicineId'] as String,
      medicineName: map['medicineName'] as String,
      time: DateTime.parse(map['time'] as String),
      dosage: map['dosage'] as String,
      // ✅ FIX: Convert INTEGER (0 or 1) from database to BOOLEAN
      isTaken: _convertToBool(map['isTaken']),
      scheduledDate: DateTime.parse(map['scheduledDate'] as String),
    );
  }

  /// ✅ NEW: Helper method to safely convert database values to boolean
  /// Handles both int and bool types for backward compatibility
  static bool _convertToBool(dynamic value) {
    if (value == null) return false;
    
    // If it's already a boolean, return it
    if (value is bool) return value;
    
    // If it's an integer (from SQLite), convert it
    if (value is int) return value == 1;
    
    // If it's a string (shouldn't happen, but just in case)
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    
    // Default to false for any other type
    return false;
  }

  /// ✅ NEW: Create a copy of this Reminder with updated fields
  Reminder copyWith({
    String? id,
    String? medicineId,
    String? medicineName,
    DateTime? time,
    String? dosage,
    bool? isTaken,
    DateTime? scheduledDate,
  }) {
    return Reminder(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      medicineName: medicineName ?? this.medicineName,
      time: time ?? this.time,
      dosage: dosage ?? this.dosage,
      isTaken: isTaken ?? this.isTaken,
      scheduledDate: scheduledDate ?? this.scheduledDate,
    );
  }

  /// ✅ NEW: Helper to mark reminder as taken
  void markAsTaken() {
    isTaken = true;
  }

  /// ✅ NEW: Helper to mark reminder as missed
  void markAsMissed() {
    isTaken = false;
  }

  /// ✅ NEW: Check if this reminder is for today
  bool isToday() {
    final now = DateTime.now();
    return scheduledDate.year == now.year &&
           scheduledDate.month == now.month &&
           scheduledDate.day == now.day;
  }

  /// ✅ NEW: Check if this reminder is in the past
  bool isPast() {
    return scheduledDate.isBefore(DateTime.now());
  }

  /// ✅ NEW: Get a human-readable status
  String getStatus() {
    if (isTaken) return 'Taken';
    if (isPast()) return 'Missed';
    return 'Pending';
  }

  /// ✅ NEW: String representation for debugging
  @override
  String toString() {
    return 'Reminder('
        'id: $id, '
        'medicine: $medicineName, '
        'dosage: $dosage, '
        'time: $time, '
        'isTaken: $isTaken, '
        'status: ${getStatus()}'
        ')';
  }

  /// ✅ NEW: Equality comparison
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is Reminder &&
        other.id == id &&
        other.medicineId == medicineId &&
        other.medicineName == medicineName &&
        other.time == time &&
        other.dosage == dosage &&
        other.isTaken == isTaken &&
        other.scheduledDate == scheduledDate;
  }

  /// ✅ NEW: Hash code for use in collections
  @override
  int get hashCode {
    return id.hashCode ^
        medicineId.hashCode ^
        medicineName.hashCode ^
        time.hashCode ^
        dosage.hashCode ^
        isTaken.hashCode ^
        scheduledDate.hashCode;
  }
}