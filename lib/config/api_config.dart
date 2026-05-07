import 'package:shared_preferences/shared_preferences.dart';

/// Solara 后端 API 配置（支持动态修改）
class ApiConfig {
  /// 默认地址
  static const String defaultBaseUrl = 'http://192.168.101.28:3001';

  /// 当前后端地址
  static String _baseUrl = defaultBaseUrl;

  /// 获取后端地址
  static String get baseUrl => _baseUrl;

  /// 代理 API 基础路径
  static const String proxyPath = '/proxy';

  /// 支持的音乐源
  static const Map<String, String> sources = {
    'netease': '网易云音乐',
    'kugou': '酷狗音乐',
    'kuwo': '酷我音乐',
    'migu': '咪咕音乐',
    'bilibili': 'B站',
  };

  /// 默认音乐源
  static const String defaultSource = 'netease';

  /// 音质选项
  static const Map<int, String> qualityOptions = {
    128: '标准音质 (128k)',
    192: '高音质 (192k)',
    320: '超高音质 (320k)',
    999: '无损音质',
  };

  /// 默认音质
  static const int defaultQuality = 320;

  /// 搜索每页数量
  static const int searchPageSize = 20;

  /// 超时时间
  static const Duration requestTimeout = Duration(seconds: 15);

  /// 从 SharedPreferences 加载保存的地址
  static Future<void> loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('backend_url');
    if (saved != null && saved.isNotEmpty) {
      _baseUrl = saved;
    }
  }

  /// 修改后端地址并保存
  static Future<void> setBaseUrl(String url) async {
    // 去掉末尾斜杠
    String clean = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    _baseUrl = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', clean);
  }

  /// 完整代理 URL
  static String proxyUrl(Map<String, String> params) {
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$baseUrl$proxyPath?$query';
  }
}
