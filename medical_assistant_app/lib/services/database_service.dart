import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'medicine_reminder.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medicines (
        id TEXT PRIMARY KEY,
        name TEXT,
        dosage TEXT,
        type TEXT,
        notes TEXT,
        startDate TEXT,
        endDate TEXT,
        rxcui TEXT,
        normalizedName TEXT,
        ingredientRxcui TEXT,
        dailymedSetid TEXT
      )
    ''');
    await db.execute('''
    CREATE TABLE reminder_times (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      medicineId TEXT,
      time INTEGER,
      day TEXT,
      notificationId INTEGER -- NEW COLUMN
    )
    ''');

    await db.execute('''
      CREATE TABLE reminder_history (
      id TEXT PRIMARY KEY,
      medicineId TEXT,
      medicineName TEXT,
      dosage TEXT,
      scheduledDate TEXT,
      time TEXT,
      isTaken INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS drug_info (
        rxcui TEXT PRIMARY KEY,
        indications_usage TEXT,
        dosage_administration TEXT,
        warnings TEXT,
        adverse_reactions TEXT,
        raw_indications_usage TEXT,
        raw_dosage_administration TEXT,
        raw_warnings TEXT,
        raw_adverse_reactions TEXT,
        last_updated INTEGER
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE medicines ADD COLUMN rxcui TEXT;');
      await db.execute('ALTER TABLE medicines ADD COLUMN normalizedName TEXT;');
      await db.execute('ALTER TABLE medicines ADD COLUMN ingredientRxcui TEXT;');
      await db.execute('ALTER TABLE medicines ADD COLUMN dailymedSetid TEXT;');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS drug_info (
          rxcui TEXT PRIMARY KEY,
          indications_usage TEXT,
          dosage_administration TEXT,
          warnings TEXT,
          adverse_reactions TEXT,
          raw_indications_usage TEXT,
          raw_dosage_administration TEXT,
          raw_warnings TEXT,
          raw_adverse_reactions TEXT,
          last_updated INTEGER
        )
      ''');
    }

    if (oldVersion >= 2 && oldVersion < 3) {
      await db.execute(
          'ALTER TABLE drug_info ADD COLUMN raw_indications_usage TEXT;');
      await db.execute(
          'ALTER TABLE drug_info ADD COLUMN raw_dosage_administration TEXT;');
      await db.execute('ALTER TABLE drug_info ADD COLUMN raw_warnings TEXT;');
      await db.execute(
          'ALTER TABLE drug_info ADD COLUMN raw_adverse_reactions TEXT;');
    }
  }
}
