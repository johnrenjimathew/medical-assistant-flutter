import '../models/medicine.dart';
import 'rxnorm_service.dart';

/// Represents a single detected interaction warning.
class InteractionWarning {
  final String description;
  final String severity; // 'High', 'Low', 'Unknown', or 'Local'
  final String source; // 'RxNorm' or 'Local'

  InteractionWarning({
    required this.description,
    required this.severity,
    required this.source,
  });
}

/// Merges RxNorm API-based interaction checks with the legacy local
/// interaction table to produce a single unified list of warnings.
class InteractionService {
  final RxNormService _rxNormService;

  InteractionService({RxNormService? rxNormService})
      : _rxNormService = rxNormService ?? RxNormService();

  /// Checks interactions between a new medicine and all existing medicines.
  ///
  /// Strategy:
  /// 1. Collect all rxcuis from existing medicines that have them (verified).
  /// 2. If the new medicine also has an rxcui, call RxNorm interaction API
  ///    with the new rxcui + all existing verified rxcuis.
  /// 3. Independently, run the local string-based interaction check for ALL
  ///    medicines (verified and unverified alike).
  /// 4. Merge both result sets, deduplicating by description.
  Future<List<InteractionWarning>> checkInteractions({
    required Medicine newMedicine,
    required List<Medicine> existingMedicines,
  }) async {
    final Map<String, InteractionWarning> mergedWarnings = {};

    // --- RxNorm API Check (for verified medicines) ---
    await _checkRxNormInteractions(
      newMedicine: newMedicine,
      existingMedicines: existingMedicines,
      mergedWarnings: mergedWarnings,
    );

    // --- Local DB Check (for ALL medicines, including unverified) ---
    _checkLocalInteractions(
      newMedicine: newMedicine,
      existingMedicines: existingMedicines,
      mergedWarnings: mergedWarnings,
    );

    return mergedWarnings.values.toList();
  }

  /// Builds a normalized dedup key from two drug names so that
  /// the same pair always produces the same key regardless of order.
  static String _pairKey(String a, String b) {
    final na = a.trim().toLowerCase();
    final nb = b.trim().toLowerCase();
    return na.compareTo(nb) <= 0 ? '$na|$nb' : '$nb|$na';
  }

  /// Runs the RxNorm interaction API if the new medicine has an rxcui.
  Future<void> _checkRxNormInteractions({
    required Medicine newMedicine,
    required List<Medicine> existingMedicines,
    required Map<String, InteractionWarning> mergedWarnings,
  }) async {
    // Collect all interaction rxcuis (ingredient-level preferred, then drug-level)
    final Set<String> allRxcuis = {..._interactionRxcuisFor(newMedicine)};
    for (final med in existingMedicines) {
      allRxcuis.addAll(_interactionRxcuisFor(med));
    }

    if (allRxcuis.length < 2) return;

    // RxNormService.getInteractions returns [] on failure (graceful)
    final results = await _rxNormService.getInteractions(allRxcuis.toList());

    for (final result in results) {
      final description = result['description'] as String? ?? '';
      if (description.isEmpty) continue;

      // Extract drug names from the result
      String drugA = result['drugA'] as String? ?? '';
      String drugB = result['drugB'] as String? ?? '';

      // Map RxNorm names back to local medicine names using tiered matching:
      // 1. Exact match (case-insensitive)
      // 2. Word-boundary match (RxNorm name appears as a full word in local name)
      // 3. Substring match as last resort (only if RxNorm name is long enough to avoid false positives)
      final lowerA = drugA.toLowerCase();
      final lowerB = drugB.toLowerCase();

      String mappedA = drugA;
      String mappedB = drugB;

      final allLocalMeds = [newMedicine, ...existingMedicines];
      for (final med in allLocalMeds) {
        final medNameLower = med.name.toLowerCase();
        final rxcuiNameLower = (med.normalizedName ?? '').toLowerCase();

        if (_matchesDrugName(lowerA, medNameLower, rxcuiNameLower)) {
          mappedA = med.name;
        }
        if (_matchesDrugName(lowerB, medNameLower, rxcuiNameLower)) {
          mappedB = med.name;
        }
      }

      final key = (mappedA.isNotEmpty && mappedB.isNotEmpty)
          ? _pairKey(mappedA, mappedB)
          : description;

      if (!mergedWarnings.containsKey(key)) {
        mergedWarnings[key] = InteractionWarning(
          description: description,
          severity: result['severity'] as String? ?? 'Unknown',
          source: 'RxNorm',
        );
      }
    }
  }

  /// Runs the legacy local string-based interaction check from MedicineInteraction.
  void _checkLocalInteractions({
    required Medicine newMedicine,
    required List<Medicine> existingMedicines,
    required Map<String, InteractionWarning> mergedWarnings,
  }) {
    final knownConflicts =
        MedicineInteraction.checkInteractions(newMedicine.name);

    if (knownConflicts.isEmpty) return;

    for (final existingMed in existingMedicines) {
      final existingNameNormalized = existingMed.name.trim().toLowerCase();
      for (final conflict in knownConflicts) {
        if (conflict.trim().toLowerCase() == existingNameNormalized) {
          // Use the same normalized pair key so RxNorm takes precedence
          final key = _pairKey(newMedicine.name, existingMed.name);
          if (!mergedWarnings.containsKey(key)) {
            final description =
                '${newMedicine.name} may interact with ${existingMed.name} (local database)';
            mergedWarnings[key] = InteractionWarning(
              description: description,
              severity: 'Local',
              source: 'Local',
            );
          }
        }
      }
    }
  }

  /// Tiered matching to map an RxNorm drug name to a local medicine name:
  /// 1. Exact match (case-insensitive)
  /// 2. Word-boundary match (rxNormName appears as a full word in local name)
  /// 3. Substring match as last resort, only if rxNormName is >= 4 chars
  ///    to avoid false positives like "al" matching "alcohol"
  static bool _matchesDrugName(
      String rxNormName, String localName, String normalizedName) {
    if (rxNormName.isEmpty) return false;

    // Tier 1: Exact match against local name or normalizedName
    if (rxNormName == localName || rxNormName == normalizedName) return true;

    // Tier 2: Word-boundary match (rxNormName appears as a whole word)
    final wordBoundary = RegExp(r'\b' + RegExp.escape(rxNormName) + r'\b');
    if (wordBoundary.hasMatch(localName)) return true;
    if (normalizedName.isNotEmpty && wordBoundary.hasMatch(normalizedName)) {
      return true;
    }

    // Tier 3: Substring match, only for names long enough to be meaningful
    if (rxNormName.length >= 4) {
      if (localName.contains(rxNormName)) return true;
      if (normalizedName.isNotEmpty && normalizedName.contains(rxNormName)) {
        return true;
      }
    }

    return false;
  }

  void dispose() {
    _rxNormService.dispose();
  }

  List<String> _interactionRxcuisFor(Medicine medicine) {
    final ingredient = medicine.ingredientRxcui;
    if (ingredient != null && ingredient.trim().isNotEmpty) {
      return ingredient
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }

    final rxcui = medicine.rxcui;
    if (rxcui != null && rxcui.trim().isNotEmpty) {
      return [rxcui.trim()];
    }

    return const [];
  }
}
