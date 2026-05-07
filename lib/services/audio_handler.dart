import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../config/api_config.dart';
import '../models/song.dart';

/// AudioService 后台音频处理器
///
/// 职责：
/// - 后台播放（锁屏后继续播放）
/// - 锁屏控制（播放/暂停/切歌/专辑封面）
/// - 通知栏控制
class SolaraAudioHandler extends BaseAudioHandler with SeekHandler {
  AudioPlayer? _player;
  bool _playerReady = false;
  final HttpClient _httpClient = HttpClient();

  List<Song> _songs = [];
  int _currentQuality = ApiConfig.defaultQuality;

  SolaraAudioHandler() {
    try {
      _player = AudioPlayer();
      _setupListeners();
      _playerReady = true;
    } catch (_) {}
  }

  void _setupListeners() {
    // 位置更新
    _player?.positionStream.listen((pos) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: pos,
      ));
    });

    // 时长更新
    _player?.durationStream.listen((dur) {
      if (dur != null && mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: dur));
      }
    });

    // 播放状态
    _player?.playerStateStream.listen((state) {
      // 播放完成自动下一首
      if (state.processingState == AudioProcessingState.completed) {
        _next();
      }

      playbackState.add(playbackState.value.copyWith(
        playing: state.playing,
        processingState: _mapProcessing(state.processingState),
        controls: [
          MediaControl.skipToPrevious,
          state.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
      ));
    });

    // 序列状态更新
    _player?.sequenceStateStream.listen((seq) {
      if (seq?.currentSource != null) {
        final idx = seq!.currentIndex;
        if (idx != null && idx < _songs.length) {
          _updateMediaItem(_songs[idx]);
        }
      }
    });
  }

  // ===== 外部接口 =====

  /// 加载并播放列表
  Future<void> loadQueue(List<Song> songs, {int startIndex = 0}) async {
    _songs = List.from(songs);
    queue.add(songs.map(_toMediaItem).toList());
    await _playAt(startIndex.clamp(0, songs.length - 1));
  }

  /// 设置音质
  set quality(int q) => _currentQuality = q;

  /// 当前播放索引
  int get currentIndex => _player?.currentIndex ?? 0;

  /// 当前歌曲
  Song? get currentSong =>
      _player?.currentIndex != null && _player?.currentIndex! < _songs.length
          ? _songs[_player?.currentIndex!]
          : null;

  /// 对外暴露 player 流（供 UI 绑定）
  Stream<PlayerState> get playerStateStream => _player?.playerStateStream;
  Stream<Duration> get positionStream => _player?.positionStream;
  Stream<Duration?> get durationStream => _player?.durationStream;

  // ===== AudioService 接口实现 =====

  @override
  Future<void> play() => _player?.play();

  @override
  Future<void> pause() => _player?.pause();

  @override
  Future<void> seek(Duration position) => _player?.seek(position);

  @override
  Future<void> skipToNext() => _next();

  @override
  Future<void> skipToPrevious() => _prev();

  @override
  Future<void> stop() async {
    await _player?.stop();
    await _player?.dispose();
    _httpClient.close(force: true);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    _player?.setLoopMode(_toLoopMode(mode));
    super.setRepeatMode(mode);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    // 暂不支持
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    // 暂不支持
  }

  // ===== 内部方法 =====

  /// 播放指定索引（获取音频 URL 并播放）
  Future<void> _playAt(int index) async {
    if (index < 0 || index >= _songs.length) return;

    final song = _songs[index];
    _updateMediaItem(song);

    try {
      final audioUrl = await _fetchAudioUrl(song);
      if (audioUrl == null) {
        await _next();
        return;
      }

      await _player?.setAudioSource(
        AudioSource.uri(Uri.parse(audioUrl)),
        preload: true,
      );
      await _player?.seek(Duration.zero);
      await _player?.play();
    } catch (_) {
      // 播放失败，跳过
      await _next();
    }
  }

  Future<void> _next() async {
    final next = (_player?.currentIndex ?? 0) + 1;
    if (next < _songs.length) {
      await _playAt(next);
    } else {
      await _player?.pause();
      await _player?.seek(Duration.zero);
    }
  }

  Future<void> _prev() async {
    final prev = (_player?.currentIndex ?? 1) - 1;
    if (prev >= 0) {
      await _playAt(prev);
    } else {
      await _player?.seek(Duration.zero);
    }
  }

  /// 通过 Solara 后端获取音频播放地址
  Future<String?> _fetchAudioUrl(Song song) async {
    final sig = DateTime.now().millisecondsSinceEpoch.toString();
    final url =
        '${ApiConfig.baseUrl}${ApiConfig.proxyPath}'
        '?types=url'
        '&id=${song.urlId ?? song.id}'
        '&source=${song.source}'
        '&br=$_currentQuality'
        '&s=$sig';

    try {
      final uri = Uri.parse(url);
      final request = await _httpClient.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      final trimmed = body.trim();
      // 可能是直接返回 URL 字符串
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
      // JSON 中提取
      try {
        final json = jsonDecode(trimmed);
        if (json is Map) {
          if (json['url'] is String) return json['url'] as String;
          if (json['data'] is Map && json['data']['url'] is String) {
            return json['data']['url'] as String;
          }
        }
      } catch (_) {}
      return null;
    } catch (_) {
      return null;
    }
  }

  void _updateMediaItem(Song song) {
    final item = _toMediaItem(song);
    mediaItem.add(item);
  }

  MediaItem _toMediaItem(Song song) {
    final sig = DateTime.now().millisecondsSinceEpoch.toString();
    final picUrl =
        '${ApiConfig.baseUrl}${ApiConfig.proxyPath}'
        '?types=pic'
        '&id=${song.picId ?? song.id}'
        '&source=${song.source}'
        '&size=300'
        '&s=$sig';

    return MediaItem(
      id: song.id,
      title: song.name,
      artist: song.artist,
      album: song.album,
      artUri: Uri.parse(picUrl),
      extras: {
        'source': song.source,
      },
    );
  }

  AudioProcessingState _mapProcessing(ProcessingState s) {
    switch (s) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  LoopMode _toLoopMode(AudioServiceRepeatMode m) {
    switch (m) {
      case AudioServiceRepeatMode.none:
        return LoopMode.off;
      case AudioServiceRepeatMode.one:
        return LoopMode.one;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        return LoopMode.all;
    }
  }
}
