/// 歌曲数据模型
class Song {
  final String id;
  final String name;
  final String artist;
  final String album;
  final String? picId;
  final String? urlId;
  final String? lyricId;
  final String source;

  Song({
    required this.id,
    required this.name,
    required this.artist,
    this.album = '',
    this.picId,
    this.urlId,
    this.lyricId,
    required this.source,
  });

  /// 从搜索 API 返回的 JSON 解析
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: (json['id'] ?? '').toString(),
      name: json['name'] ?? '未知歌曲',
      artist: json['artist'] ?? '未知艺术家',
      album: json['album'] ?? '',
      picId: json['pic_id']?.toString(),
      urlId: json['url_id']?.toString(),
      lyricId: json['lyric_id']?.toString(),
      source: json['source'] ?? 'netease',
    );
  }

  /// 序列化到 JSON（用于本地存储）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'album': album,
      'pic_id': picId,
      'url_id': urlId,
      'lyric_id': lyricId,
      'source': source,
    };
  }

  /// 显示标题（歌手 - 歌曲）
  String get displayName => '$artist - $name';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
