import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/api_config.dart';
import '../models/song.dart';
import '../services/api_service.dart';

/// 歌曲列表项组件
class SongTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final api = ApiService();
    final artUrl = api.getAlbumArtUrl(song);

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: artUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.music_note,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.music_note,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      title: Text(
        song.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing ??
          (onFavoriteTap != null
              ? IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.redAccent : null,
                    size: 20,
                  ),
                  onPressed: onFavoriteTap,
                )
              : null),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
