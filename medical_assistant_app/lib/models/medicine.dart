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
  
  // API Integration Fields
  final String? rxcui;
  final String? normalizedName;
  final String? ingredientRxcui;
  final String? dailymedSetid;

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
    this.rxcui,
    this.normalizedName,
    this.ingredientRxcui,
    this.dailymedSetid,
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
      'rxcui': rxcui,
      'normalizedName': normalizedName,
      'ingredientRxcui': ingredientRxcui,
      'dailymedSetid': dailymedSetid,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    final reminderTimes = (map['reminderTimes'] as List<dynamic>?)
            ?.map((value) => value as int)
            .toList() ??
        [];
    final daysOfWeek = (map['daysOfWeek'] as List<dynamic>?)
            ?.map((value) => value as String)
            .toList() ??
        [];

    return Medicine(
      id: map['id'],
      name: map['name'],
      dosage: map['dosage'],
      type: map['type'],
      notes: map['notes'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      reminderTimes: reminderTimes,
      daysOfWeek: daysOfWeek,
      rxcui: map['rxcui'],
      normalizedName: map['normalizedName'],
      ingredientRxcui: map['ingredientRxcui'],
      dailymedSetid: map['dailymedSetid'],
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
    String? rxcui,
    String? normalizedName,
    String? ingredientRxcui,
    String? dailymedSetid,
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
      rxcui: rxcui ?? this.rxcui,
      normalizedName: normalizedName ?? this.normalizedName,
      ingredientRxcui: ingredientRxcui ?? this.ingredientRxcui,
      dailymedSetid: dailymedSetid ?? this.dailymedSetid,
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

  static String _normalizeMedicineName(String medicineName) {
    return medicineName.trim().toLowerCase();
  }

  static List<String> checkInteractions(String medicineName) {
    final normalizedName = _normalizeMedicineName(medicineName);

    for (final entry in interactions.entries) {
      final normalizedKey = _normalizeMedicineName(entry.key);
      if (normalizedKey == normalizedName) {
        return entry.value;
      }

      final keyPattern = RegExp(r'\b' + RegExp.escape(normalizedKey) + r'\b');
      if (keyPattern.hasMatch(normalizedName)) {
        return entry.value;
      }
    }

    return [];
  }
}
