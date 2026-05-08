import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/music_provider.dart';
import '../models/song.dart';

/// 本地音乐页面 - 选择并播放本地音频文件
class LocalMusicPage extends StatelessWidget {
  const LocalMusicPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '选择本地音频文件播放',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () => _pickFiles(context),
            icon: const Icon(Icons.add),
            label: const Text('选择文件'),
          ),
          const SizedBox(height: 12),
          Text(
            '支持 MP3 / FLAC / WAV / AAC / OGG',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'flac', 'wav', 'aac', 'ogg', 'm4a', 'opus'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      final songs = result.files.map((f) {
        final name = f.name;
        // 去除扩展名，标题取文件名
        final ext = name.contains('.') ? name.substring(name.lastIndexOf('.')) : '';
        final title = name.replaceAll(ext, '');
        return Song(
          id: f.path ?? name,
          name: title,
          artist: '本地音乐',
          source: 'local',
          urlId: f.path,
        );
      }).toList();

      if (context.mounted) {
        context.read<MusicProvider>().playFromList(songs, startIndex: 0);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }
}
