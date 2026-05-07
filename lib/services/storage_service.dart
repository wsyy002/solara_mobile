import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/song.dart';

/// 本地持久化服务
/// 使用 SharedPreferences 存简单配置 + SQLite 存歌单/收藏
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;

  Database? _db;
  SharedPreferences? _prefs;

  StorageService._internal();

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      p.join(dir.path, 'solara.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS playlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            songs TEXT NOT NULL,
            created_at INTEGER DEFAULT (strftime('%s','now')),
            updated_at INTEGER DEFAULT (strftime('%s','now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS favorites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            song_id TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            artist TEXT,
            album TEXT,
            pic_id TEXT,
            url_id TEXT,
            lyric_id TEXT,
            source TEXT DEFAULT 'netease',
            added_at INTEGER DEFAULT (strftime('%s','now'))
          )
        ''');
        // 默认播放列表
        await db.insert('playlists', {
          'name': '默认播放列表',
          'songs': '[]',
        });
      },
    );
  }

  // ======== 配置 ========

  String? getString(String key) => _prefs?.getString(key);
  int getInt(String key, {int defaultValue = 0}) =>
      _prefs?.getInt(key) ?? defaultValue;
  bool getBool(String key, {bool defaultValue = false}) =>
      _prefs?.getBool(key) ?? defaultValue;

  Future<void> setString(String key, String value) =>
      _prefs?.setString(key, value) ?? Future.value();
  Future<void> setInt(String key, int value) =>
      _prefs?.setInt(key, value) ?? Future.value();
  Future<void> setBool(String key, bool value) =>
      _prefs?.setBool(key, value) ?? Future.value();

  // ======== 收藏 ========

  /// 获取所有收藏歌曲
  Future<List<Song>> getFavorites() async {
    if (_db == null) return [];
    final rows = await _db!.query('favorites', orderBy: 'added_at DESC');
    return rows.map((r) => Song(
      id: r['song_id'] as String,
      name: r['name'] as String,
      artist: (r['artist'] as String?) ?? '',
      album: (r['album'] as String?) ?? '',
      picId: r['pic_id'] as String?,
      urlId: r['url_id'] as String?,
      lyricId: r['lyric_id'] as String?,
      source: (r['source'] as String?) ?? 'netease',
    )).toList();
  }

  /// 添加收藏
  Future<void> addFavorite(Song song) async {
    if (_db == null) return;
    await _db!.insert('favorites', {
      'song_id': song.id,
      'name': song.name,
      'artist': song.artist,
      'album': song.album,
      'pic_id': song.picId,
      'url_id': song.urlId,
      'lyric_id': song.lyricId,
      'source': song.source,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// 移除收藏
  Future<void> removeFavorite(String songId) async {
    if (_db == null) return;
    await _db!.delete('favorites', where: 'song_id = ?', whereArgs: [songId]);
  }

  /// 检查是否已收藏
  Future<bool> isFavorite(String songId) async {
    if (_db == null) return false;
    final rows = await _db!.query(
      'favorites',
      where: 'song_id = ?',
      whereArgs: [songId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ======== 播放列表 ========

  /// 获取所有播放列表
  Future<List<Map<String, dynamic>>> getPlaylists() async {
    if (_db == null) return [];
    return await _db!.query('playlists', orderBy: 'updated_at DESC');
  }

  /// 获取播放列表中的歌曲
  Future<List<Song>> getPlaylistSongs(int playlistId) async {
    if (_db == null) return [];
    final rows = await _db!.query(
      'playlists',
      where: 'id = ?',
      whereArgs: [playlistId],
      limit: 1,
    );
    if (rows.isEmpty) return [];
    final songsJson = rows.first['songs'] as String? ?? '[]';
    final list = jsonDecode(songsJson) as List;
    return list.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 保存播放列表
  Future<void> savePlaylistSongs(int playlistId, List<Song> songs) async {
    if (_db == null) return;
    await _db!.update(
      'playlists',
      {
        'songs': jsonEncode(songs.map((s) => s.toJson()).toList()),
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }
}
