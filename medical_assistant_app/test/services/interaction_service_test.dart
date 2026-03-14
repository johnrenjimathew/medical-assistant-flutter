import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:medicine_reminder/models/medicine.dart';
import 'package:medicine_reminder/services/interaction_service.dart';
import 'package:medicine_reminder/services/rxnorm_service.dart';

import 'interaction_service_test.mocks.dart';

@GenerateMocks([RxNormService])
void main() {
  late MockRxNormService mockRxNorm;
  late InteractionService service;

  setUp(() {
    mockRxNorm = MockRxNormService();
    service = InteractionService(rxNormService: mockRxNorm);
  });

  group('InteractionService - checkInteractions', () {
    test('merges RxNorm and local results without duplicates (RxNorm wins)',
        () async {
      final medicines = [
        Medicine(
            id: '1',
            name: 'Aspirin',
            type: 'Pill',
            dosage: '80mg',
            startDate: DateTime.now(),
            endDate: DateTime.now(),
            reminderTimes: [],
            daysOfWeek: ['Monday'],
            rxcui: '1191',
            normalizedName: 'aspirin'),
        Medicine(
            id: '2',
            name: 'Warfarin',
            type: 'Pill',
            dosage: '5mg',
            startDate: DateTime.now(),
            endDate: DateTime.now(),
            reminderTimes: [],
            daysOfWeek: ['Monday'],
            rxcui: '11289',
            normalizedName: 'warfarin'),
      ];

      // Local fallback in MedicineInteraction.checkInteractions('Aspirin') returns ['Warfarin']

      // But RxNorm also returns an interaction
      // We use `any` or `argThat` so we aren't dependent on list sorting implementation details
      when(mockRxNorm.getInteractions(any)).thenAnswer((_) async => [
            {
              'description': 'RXNORM: Aspirin and Warfarin may cause bleeding',
              'severity': 'high',
              'drugA': 'Aspirin',
              'drugB': 'Warfarin'
            }
          ]);

      final warnings = await service.checkInteractions(
          newMedicine: medicines[0], existingMedicines: [medicines[1]]);

      // Verify no duplicates: Local interaction was subsumed by RxNorm because the Normalized Keys matched
      expect(warnings.length, 1);
      expect(warnings.first.source, 'RxNorm');
      expect(warnings.first.description,
          'RXNORM: Aspirin and Warfarin may cause bleeding');
    });

    test(
        'deduplicates correctly even when RxNorm drug names differ from local names (name mismatch)',
        () async {
      // Local medicine has extraneous text (Dosage/Form) compared to RxNorm raw names
      final medicines = [
        Medicine(
            id: '1',
            name: 'Aspirin 325 MG Oral Tablet',
            type: 'Pill',
            dosage: '325mg',
            startDate: DateTime.now(),
            endDate: DateTime.now(),
            reminderTimes: [],
            daysOfWeek: ['Monday'],
            rxcui: '1191', // We mapped Aspirin 325 to RxCui 1191
            normalizedName: 'aspirin'),
        Medicine(
            id: '2',
            name: 'Warfarin Sodium 5 MG',
            type: 'Pill',
            dosage: '5mg',
            startDate: DateTime.now(),
            endDate: DateTime.now(),
            reminderTimes: [],
            daysOfWeek: ['Monday'],
            rxcui: '11289', // Mapped to 11289
            normalizedName: 'warfarin'),
      ];

      when(mockRxNorm.getInteractions(any)).thenAnswer((_) async => [
            {
              'description': 'RXNORM: Aspirin and Warfarin may cause bleeding',
              'severity': 'high',
              'drugA': 'Aspirin', // RxNorm only returns base ingredient name
              'drugB': 'Warfarin'
            }
          ]);

      final warnings = await service.checkInteractions(
          newMedicine: medicines[0], existingMedicines: [medicines[1]]);

      // Deduplication based on mapped local names should ensure only 1 warning
      // because the local legacy array MedicineInteraction.checkInteractions('Aspirin 325...')
      // will also trigger a local check (since local check is string-based and usually loops subsets).
      // Even if local returns something, RxNorm should win and map its result to the local names
      // so their keys collide intentionally.
      expect(warnings.length, 1);
      expect(warnings.first.source, 'RxNorm');
    });

    test('returns only local interactions when RxNorm has none', () async {
      // Testing Ibuprofen and Lithium. Ibuprofen interacts with Lithium locally.
      final medicines = [
        Medicine(
            id: '3',
            name: 'Ibuprofen',
            type: 'Pill',
            dosage: '200mg',
            startDate: DateTime.now(),
            endDate: DateTime.now(),
            reminderTimes: [],
            daysOfWeek: ['Monday'],
            rxcui: '5640',
            normalizedName: 'ibuprofen'),
        Medicine(
            id: '4',
            name: 'Lithium',
            type: 'Pill',
            dosage: '250mg',
            startDate: DateTime.now(),
            endDate: DateTime.now(),
            reminderTimes: [],
            daysOfWeek: ['Monday'],
            rxcui: '7258',
            normalizedName: 'lithium'),
      ];

      // RxNorm returns NO interactions
      when(mockRxNorm.getInteractions(['5640', '7258']))
          .thenAnswer((_) async => []);

      final warnings = await service.checkInteractions(
          newMedicine: medicines[0], existingMedicines: [medicines[1]]);

      // Verify local fallback is used
      expect(warnings.length, 1);
      expect(warnings.first.source, 'Local');
      expect(warnings.first.description,
          'Ibuprofen may interact with Lithium (local database)');
    });

    test(
        'ignores medicines without an RxCUI for RxNorm searches, but checks them locally',
        () async {
      final medicines = [
        Medicine(
            id: '3',
            name: 'Metformin',
            type: 'Pill',
            dosage: '200mg',
            startDate: DateTime.now(),
            endDate: DateTime.now(),
            reminderTimes: [],
            daysOfWeek: ['Monday'],
            rxcui: null,
            normalizedName: 'metformin'), // No RxCUI
        Medicine(
            id: '4',
            name: 'Alcohol',
            type: 'Liquid',
            dosage: '1 shot',
            startDate: DateTime.now(),
            endDate: DateTime.now(),
            reminderTimes: [],
            daysOfWeek: ['Monday'],
            rxcui: null,
            normalizedName: 'alcohol'), // No RxCUI
      ];

      // Metformin interacts with Alcohol locally.

      final warnings = await service.checkInteractions(
          newMedicine: medicines[0], existingMedicines: [medicines[1]]);

      // Verify RxNorm was never called for interactions
      verifyNever(mockRxNorm.getInteractions(any));

      // Verify local fallback is used since names match locally
      expect(warnings.length, 1);
      expect(warnings.first.source, 'Local');
      expect(warnings.first.description,
          'Metformin may interact with Alcohol (local database)');
    });
  });
}
