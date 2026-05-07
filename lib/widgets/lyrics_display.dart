import 'package:flutter/material.dart';

/// 歌词显示组件
class LyricsDisplay extends StatelessWidget {
  final String? lyricText;
  final Duration position;
  final bool fullScreen;

  const LyricsDisplay({
    super.key,
    this.lyricText,
    this.position = Duration.zero,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (lyricText == null || lyricText!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              '暂无歌词',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                fontSize: fullScreen ? 16 : 14,
              ),
            ),
          ],
        ),
      );
    }

    // 简单逐行显示（不处理时间戳）
    final lines = lyricText!
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    // 解析时间标签
    final parsedLines = <_LyricLine>[];
    for (final line in lines) {
      final match = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$')
          .firstMatch(line.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millis = int.parse(match.group(3)!.padRight(3, '0').substring(0, 3));
        final text = match.group(4)?.trim() ?? '';
        if (text.isNotEmpty) {
          parsedLines.add(_LyricLine(
            time: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: millis,
            ),
            text: text,
          ));
        }
      } else if (line.trim().isNotEmpty && !line.trim().startsWith('[')) {
        parsedLines.add(_LyricLine(text: line.trim()));
      }
    }

    if (parsedLines.isEmpty) {
      // 没有时间标签，直接显示文本
      return _buildPlainText(context);
    }

    // 找到当前行
    int currentLine = 0;
    if (parsedLines.first.time != null) {
      for (int i = parsedLines.length - 1; i >= 0; i--) {
        if (parsedLines[i].time != null &&
            parsedLines[i].time! <= position) {
          currentLine = i;
          break;
        }
      }
    }

    return _buildTimedLyrics(context, parsedLines, currentLine);
  }

  Widget _buildPlainText(BuildContext context) {
    final fontSize = fullScreen ? 18.0 : 13.0;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: fullScreen ? 32 : 16,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: lyricText!
            .split('\n')
            .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('['))
            .map((line) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    line.trim(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildTimedLyrics(
    BuildContext context,
    List<_LyricLine> parsedLines,
    int currentLine,
  ) {
    final fontSize = fullScreen ? 18.0 : 13.0;
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: fullScreen ? 32 : 16,
        vertical: fullScreen ? 60 : 8,
      ),
      itemCount: parsedLines.length,
      itemBuilder: (context, index) {
        final isActive = index == currentLine;
        return AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: isActive ? fontSize + 2 : fontSize,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? activeColor : inactiveColor,
            height: fullScreen ? 2.0 : 1.6,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              parsedLines[index].text,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}

class _LyricLine {
  final Duration? time;
  final String text;
  _LyricLine({this.time, required this.text});
}
