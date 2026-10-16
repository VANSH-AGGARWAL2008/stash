import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/item.dart';

/// Singleton wrapper around the SQLite database.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'stash.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE items (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT,
            url TEXT,
            image_path TEXT,
            tags TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            archived INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<List<Item>> getAllItems() async {
    final db = await database;
    final rows = await db.query('items', orderBy: 'updated_at DESC');
    return rows.map(Item.fromMap).toList();
  }

  Future<Item?> getItem(String id) async {
    final db = await database;
    final rows = await db.query('items', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Item.fromMap(rows.first);
  }

  Future<void> insertItem(Item item) async {
    final db = await database;
    await db.insert('items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateItem(Item item) async {
    final db = await database;
    await db.update('items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteItem(String id) async {
    final db = await database;
    await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }
}