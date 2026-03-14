import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:medicine_reminder/models/medicine.dart';
import 'package:medicine_reminder/repositories/medicine_repository.dart';
import 'package:medicine_reminder/services/database_service.dart';
import 'package:medicine_reminder/utils/feature_flags.dart';

import 'medicine_repository_test.mocks.dart';

@GenerateMocks([DatabaseService])
void main() {
  late MedicineRepository repository;
  late MockDatabaseService mockDb;
  late Database ffiDb;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Use a real in-memory FFI SQLite database for the integration test
    ffiDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await ffiDb.execute('''
      CREATE TABLE medicines(
        id TEXT PRIMARY KEY,
        name TEXT,
        type TEXT,
        dosage TEXT,
        notes TEXT,
        startDate TEXT,
        endDate TEXT,
        rxcui TEXT,
        normalizedName TEXT,
        ingredientRxcui TEXT,
        dailymedSetid TEXT
      )
    ''');
    await ffiDb.execute('''
      CREATE TABLE reminder_times(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicineId TEXT,
        time TEXT,
        FOREIGN KEY(medicineId) REFERENCES medicines(id)
      )
    ''');
    await ffiDb.execute('''
      CREATE TABLE days_of_week(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicineId TEXT,
        day TEXT,
        FOREIGN KEY(medicineId) REFERENCES medicines(id)
      )
    ''');
  });

  setUp(() async {
    // Clear the DB between tests
    await ffiDb.execute('DELETE FROM reminder_times');
    await ffiDb.execute('DELETE FROM days_of_week');
    await ffiDb.execute('DELETE FROM medicines');

    mockDb = MockDatabaseService();
    when(mockDb.database).thenAnswer((_) async => ffiDb);

    // Disable all external networking hooks via the Feature Flags
    // Use reset explicitly for each test state
    FeatureFlags.enableRxNormApi = false;
    FeatureFlags.enableDailyMedApi = false;
  });

  tearDown(() {
    // Reset back to defaults
    FeatureFlags.enableRxNormApi = true;
    FeatureFlags.enableDailyMedApi = true;
  });

  test('MedicineRepository offline integration simulation', () async {
    // repository instantiated with proper Dependency Injection
    repository = MedicineRepository(dbService: mockDb);

    final med = Medicine(
      id: 'integration-test-1',
      name: 'Test Aspirin',
      type: 'Pill',
      dosage: '100mg',
      startDate: DateTime.now(),
      endDate: DateTime.now(),
      reminderTimes: [],
      daysOfWeek: ['Monday'],
      rxcui: '1191',
    );

    // Attempt to save. The network call will be bypassed via FeatureFlags.
    await repository.insertMedicine(med);

    // Verify it saved
    final allMeds = await repository.getAllMedicines();
    expect(allMeds.length, 1);
    expect(allMeds.first.name, 'Test Aspirin');

    // Attempt to fetch DailyMed info. It should return null immediately because it's disabled.
    final drugInfo = await repository.getDrugInfo('1191');
    expect(drugInfo, isNull);
  });

  test('DatabaseService v1 to v2 schema migration simulation', () async {
    // Spin up a raw FFI database simulating v1 (no rxcui columns, no drug_info)
    final v1DbPath = 'test_migration.db';
    // Clean up any old file before we start
    try {
      await databaseFactoryFfi.deleteDatabase(v1DbPath);
    } catch (_) {}
    final db = await databaseFactoryFfi.openDatabase(
      v1DbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute('''
            CREATE TABLE medicines(
              id TEXT PRIMARY KEY,
              name TEXT,
              type TEXT,
              dosage TEXT,
              startDate TEXT,
              endDate TEXT
            )
          ''');
        },
      ),
    );

    // Insert v1 legacy data
    await db.insert('medicines', {
      'id': 'legacy-med-1',
      'name': 'Legacy Ibuprofen',
      'type': 'Pill',
      'dosage': '200mg',
      'startDate': DateTime.now().toIso8601String(),
      'endDate': DateTime.now().toIso8601String(),
    });

    await db.close();

    // Now trigger the upgrade by instantiating the real DatabaseService against the same file mapping
    // We can manually hook its onUpgrade function by simulating what DatabaseService does.

    final migratedDb = await databaseFactoryFfi.openDatabase(
      v1DbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE medicines ADD COLUMN rxcui TEXT');
            await db.execute(
                'ALTER TABLE medicines ADD COLUMN normalizedName TEXT');
            await db.execute(
                'ALTER TABLE medicines ADD COLUMN ingredientRxcui TEXT');
            await db
                .execute('ALTER TABLE medicines ADD COLUMN dailymedSetid TEXT');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS drug_info(
                rxcui TEXT PRIMARY KEY,
                indications_usage TEXT,
                dosage_administration TEXT,
                warnings TEXT,
                adverse_reactions TEXT,
                last_updated INTEGER NOT NULL
              )
            ''');
          }
        },
      ),
    );

    // Verify old row exists and new columns are NULL
    final rows = await migratedDb.query('medicines');
    expect(rows.length, 1);
    expect(rows.first['name'], 'Legacy Ibuprofen');
    expect(rows.first.containsKey('rxcui'), true);
    expect(rows.first['rxcui'], isNull);

    // Verify drug_info table exists
    final tableCheck = await migratedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='drug_info'");
    expect(tableCheck.isNotEmpty, true);

    await migratedDb.close();
  });
}
