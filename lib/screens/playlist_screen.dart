import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/music_provider.dart';
import '../widgets/song_tile.dart';

/// 播放列表面板（可作为独立页面或底部弹出面板）
class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, _) {
        if (provider.playlist.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('播放列表')),
            body: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.queue_music_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '播放列表为空',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '搜索歌曲后点击播放即可添加到列表',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('播放列表 (${provider.playlist.length})'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: provider.playlist.isNotEmpty
                    ? () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('清空播放列表'),
                            content: const Text('确定要清空播放列表吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  provider.clearPlaylist();
                                  Navigator.pop(ctx);
                                },
                                child: const Text('确定', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        );
                      }
                    : null,
              ),
            ],
          ),
          body: ReorderableListView.builder(
            itemCount: provider.playlist.length,
            onReorder: (oldIndex, newIndex) {
              // TODO: 拖动排序
            },
            itemBuilder: (context, index) {
              final song = provider.playlist[index];
              final isCurrent = index == provider.currentIndex;

              return SongTile(
                key: ValueKey('playlist-${song.id}-$index'),
                song: song,
                isFavorite: provider.isFavorite(song.id),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCurrent)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => provider.removeFromPlaylist(index),
                    ),
                  ],
                ),
                onTap: () => provider.playFromList(provider.playlist, startIndex: index),
                onFavoriteTap: () => provider.toggleFavorite(song),
              );
            },
          ),
        );
      },
    );
  }
}
