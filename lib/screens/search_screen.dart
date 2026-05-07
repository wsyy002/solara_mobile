import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../widgets/song_tile.dart';

/// 搜索界面
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showSourcePicker = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MusicProvider>();
      if (provider.searchKeyword.isNotEmpty) {
        _searchController.text = provider.searchKeyword;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<MusicProvider>().loadMoreResults();
    }
  }

  void _performSearch({bool refresh = true}) {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    final provider = context.read<MusicProvider>();
    provider.search(keyword: keyword, refresh: refresh);

    // 收起键盘
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索歌曲'),
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索歌曲、歌手或专辑...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _performSearch(),
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 8),
                // 搜索源选择
                _SourceChip(
                  label: ApiConfig.sources[
                          context.watch<MusicProvider>().searchSource] ??
                      '网易云',
                  onTap: () => setState(() => _showSourcePicker = !_showSourcePicker),
                ),
              ],
            ),
          ),

          // 源选择器
          if (_showSourcePicker) _buildSourcePicker(context),

          // 搜索结果
          Expanded(
            child: _buildResults(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePicker(BuildContext context) {
    final currentSource = context.watch<MusicProvider>().searchSource;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: ApiConfig.sources.entries.map((entry) {
          final isSelected = entry.key == currentSource;
          return ListTile(
            dense: true,
            leading: Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : null,
              size: 20,
            ),
            title: Text(
              entry.value,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            onTap: () {
              context.read<MusicProvider>().setSearchSource(entry.key);
              setState(() => _showSourcePicker = false);
              _performSearch(refresh: true);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final provider = context.watch<MusicProvider>();

    if (provider.isSearching && provider.searchResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                provider.searchError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => _performSearch(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.searchResults.isEmpty && provider.searchKeyword.isNotEmpty && !provider.isSearching) {
      return const Center(
        child: Text('未找到结果', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    if (provider.searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '输入关键词搜索音乐',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '支持网易云、酷狗、酷我、咪咕、B站',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: provider.searchResults.length + (provider.hasMoreResults ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= provider.searchResults.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final song = provider.searchResults[index];
        return SongTile(
          song: song,
          isFavorite: provider.isFavorite(song.id),
          onTap: () {
            provider.playFromSearch(provider.searchResults, startIndex: index);
          },
          onFavoriteTap: () => provider.toggleFavorite(song),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.play_circle_fill, size: 22),
                color: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  provider.playFromSearch(provider.searchResults, startIndex: index);
                },
              ),
              IconButton(
                icon: const Icon(Icons.playlist_add, size: 20),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                onPressed: () {
                  provider.addToPlaylist([song]);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已添加到播放列表'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 源选择 Chip
class _SourceChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SourceChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.expand_more,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
