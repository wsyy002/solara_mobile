import 'dart:convert';
import 'dart:io';
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
    final proxyUrl = getAlbumArtUrl(song, size: size);
    print('[AlbumArt] step1: $proxyUrl');

    // 1) 直接用 dart:io HttpClient 请求代理 URL
    try {
      final uri = Uri.parse(proxyUrl);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      print('[AlbumArt] step2: status=${response.statusCode} body.len=${body.length}');

      // 解析 JSON
      String? realUrl;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          if (decoded['url'] is String) {
            realUrl = decoded['url'] as String;
          }
        }
      } catch (_) {
        // 可能是直接返回 URL 字符串
        if (body.startsWith('http')) {
          realUrl = body;
        }
      }

      if (realUrl == null) {
        print('[AlbumArt] step3: no realUrl found, body=$body');
        return null;
      }

      print('[AlbumArt] step4: realUrl=$realUrl');

      // 2) 用 dart:io HttpClient 下载图片
      final imgClient = HttpClient();
      imgClient.connectionTimeout = const Duration(seconds: 15);
      final imgRequest = await imgClient.getUrl(Uri.parse(realUrl));
      final imgResponse = await imgRequest.close();

      if (imgResponse.statusCode == 200) {
        final bytes = await imgResponse.fold<Uint8List>(
          Uint8List(0),
          (prev, chunk) {
            final c = chunk as List<int>;
            final result = Uint8List(prev.length + c.length);
            result.setRange(0, prev.length, prev);
            result.setRange(prev.length, result.length, c);
            return result;
          },
        );
        imgClient.close();
        print('[AlbumArt] step5: downloaded ${bytes.length} bytes');
        return bytes;
      }
      imgClient.close();
      print('[AlbumArt] step3b: img status=${imgResponse.statusCode}');
    } catch (e) {
      print('[AlbumArt] error: $e');
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
