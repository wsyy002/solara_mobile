import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/api_config.dart';
import '../providers/music_provider.dart';
import '../services/api_service.dart';
import 'search_screen.dart';
import 'player_screen.dart';
import 'playlist_screen.dart';

/// 主页（底部导航结构）
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  final List<Widget> _pages = const [
    _NowPlayingPage(),
    _PlaylistPage(),
    _FavoritesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Solara',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '音乐',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            activeIcon: Icon(Icons.play_circle_filled),
            label: '正在播放',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.queue_music_outlined),
            activeIcon: Icon(Icons.queue_music),
            label: '播放列表',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: '收藏',
          ),
        ],
      ),
    );
  }
}

/// 正在播放页
class _NowPlayingPage extends StatelessWidget {
  const _NowPlayingPage();

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, _) {
        final song = provider.currentSong;
        if (song == null) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_note, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  '选择一首歌开始播放',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final api = ApiService();
        final artUrl = api.getAlbumArtUrl(song);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlayerScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                // 专辑封面
                Hero(
                  tag: 'album-art-${song.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: artUrl,
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: MediaQuery.of(context).size.width * 0.7,
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
                const SizedBox(height: 32),

                // 歌曲信息
                Text(
                  song.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  song.artist,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),

                // 进度条
                LinearProgressIndicator(
                  value: provider.duration != null && provider.duration!.inMilliseconds > 0
                      ? provider.position.inMilliseconds /
                          provider.duration!.inMilliseconds
                      : 0,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(provider.position),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      _formatDuration(provider.duration ?? Duration.zero),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 播放控制
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 36),
                      onPressed: provider.playPrevious,
                    ),
                    const SizedBox(width: 24),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: IconButton(
                        icon: Icon(
                          provider.isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 40,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        onPressed: provider.togglePlayPause,
                      ),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 36),
                      onPressed: provider.onPlaybackComplete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// 播放列表页（占位）
class _PlaylistPage extends StatelessWidget {
  const _PlaylistPage();

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, _) {
        if (provider.playlist.isEmpty) {
          return const Center(child: Text('播放列表为空'));
        }
        return ListView.builder(
          itemCount: provider.playlist.length,
          itemBuilder: (context, index) {
            final song = provider.playlist[index];
            final isCurrent = index == provider.currentIndex;
            return ListTile(
              leading: isCurrent
                  ? Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary)
                  : Text('${index + 1}', style: const TextStyle(fontSize: 14)),
              title: Text(
                song.name,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
              subtitle: Text(song.artist),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => provider.removeFromPlaylist(index),
              ),
              onTap: () => provider.playFromList(
                provider.playlist,
                startIndex: index,
              ),
            );
          },
        );
      },
    );
  }
}

/// 收藏页
class _FavoritesPage extends StatelessWidget {
  const _FavoritesPage();

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, _) {
        if (provider.favorites.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('还没有收藏歌曲', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: provider.favorites.length,
          itemBuilder: (context, index) {
            final song = provider.favorites[index];
            return ListTile(
              leading: Text('${index + 1}', style: const TextStyle(fontSize: 14)),
              title: Text(song.name),
              subtitle: Text(song.artist),
              trailing: IconButton(
                icon: Icon(
                  Icons.favorite,
                  color: Colors.redAccent.shade200,
                ),
                onPressed: () => provider.removeFavorite(song.id),
              ),
              onTap: () {
                provider.playFromList(provider.favorites, startIndex: index);
              },
            );
          },
        );
      },
    );
  }
}
