import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/api_config.dart';
import '../providers/music_provider.dart';
import '../services/api_service.dart';
import '../widgets/lyrics_display.dart';

/// 全屏播放器页面
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, _) {
        final song = provider.currentSong;
        if (song == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('没有正在播放的歌曲')),
          );
        }

        final api = ApiService();
        final artUrl = api.getAlbumArtUrl(song);
        final isFavorite = provider.isFavorite(song.id);

        // 简易分页：封面页 / 歌词页
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                children: [
                  Text(
                    song.name,
                    style: const TextStyle(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.redAccent : null,
                  ),
                  onPressed: () => provider.toggleFavorite(song),
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.album), text: '封面'),
                  Tab(icon: Icon(Icons.lyrics_outlined), text: '歌词'),
                ],
                labelStyle: TextStyle(fontSize: 13),
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: TabBarView(
                    children: [
                      // 封面页
                      _AlbumArtPage(artUrl: artUrl, songName: song.name),
                      // 歌词页
                      LyricsDisplay(
                        lyricText: provider.lyricText,
                        position: provider.position,
                        fullScreen: true,
                      ),
                    ],
                  ),
                ),

                // 底部控制栏
                _PlayerControls(provider: provider),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 专辑封面页
class _AlbumArtPage extends StatelessWidget {
  final String artUrl;
  final String songName;

  const _AlbumArtPage({
    required this.artUrl,
    required this.songName,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Hero(
            tag: 'album-art-${artUrl.hashCode}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: artUrl,
                width: MediaQuery.of(context).size.width * 0.65,
                height: MediaQuery.of(context).size.width * 0.65,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.music_note, size: 80),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.music_note, size: 80),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            songName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 播放控制栏
class _PlayerControls extends StatelessWidget {
  final MusicProvider provider;

  const _PlayerControls({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: provider.duration != null && provider.duration!.inMilliseconds > 0
                  ? provider.position.inMilliseconds /
                      provider.duration!.inMilliseconds
                  : 0,
              onChanged: (v) {
                if (provider.duration != null) {
                  provider.setPosition(
                    Duration(milliseconds: (v * provider.duration!.inMilliseconds).round()),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _fmt(provider.position),
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  _fmt(provider.duration ?? Duration.zero),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 音质选择
              PopupMenuButton<int>(
                initialValue: provider.quality,
                onSelected: provider.setQuality,
                itemBuilder: (_) => ApiConfig.qualityOptions.entries.map((e) {
                  return PopupMenuItem(
                    value: e.key,
                    child: Row(
                      children: [
                        if (e.key == provider.quality)
                          Icon(Icons.check,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(e.value),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hq, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${provider.quality}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              ),

              // 上一首
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 32),
                onPressed: provider.playPrevious,
              ),

              // 播放/暂停
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: IconButton(
                  icon: Icon(
                    provider.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 36,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: provider.togglePlayPause,
                ),
              ),

              // 下一首
              IconButton(
                icon: const Icon(Icons.skip_next, size: 32),
                onPressed: provider.onPlaybackComplete,
              ),

              // 播放模式（占位）
              IconButton(
                icon: const Icon(Icons.repeat, size: 20),
                onPressed: () {
                  // TODO: 切换播放模式
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
