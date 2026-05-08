import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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

  /// 封面 URL 缓存
  static final Map<String, String> _artCache = {};

  /// 获取专辑封面 API 地址（返回 JSON）
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

  /// 获取专辑封面图片地址
  /// 返回代理 URL，让 Image.network 直接通过代理加载图片
  Future<String> fetchAlbumArtUrl(Song song, {int size = 300}) async {
    final key = '${song.id}_${song.source}_$size';
    if (_artCache.containsKey(key)) return _artCache[key]!;

    final url = getAlbumArtUrl(song, size: size);
    _artCache[key] = url;
    return url;
  }

  /// 通过 Dio 下载专辑封面图片字节流
  /// 先通过代理获取真实 URL，再用 Dio 下载图片，绕过 Image.network 的限制
  Future<Uint8List?> fetchAlbumArtBytes(Song song, {int size = 300}) async {
    try {
      // 1) 从代理获取真实图片 URL
      final proxyUrl = getAlbumArtUrl(song, size: size);
      final proxyResp = await _dio.get(proxyUrl);
      final data = proxyResp.data;

      String? realUrl;
      if (data is Map) {
        if (data['url'] is String) realUrl = data['url'] as String;
      } else if (data is String && data.startsWith('http')) {
        realUrl = data;
      }
      if (realUrl == null) return null;

      // 2) 下载实际图片
      final imgResp = await _dio.get(
        realUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (imgResp.statusCode == 200 && imgResp.data is Uint8List) {
        return imgResp.data as Uint8List;
      }
    } catch (e) {
      print('[AlbumArtBytes] fetch failed: $e');
    }
    return null;
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
