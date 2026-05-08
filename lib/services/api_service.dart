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

  /// 获取真实的专辑封面 CDN URL（从代理 JSON 中提取）
  /// 用于通知栏/锁屏显示的封面
  Future<String?> fetchAlbumArtRealUrl(Song song, {int size = 300}) async {
    try {
      final proxyUrl = getAlbumArtUrl(song, size: size);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse(proxyUrl));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      client.close();
      if (body.isEmpty) return null;
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['url'] is String) return decoded['url'] as String;
    } catch (_) {}
    return null;
  }

  /// 通过 Dio 下载专辑封面图片字节流
  /// 先通过代理获取真实 URL，再用 Dio 下载图片，绕过 Image.network 的限制
  /// 下载专辑封面图片字节
  /// 从代理获取真实 URL，然后通过代理下载（绕过手机无法直接访问 CDN 的问题）
  Future<Uint8List?> fetchAlbumArtBytes(Song song, {int size = 300}) async {
    // 方法A: 直接用后端代理获取图片（不走 CDN）
    // 后端 /proxy?types=pic 返回 JSON: {"url":"https://cdn..."}
    // 但我们也可以在 id 中用 pic_id，让后端代理来下载
    final picId = song.picId ?? song.id;
    final proxyUrl = '${ApiConfig.baseUrl}${ApiConfig.proxyPath}'
        '?types=pic&id=$picId&source=${song.source}'
        '&size=$size&s=${DateTime.now().millisecondsSinceEpoch}';

    // 读代理返回的 JSON 获取真实 URL
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(proxyUrl));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      client.close();

      if (body.isEmpty) return null;

      String? realUrl;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['url'] is String) realUrl = decoded['url'] as String;
      } catch (_) {
        if (body.startsWith('http')) realUrl = body;
      }
      if (realUrl == null || realUrl.isEmpty) return null;

      // 方法B: 通过代理下载图片，不走 CDN 直连
      // 构造代理图片下载 URL: types=pic_download 或直接通过代理抓取
      // 最简单：改为用 Dio 下载（Dio 用 OkHttp，网络栈不同）
      try {
        final imgResp = await _dio.get(
          realUrl,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 20),
          ),
        );
        if (imgResp.statusCode == 200 && imgResp.data is Uint8List) {
          final bytes = imgResp.data as Uint8List;
          if (bytes.isNotEmpty) return bytes;
        }
      } catch (e) {
        print('[ArtFetch] Dio download failed: $e');
      }

      // 方法C: 尝试用 HttpClient 绕过 SSL 验证下载
      try {
        final imgClient = HttpClient()
          ..connectionTimeout = const Duration(seconds: 20)
          ..badCertificateCallback = (cert, host, port) => true; // 绕过 SSL 证书验证
        final imgReq = await imgClient.getUrl(Uri.parse(realUrl));
        imgReq.headers.set('User-Agent', 'Mozilla/5.0');
        final imgResp = await imgReq.close();
        imgClient.close();

        if (imgResp.statusCode == 200) {
          final bytes = await imgResp.fold<Uint8List>(
            Uint8List(0),
            (prev, chunk) {
              final c = chunk as List<int>;
              final result = Uint8List(prev.length + c.length);
              result.setRange(0, prev.length, prev);
              result.setRange(prev.length, result.length, c);
              return result;
            },
          );
          if (bytes.isNotEmpty) return bytes;
        }
      } catch (e) {
        print('[ArtFetch] SSL-bypass download failed: $e');
      }
    } catch (e) {
      print('[ArtFetch] proxy request failed: $e');
      rethrow; // 让 provider 显示错误
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
