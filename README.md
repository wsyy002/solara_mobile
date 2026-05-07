# Solara Mobile 🎵

Solara 音乐播放器的 Flutter 移动客户端。

## 架构

```
┌─────────────────────┐       HTTP/REST       ┌──────────────────┐
│   Solara Mobile     │ ──────────────────▶   │  Solara 后端      │
│   (Flutter App)     │ ◀──────────────────   │  (NAS:3001)       │
│                     │                       │                  │
│  - 搜索/播放         │                       │  - 代理音源API     │
│  - 收藏/歌单         │                       │  - 音频代理        │
│  - 后台播放          │                       │  - 状态持久化      │
│  - 锁屏控制/歌词      │                       │  - NAS下载         │
└─────────────────────┘                       └──────────────────┘
```

## 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0

## 快速开始

```bash
# 1. 克隆/复制项目后，安装依赖
cd solara_mobile
flutter pub get

# 2. 配置后端地址（默认连接 NAS 内网）
# 编辑 lib/config/api_config.dart 修改 baseUrl

# 3. 运行（需要连接一台 Android 设备或模拟器）
flutter run

# 4. 构建 APK
flutter build apk --release
```

## 构建 APK

```bash
# Release APK（输出在 build/app/outputs/flutter-apk/）
flutter build apk --release

# 如果你要指定输出路径（如推送到 NAS 共享目录）
cp build/app/outputs/flutter-apk/app-release.apk /vol1/1000/VM/solara-mobile.apk
```

## 项目结构

```
solara_mobile/
├── lib/
│   ├── main.dart                  # 入口 + AudioService 初始化
│   ├── config/
│   │   └── api_config.dart        # 后端地址、音源配置
│   ├── models/
│   │   └── song.dart              # 歌曲数据模型
│   ├── services/
│   │   ├── api_service.dart       # HTTP API 客户端
│   │   ├── audio_handler.dart     # 后台音频处理器
│   │   └── storage_service.dart   # SQLite + SharedPreferences
│   ├── providers/
│   │   └── music_provider.dart    # 核心状态管理
│   ├── screens/
│   │   ├── home_screen.dart       # 主页（底部导航）
│   │   ├── search_screen.dart     # 搜索界面
│   │   ├── player_screen.dart     # 全屏播放器
│   │   └── playlist_screen.dart   # 播放列表
│   └── widgets/
│       ├── song_tile.dart         # 歌曲列表项
│       └── lyrics_display.dart    # 歌词展示组件
```

## 功能清单

- [x] 多源搜索（网易云、酷狗、酷我、咪咕、B站）
- [x] 多音质选择（128k/192k/320k/无损）
- [x] 播放/暂停/上一首/下一首
- [x] 专辑封面展示
- [x] 歌词展示（支持时间轴高亮）
- [x] 收藏管理
- [x] 播放列表管理
- [x] 深色/浅色主题跟随系统
- [x] 后台播放
- [x] 锁屏控制（MediaSession）
- [ ] 歌单导入/导出
- [ ] EQ均衡器
- [ ] 下载到本地/NAS
- [x] 搜索历史
- [ ] 歌单发现/推荐

## 依赖

| 包 | 用途 |
|---|---|
| dio | HTTP 请求 |
| provider | 状态管理 |
| just_audio | 音频播放 |
| audio_service | 后台播放/锁屏控制 |
| cached_network_image | 封面图片缓存 |
| sqflite | 本地数据库（收藏/歌单） |
| shared_preferences | 简单配置存储 |
