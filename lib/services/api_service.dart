import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/song.dart';

/// Solara 后端 API 服务
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.requestTimeout,
      receiveTimeout: ApiConfig.requestTimeout,
      headers: {
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      error: true,
    ));
  }

  /// 生成签名（与前端 JS 逻辑一致）
  String _generateSignature() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return '${random}_${random.hashCode}';
  }

  /// 搜索歌曲
  Future<List<Song>> search({
    required String keyword,
    String source = ApiConfig.defaultSource,
    int count = ApiConfig.searchPageSize,
    int page = 1,
  }) async {
    final params = {
      'types': 'search',
      'source': source,
      'name': keyword,
      'count': count.toString(),
      'pages': page.toString(),
      's': _generateSignature(),
    };

    final url = ApiConfig.proxyUrl(params);

    try {
      final response = await _dio.get(url);

      if (response.data is List) {
        return (response.data as List)
            .map((item) => Song.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取歌曲播放 URL
  Future<String> getSongUrl({
    required Song song,
    int quality = ApiConfig.defaultQuality,
  }) async {
    final params = {
      'types': 'url',
      'id': song.urlId ?? song.id,
      'source': song.source,
      'br': quality.toString(),
      's': _generateSignature(),
    };

    final url = ApiConfig.proxyUrl(params);

    try {
      final response = await _dio.get(url);
      if (response.data is String) {
        return response.data as String;
      }
      if (response.data is Map && (response.data as Map).containsKey('url')) {
        return (response.data as Map)['url'] as String;
      }
      throw Exception('无法解析播放地址');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取歌词
  Future<String?> getLyric(Song song) async {
    final params = {
      'types': 'lyric',
      'id': song.lyricId ?? song.id,
      'source': song.source,
      's': _generateSignature(),
    };

    final url = ApiConfig.proxyUrl(params);

    try {
      final response = await _dio.get(url);
      if (response.data is Map && (response.data as Map).containsKey('lrc')) {
        return (response.data as Map)['lrc']['lyric'] as String?;
      }
      if (response.data is Map && (response.data as Map).containsKey('lyric')) {
        return (response.data as Map)['lyric'] as String?;
      }
      return null;
    } on DioException {
      return null; // 歌词非必须，静默失败
    }
  }

  /// 获取专辑封面 URL
  String getAlbumArtUrl(Song song, {int size = 300}) {
    final params = {
      'types': 'pic',
      'id': song.picId ?? song.id,
      'source': song.source,
      'size': size.toString(),
      's': _generateSignature(),
    };
    return ApiConfig.proxyUrl(params);
  }

  /// 错误处理
  Exception _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('连接超时，请检查网络或NAS是否在线');
      case DioExceptionType.connectionError:
        return Exception('无法连接到NAS ($e.message)');
      default:
        return Exception('请求失败: ${e.message}');
    }
  }
}
