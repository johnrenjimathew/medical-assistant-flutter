import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:medicine_reminder/services/dailymed_service.dart';
import 'package:medicine_reminder/services/database_service.dart';

import 'dailymed_service_test.mocks.dart';

// Generate a MockDatabaseService and MockClient
@GenerateMocks([DatabaseService, http.Client])
void main() {
  late MockClient mockClient;
  late MockDatabaseService mockDbService;
  late DailyMedService service;
  late Database ffiDb;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Create the real in-memory FFI database once
    ffiDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await ffiDb.execute('''
      CREATE TABLE IF NOT EXISTS drug_info (
        rxcui TEXT PRIMARY KEY,
        indications_usage TEXT,
        dosage_administration TEXT,
        warnings TEXT,
        adverse_reactions TEXT,
        last_updated INTEGER
      )
    ''');
  });

  setUp(() async {
    mockClient = MockClient();
    mockDbService = MockDatabaseService();

    // Wire the mock DatabaseService to return our real FFI database
    when(mockDbService.database).thenAnswer((_) async => ffiDb);

    // Ensure fresh DB table for each test
    await ffiDb.delete('drug_info');

    service = DailyMedService(
      client: mockClient,
      dbService: mockDbService,
    );
  });

  group('DailyMedService - Fetch & Parse', () {
    test('succesfully fetches, parses XML, and caches new drug info', () async {
      final setIdResponse = {
        'data': [
          {'setid': '1234-abcd'}
        ]
      };

      final xmlResponse = '''
      <?xml version="1.0" encoding="UTF-8"?>
      <document>
        <section>
          <title>INDICATIONS AND USAGE</title>
          <text>Used for pain relief.</text>
        </section>
        <section>
          <title>WARNINGS</title>
          <text>Do not take if allergic.</text>
        </section>
      </document>
      ''';

      when(mockClient.get(any)).thenAnswer((invocation) async {
        final url = invocation.positionalArguments[0].toString();
        if (url.contains('spls.json?rxcui=1191')) {
          return http.Response(jsonEncode(setIdResponse), 200);
        } else if (url.contains('spls/1234-abcd.xml')) {
          return http.Response(xmlResponse, 200);
        }
        return http.Response('Not Found', 404);
      });

      final info = await service.getDrugInfo('1191');

      expect(info, isNotNull);
      expect(info!.rxcui, '1191');
      // Note: _parseSplXml uses section.innerText which concatenates all child nodes (like <title> and <text>). This is expected behaviour.
      expect(info.indicationsUsage,
          'INDICATIONS AND USAGE\n          Used for pain relief.');
      expect(info.warnings, 'WARNINGS\n          Do not take if allergic.');

      // Verify it was cached
      final rows = await ffiDb
          .query('drug_info', where: 'rxcui = ?', whereArgs: ['1191']);
      expect(rows.length, 1);
    });

    test('returns null if setId is not found and cache is empty', () async {
      when(mockClient.get(any)).thenAnswer(
          (_) async => http.Response(jsonEncode({'data': []}), 200));

      final info = await service.getDrugInfo('9999');
      expect(info, isNull);
    });
  });

  group('DailyMedService - Cache Policy', () {
    test('uses fresh cache without hitting network', () async {
      await ffiDb.insert('drug_info', {
        'rxcui': '1191',
        'indications_usage': 'Cached indications',
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      });

      final info = await service.getDrugInfo('1191');

      expect(info?.indicationsUsage, 'Cached indications');
      verifyZeroInteractions(mockClient);
    });

    test('falls back to stale cache on network failure (500)', () async {
      await ffiDb.insert('drug_info', {
        'rxcui': '1191',
        'warnings': 'Stale warnings',
        'last_updated': DateTime.now()
            .subtract(const Duration(days: 40))
            .millisecondsSinceEpoch,
      });

      final rowBefore = await ffiDb
          .query('drug_info', where: 'rxcui = ?', whereArgs: ['1191']);
      final timestampBefore = rowBefore.first['last_updated'];

      when(mockClient.get(any))
          .thenAnswer((_) async => http.Response('Server Error', 500));

      final info = await service.getDrugInfo('1191');

      expect(info?.warnings, 'Stale warnings');

      final rowAfter = await ffiDb
          .query('drug_info', where: 'rxcui = ?', whereArgs: ['1191']);
      expect(rowAfter.first['last_updated'],
          timestampBefore); // Timestamp must NOT change on failure
    });

    test('falls back to stale cache on total XML parse failure (malformed)',
        () async {
      await ffiDb.insert('drug_info', {
        'rxcui': '1191',
        'warnings': 'Stale warnings',
        'last_updated': DateTime.now()
            .subtract(const Duration(days: 40))
            .millisecondsSinceEpoch,
      });

      when(mockClient.get(any)).thenAnswer((invocation) async {
        final url = invocation.positionalArguments[0].toString();
        if (url.contains('spls.json')) {
          return http.Response(
              jsonEncode({
                'data': [
                  {'setid': '1234'}
                ]
              }),
              200);
        }
        return http.Response('<invalid><<xml', 200);
      });

      final rowBefore = await ffiDb
          .query('drug_info', where: 'rxcui = ?', whereArgs: ['1191']);
      final timestampBefore = rowBefore.first['last_updated'];

      final info = await service.getDrugInfo('1191');

      // Should return the stale cache instead of overwriting with empty data
      expect(info?.warnings, 'Stale warnings');

      final rowAfter = await ffiDb
          .query('drug_info', where: 'rxcui = ?', whereArgs: ['1191']);
      expect(rowAfter.first['last_updated'],
          timestampBefore); // Timestamp must NOT change on failure
    });
  });
}
