import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'model_class.dart';

class DatabaseHelper {
  static final _databaseName = "DocumentManager.db";
  static final _databaseVersion = 3; // Increment the version

  static final table = 'documents';

  // Column names
  static final columnId = '_id';
  static final columnTitle = 'title';
  static final columnDescription = 'description';
  static final columnCreatedOn = 'created_on';
  static final columnExpiryDate = 'expiry_date';
  static final columnFilePath = 'file_path';
  static final columnFileType = 'file_type';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(path, version: _databaseVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnTitle TEXT NOT NULL,
        $columnDescription TEXT NOT NULL,
        $columnCreatedOn TEXT NOT NULL,
        $columnExpiryDate TEXT,
        $columnFilePath TEXT NOT NULL,
        $columnFileType TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      await db.execute('''
        ALTER TABLE $table ADD COLUMN $columnCreatedOn TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      ''');
    }
  }

  Future<int> insertDocument(Document document) async {
    Database db = await instance.database;
    return await db.insert(table, document.toMap());
  }

  Future<List<Map<String, dynamic>>> queryAllRows() async {
    Database db = await instance.database;
    return await db.query(table);
  }

  Future<int> delete(int id) async {
    Database db = await instance.database;
    return await db.delete(table, where: '$columnId = ?', whereArgs: [id]);
  }
}
