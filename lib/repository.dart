import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'comic.dart';

class ComicRepository {
  static const _databaseName = 'zone_comics.db';
  static const _legacyDatabaseName = 'mycomics.db';
  static const _migrationKey = 'sqlite_migrated_v1';
  static const _releaseUpdatedKey = 'releases_updated_v1';

  final _prefs = SharedPreferencesAsync();
  final _secure = const FlutterSecureStorage();
  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;
    final databasesPath = await getDatabasesPath();
    final databasePath = p.join(databasesPath, _databaseName);
    final legacyDatabasePath = p.join(databasesPath, _legacyDatabaseName);
    if (!await databaseExists(databasePath) &&
        await databaseExists(legacyDatabasePath)) {
      final legacyDatabase = await openDatabase(legacyDatabasePath);
      await legacyDatabase.close();
      await File(legacyDatabasePath).copy(databasePath);
    }
    final database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE comics (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            publisher TEXT NOT NULL,
            status TEXT NOT NULL,
            issue TEXT NOT NULL DEFAULT '',
            year TEXT NOT NULL DEFAULT '',
            rating INTEGER NOT NULL DEFAULT 0,
            notes TEXT NOT NULL DEFAULT '',
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE releases (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            publisher TEXT NOT NULL,
            release_date TEXT NOT NULL,
            issue TEXT NOT NULL DEFAULT '',
            image TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
    _database = database;
    return database;
  }

  Future<void> initialize() async {
    final db = await _db;
    await _migrateLegacyData(db);
  }

  Future<void> _migrateLegacyData(Database db) async {
    if (await _prefs.getBool(_migrationKey) == true) return;
    final oldComics = await _prefs.getString('comics_v1');
    final oldReleases = await _prefs.getString('releases_v1');
    final oldRefresh = await _prefs.getString(_releaseUpdatedKey);
    await db.transaction((txn) async {
      if (oldComics != null) {
        try {
          for (final comic in decodeComics(oldComics)) {
            await txn.insert(
              'comics',
              _comicRow(comic),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        } catch (_) {
          // Une ancienne sauvegarde illisible ne doit pas bloquer le démarrage.
        }
      }
      if (oldReleases != null) {
        try {
          final decoded = jsonDecode(oldReleases) as List;
          for (final raw in decoded) {
            final release = Release.fromJson(raw as Map<String, dynamic>);
            await txn.insert(
              'releases',
              _releaseRow(release),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        } catch (_) {
          // Le cache peut être reconstruit depuis Metron.
        }
      }
      if (oldRefresh != null) {
        await txn.insert(
          'metadata',
          {'key': _releaseUpdatedKey, 'value': oldRefresh},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await _prefs.setBool(_migrationKey, true);
  }

  Future<List<Comic>> loadComics() async {
    await initialize();
    final rows = await (await _db).query(
      'comics',
      orderBy: 'title COLLATE NOCASE, issue COLLATE NOCASE',
    );
    return rows.map(_comicFromRow).toList();
  }

  Future<void> upsertComic(Comic comic) async {
    await initialize();
    await (await _db).insert(
      'comics',
      _comicRow(comic),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteComic(String id) async {
    await initialize();
    await (await _db).delete('comics', where: 'id = ?', whereArgs: [id]);
  }

  Future<({String username, String password})> credentials() async => (
        username: await _secure.read(key: 'metron_username') ?? '',
        password: await _secure.read(key: 'metron_password') ?? '',
      );

  Future<void> saveCredentials(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      await _secure.delete(key: 'metron_username');
      await _secure.delete(key: 'metron_password');
      return;
    }
    await _secure.write(key: 'metron_username', value: username);
    await _secure.write(key: 'metron_password', value: password);
  }

  Future<List<Release>> cachedReleases() async {
    await initialize();
    final rows = await (await _db).query('releases', orderBy: 'release_date');
    return rows.map(_releaseFromRow).toList();
  }

  Future<DateTime?> lastRefresh() async {
    await initialize();
    final rows = await (await _db).query(
      'metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_releaseUpdatedKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['value'] as String);
  }

  Future<void> cacheReleases(List<Release> releases) async {
    await initialize();
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('releases');
      for (final release in releases) {
        await txn.insert(
          'releases',
          _releaseRow(release),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.insert(
        'metadata',
        {'key': _releaseUpdatedKey, 'value': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }

  Map<String, Object?> _comicRow(Comic comic) => {
        'id': comic.id,
        'title': comic.title,
        'publisher': comic.publisher.name,
        'status': comic.status.name,
        'issue': comic.issue,
        'year': comic.year,
        'rating': comic.rating,
        'notes': comic.notes,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

  Comic _comicFromRow(Map<String, Object?> row) => Comic(
        id: row['id'] as String,
        title: row['title'] as String,
        publisher: Publisher.values.firstWhere(
          (value) => value.name == row['publisher'],
          orElse: () => Publisher.marvel,
        ),
        status: ReadingStatus.values.firstWhere(
          (value) => value.name == row['status'],
          orElse: () => ReadingStatus.toRead,
        ),
        issue: row['issue'] as String? ?? '',
        year: row['year'] as String? ?? '',
        rating: (row['rating'] as num?)?.toInt() ?? 0,
        notes: row['notes'] as String? ?? '',
      );

  Map<String, Object?> _releaseRow(Release release) => {
        'id': release.id,
        'title': release.title,
        'publisher': release.publisher.name,
        'release_date': release.date.toIso8601String(),
        'issue': release.issue,
        'image': release.image,
      };

  Release _releaseFromRow(Map<String, Object?> row) => Release(
        id: (row['id'] as num).toInt(),
        title: row['title'] as String,
        publisher: Publisher.values.firstWhere(
          (value) => value.name == row['publisher'],
          orElse: () => Publisher.marvel,
        ),
        date: DateTime.parse(row['release_date'] as String),
        issue: row['issue'] as String? ?? '',
        image: row['image'] as String? ?? '',
      );
}
