import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';

import 'config/api_config.dart';
import 'providers/music_provider.dart';
import 'services/storage_service.dart';
import 'services/audio_handler.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 状态栏沉浸
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // 加载保存的后端地址（带超时）
  try {
    await ApiConfig.loadSavedUrl().timeout(const Duration(seconds: 3));
  } catch (_) {}

  // 初始化存储（带超时）
  try {
    await StorageService().init().timeout(const Duration(seconds: 3));
  } catch (_) {}

  // 启动 AudioService（后台播放）— 带超时兜底
  dynamic audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => SolaraAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.solara.music.channel',
        androidNotificationChannelName: 'PureTune',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    ).timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('AudioService init failed: $e, continuing without background audio');
    audioHandler = null;
  }

  // 初始化 MusicProvider
  final musicProvider = MusicProvider();
  await musicProvider.init();

  // 如果 AudioHandler 可用，注入到 MusicProvider
  if (audioHandler != null) {
    musicProvider.setAudioHandler(audioHandler as BaseAudioHandler);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: musicProvider),
        if (audioHandler != null)
          Provider.value(value: audioHandler),
      ],
      child: const SolaraApp(),
    ),
  );
}

class SolaraApp extends StatelessWidget {
  const SolaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PureTune',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system, // 跟随系统深浅色
      home: const HomeScreen(),
    );
  }

  // PureTune 主题色 — 紫罗兰渐变
  static const Color _seedColor = Color(0xFF7C3AED); // vibrant purple

  ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        foregroundColor: colorScheme.onSurface,
        backgroundColor: colorScheme.surface,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        foregroundColor: colorScheme.onSurface,
        backgroundColor: colorScheme.surface,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
