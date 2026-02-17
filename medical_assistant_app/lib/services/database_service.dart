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
      version: 1,
      onCreate: _onCreate,
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
        endDate TEXT
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
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        medicineId TEXT,
        scheduledDate TEXT,
        time TEXT,
        dosage TEXT,
        isTaken INTEGER
      )
    ''');
  }
}
