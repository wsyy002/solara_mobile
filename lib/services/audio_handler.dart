import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../config/api_config.dart';
import '../models/song.dart';
import '../services/api_service.dart';

/// AudioService 后台音频处理器
///
/// 仅负责：
/// - 通知栏/锁屏控制（播放/暂停/切歌/封面）
/// - 媒体会话状态同步
///
/// 播放逻辑完全由 MusicProvider 管理
class SolaraAudioHandler extends BaseAudioHandler with SeekHandler {
  AudioPlayer? _player;
  bool _playerReady = false;

  List<Song> _songs = [];
  int _currentQuality = ApiConfig.defaultQuality;

  VoidCallback? _onNextPressed;
  VoidCallback? _onPrevPressed;
  VoidCallback? _onStopPressed;

  /// 设置通知栏按钮回调（由 MusicProvider 注入）
  void setCallbacks({
    VoidCallback? onNext,
    VoidCallback? onPrev,
    VoidCallback? onStop,
  }) {
    _onNextPressed = onNext;
    _onPrevPressed = onPrev;
    _onStopPressed = onStop;
  }

  /// 由 MusicProvider 注入共享的 AudioPlayer
  void setPlayer(AudioPlayer player) {
    if (_playerReady) return;
    _player = player;
    _playerReady = true;
    _setupListeners();
  }

  void _setupListeners() {
    // 位置更新 → 通知栏进度
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

    // 播放状态 → 更新通知栏按钮
    _player?.playerStateStream.listen((state) {
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
  }

  // ===== 外部接口 =====

  /// 设置播放列表中的歌曲（供 MusicProvider 调用）
  void setSongList(List<Song> songs) {
    _songs = List.from(songs);
    queue.add(songs.map(_toMediaItem).toList());
  }

  /// 更新当前播放的媒体信息（封面、歌名等）
  void updateCurrentMedia(Song song, {int index = 0}) {
    final item = _toMediaItem(song);
    mediaItem.add(item);
    // 异步更新真实封面 URL
    _updateArtUrl(song);
  }

  /// 设置音质
  set quality(int q) => _currentQuality = q;

  /// 当前播放索引
  int get currentIndex => _player?.currentIndex ?? 0;

  /// 当前歌曲
  Song? get currentSong =>
      _player?.currentIndex != null && (_player?.currentIndex ?? 0) < _songs.length
          ? _songs[_player?.currentIndex ?? 0]
          : null;

  /// 对外暴露 player 流（供 UI 绑定）
  Stream<PlayerState> get playerStateStream => _player?.playerStateStream ?? const Stream.empty();
  Stream<Duration> get positionStream => _player?.positionStream ?? const Stream.empty();
  Stream<Duration?> get durationStream => _player?.durationStream ?? const Stream<Duration?>.empty();

  // ===== AudioService 接口实现 =====

  @override
  Future<void> play() => _player?.play() ?? Future<void>.value();

  @override
  Future<void> pause() => _player?.pause() ?? Future<void>.value();

  @override
  Future<void> seek(Duration position) => _player?.seek(position) ?? Future<void>.value();

  @override
  Future<void> skipToNext() {
    _onNextPressed?.call();
    return Future<void>.value();
  }

  @override
  Future<void> skipToPrevious() {
    _onPrevPressed?.call();
    return Future<void>.value();
  }

  @override
  Future<void> stop() async {
    _onStopPressed?.call();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    super.setRepeatMode(mode);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {}

  @override
  Future<void> removeQueueItemAt(int index) async {}

  // ===== 内部方法 =====

  void _updateMediaItem(Song song) {
    _updateArtUrl(song);
    final item = _toMediaItem(song);
    mediaItem.add(item);
  }

  Future<void> _updateArtUrl(Song song) async {
    try {
      final realUrl = await ApiService().fetchAlbumArtRealUrl(song);
      if (realUrl != null && realUrl.isNotEmpty && mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(artUri: Uri.parse(realUrl)));
      }
    } catch (_) {}
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
        'pic_id': song.picId ?? song.id,
      },
    );
  }

  AudioProcessingState _mapProcessing(ProcessingState s) {
    switch (s) {
      case ProcessingState.idle: return AudioProcessingState.idle;
      case ProcessingState.loading: return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready: return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
    }
  }
}
