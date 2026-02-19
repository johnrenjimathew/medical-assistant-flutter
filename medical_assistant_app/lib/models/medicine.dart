class Medicine {
  final String id;
  final String name;
  final String dosage;
  final String type; 
  final String? notes;
  final DateTime startDate;
  final DateTime endDate;
  final List<int> reminderTimes; 
  final List<String> daysOfWeek; 

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.type,
    this.notes,
    required this.startDate,
    required this.endDate,
    required this.reminderTimes,
    required this.daysOfWeek,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'type': type,
      'notes': notes,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'],
      name: map['name'],
      dosage: map['dosage'],
      type: map['type'],
      notes: map['notes'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      reminderTimes: [],
      daysOfWeek: [],
    );
  }
  Medicine copyWith({
  String? id,
  String? name,
  String? dosage,
  String? type,
  String? notes,
  DateTime? startDate,
  DateTime? endDate,
  List<int>? reminderTimes,
  List<String>? daysOfWeek,
}) {
  return Medicine(
    id: id ?? this.id,
    name: name ?? this.name,
    dosage: dosage ?? this.dosage,
    type: type ?? this.type,
    notes: notes ?? this.notes,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    reminderTimes: reminderTimes ?? this.reminderTimes,
    daysOfWeek: daysOfWeek ?? this.daysOfWeek,
  );
}

}

/// Simple interaction database (academic purpose)
class MedicineInteraction {
  static final Map<String, List<String>> interactions = {
    'Warfarin': ['Aspirin', 'Ibuprofen', 'Naproxen'],
    'Aspirin': ['Warfarin', 'Ibuprofen'],
    'Ibuprofen': ['Warfarin', 'Aspirin', 'Lithium'],
    'Metformin': ['Alcohol'],
    'Paracetamol': ['Alcohol'],
  };

  static List<String> checkInteractions(String medicineName) {
    return interactions[medicineName] ?? [];
  }

}
