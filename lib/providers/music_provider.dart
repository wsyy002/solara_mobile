import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audio_service/audio_service.dart';

import '../config/api_config.dart';
import '../services/audio_handler.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// 音乐播放器核心状态
class MusicProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  // ======== 搜索状态 ========
  bool _isSearching = false;
  String _searchKeyword = '';
  String _searchSource = ApiConfig.defaultSource;
  List<Song> _searchResults = [];
  int _searchPage = 1;
  bool _hasMoreResults = false;
  String? _searchError;

  bool get isSearching => _isSearching;
  String get searchKeyword => _searchKeyword;
  String get searchSource => _searchSource;
  List<Song> get searchResults => _searchResults;
  int get searchPage => _searchPage;
  bool get hasMoreResults => _hasMoreResults;
  String? get searchError => _searchError;

  // ======== 播放器状态 ========
  List<Song> _playlist = [];
  int _currentIndex = -1;
  Song? _currentSong;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  int _quality = ApiConfig.defaultQuality;
  String? _lyricText;

  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration? get duration => _duration;
  int get quality => _quality;
  String? get lyricText => _lyricText;

  // ======== 收藏 ========
  List<Song> _favorites = [];
  Set<String> _favoriteIds = {};

  List<Song> get favorites => _favorites;
  bool isFavorite(String id) => _favoriteIds.contains(id);

  // ======== 初始化 ========
  Future<void> init() async {
    await _storage.init();
    await loadFavorites();

    // 恢复上次播放状态
    final prefs = await SharedPreferences.getInstance();
    final savedSource = prefs.getString('search_source');
    if (savedSource != null) _searchSource = savedSource;
  }

  // ======== 搜索 ========
  Future<void> search({
    required String keyword,
    String? source,
    bool refresh = true,
  }) async {
    if (keyword.trim().isEmpty) return;

    _searchKeyword = keyword.trim();
    if (source != null) _searchSource = source;
    if (refresh) {
      _searchPage = 1;
      _searchResults = [];
      _hasMoreResults = false;
    }
    _searchError = null;
    _isSearching = true;
    notifyListeners();

    try {
      final results = await _api.search(
        keyword: _searchKeyword,
        source: _searchSource,
        page: _searchPage,
      );
      if (refresh) {
        _searchResults = results;
      } else {
        _searchResults.addAll(results);
      }
      _hasMoreResults = results.length >= ApiConfig.searchPageSize;
    } catch (e) {
      _searchError = e.toString().replaceAll('Exception: ', '');
    }

    _isSearching = false;
    notifyListeners();
  }

  /// 加载更多搜索结果
  Future<void> loadMoreResults() async {
    if (!_hasMoreResults || _isSearching) return;
    _searchPage++;
    await search(
      keyword: _searchKeyword,
      refresh: false,
    );
  }

  /// 切换搜索源
  Future<void> setSearchSource(String source) async {
    _searchSource = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('search_source', source);

    // 如果有搜索关键词，立即重新搜索
    if (_searchKeyword.isNotEmpty) {
      await search(keyword: _searchKeyword, refresh: true);
    } else {
      notifyListeners();
    }
  }

  // ======== 播放列表 ========
  /// 设置播放列表并开始播放
  void playFromList(List<Song> songs, {int startIndex = 0}) {
    if (songs.isEmpty) return;
    _playlist = List.from(songs);
    _currentIndex = startIndex.clamp(0, songs.length - 1);
    _currentSong = _playlist[_currentIndex];
    _isPlaying = true;

    notifyListeners();
    _fetchLyric();

    // 通知 AudioHandler 播放
    _notifyAudioServicePlay();
  }

  /// 从搜索结果播放：只把点击的这首歌追加到列表末尾
  void playFromSearch(List<Song> songs, {int startIndex = 0}) {
    if (songs.isEmpty) return;
    final song = songs[startIndex];
    if (_playlist.isEmpty) {
      _playlist = [song];
    } else {
      // 只追加点击的这一首
      _playlist.add(song);
    }
    _currentIndex = _playlist.length - 1;
    _currentSong = _playlist[_currentIndex];
    _isPlaying = true;
    _notifyAudioServicePlay();
    notifyListeners();
    _fetchLyric();
  }

  /// 将单首歌追加到播放列表末尾
  void addToPlaylist(List<Song> songs) {
    _playlist.addAll(songs);
    notifyListeners();
  }

  /// 清空播放列表
  void clearPlaylist() {
    _playlist = [];
    _currentIndex = -1;
    _currentSong = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = null;
    _lyricText = null;
    notifyListeners();
  }

  /// 移除播放列表中某首歌
  void removeFromPlaylist(int index) {
    if (index < 0 || index >= _playlist.length) return;
    _playlist.removeAt(index);
    if (_currentIndex >= index) {
      _currentIndex--;
    }
    if (_playlist.isEmpty) {
      _currentIndex = -1;
      _currentSong = null;
      _isPlaying = false;
    }
    notifyListeners();
  }

  /// 当前播放完成 → 下一首
  void onPlaybackComplete() {
    if (_currentIndex < _playlist.length - 1) {
      playFromList(_playlist, startIndex: _currentIndex + 1);
    } else {
      _isPlaying = false;
      _position = Duration.zero;
      notifyListeners();
    }
  }

  /// 上一首
  void playPrevious() {
    if (_playlist.isEmpty) return;
    final prev = (_currentIndex - 1).clamp(0, _playlist.length - 1);
    playFromList(_playlist, startIndex: prev);
  }

  /// 切换播放/暂停
  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void setPosition(Duration pos) {
    _position = pos;
  }

  void setDuration(Duration? dur) {
    _duration = dur;
  }

  void setPlaying(bool playing) {
    _isPlaying = playing;
    notifyListeners();
  }

  /// 设置音质
  void setQuality(int quality) {
    _quality = quality;
    notifyListeners();
  }

  // ======== 收藏 ========
  Future<void> loadFavorites() async {
    _favorites = await _storage.getFavorites();
    _favoriteIds = _favorites.map((s) => s.id).toSet();
    notifyListeners();
  }

  Future<void> toggleFavorite(Song song) async {
    if (_favoriteIds.contains(song.id)) {
      await _storage.removeFavorite(song.id);
      _favoriteIds.remove(song.id);
      _favorites.removeWhere((s) => s.id == song.id);
    } else {
      await _storage.addFavorite(song);
      _favoriteIds.add(song.id);
      _favorites.insert(0, song);
    }
    notifyListeners();
  }

  Future<void> removeFavorite(String songId) async {
    await _storage.removeFavorite(songId);
    _favoriteIds.remove(songId);
    _favorites.removeWhere((s) => s.id == songId);
    notifyListeners();
  }

  // ======== 歌词 ========
  Future<void> _fetchLyric() async {
    if (_currentSong == null) return;
    _lyricText = null;
    notifyListeners();

    try {
      _lyricText = await _api.getLyric(_currentSong!);
    } catch (_) {
      _lyricText = null;
    }
    notifyListeners();
  }

  // ======== AudioHandler ========
  BaseAudioHandler? _audioHandler;

  /// 设置 AudioHandler（由 main.dart 注入）
  void setAudioHandler(BaseAudioHandler handler) {
    _audioHandler = handler;
  }

  /// 获取 AudioHandler
  BaseAudioHandler? get audioHandler => _audioHandler;

  // ======== 通知 AudioService ========
  void _notifyAudioServicePlay() {
    if (_audioHandler is SolaraAudioHandler) {
      (_audioHandler as SolaraAudioHandler).loadQueue(_playlist, startIndex: _currentIndex);
    }
  }
}
