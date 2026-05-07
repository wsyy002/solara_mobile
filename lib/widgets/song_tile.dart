import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/api_service.dart';

/// 歌曲列表项组件（含异步封面加载）
class SongTile extends StatefulWidget {
  final Song song;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final Widget? trailing;

  const SongTile({
    super.key,
    required this.song,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteTap,
    this.trailing,
  });

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  String? _artUrl;
  bool _loadingArt = true;

  @override
  void initState() {
    super.initState();
    _loadArt();
  }

  Future<void> _loadArt() async {
    final url = await ApiService().fetchAlbumArtUrl(widget.song);
    if (mounted) {
      setState(() {
        _artUrl = url.isNotEmpty ? url : null;
        _loadingArt = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 48,
          height: 48,
          color: colorScheme.surfaceContainerHighest,
          child: _loadingArt
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : (_artUrl != null
                  ? Image.network(
                      _artUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.music_note,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : const Icon(Icons.music_note),
                    )
                  : Icon(
                      Icons.music_note,
                      color: colorScheme.onSurfaceVariant,
                    )),
        ),
      ),
      title: Text(
        widget.song.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Text(
        widget.song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: widget.trailing ??
          (widget.onFavoriteTap != null
              ? IconButton(
                  icon: Icon(
                    widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: widget.isFavorite ? Colors.redAccent : null,
                    size: 20,
                  ),
                  onPressed: widget.onFavoriteTap,
                )
              : null),
      onTap: widget.onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
