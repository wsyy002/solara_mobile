/// Solara 后端 API 配置
class ApiConfig {
  /// NAS 上 Solara 服务的地址（内网）
  static const String baseUrl = 'http://192.168.101.28:3001';

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

  /// 音质选项 (key: 码率, value: 显示名)
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

  /// 完整代理 URL
  static String proxyUrl(Map<String, String> params) {
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$baseUrl$proxyPath?$query';
  }
}
