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

  // 初始化存储
  await StorageService().init();

  // 启动 AudioService（后台播放）— 带超时兜底
  dynamic audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => SolaraAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.solara.music.channel',
        androidNotificationChannelName: 'Solara 音乐',
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: musicProvider),
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
      title: 'Solara',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system, // 跟随系统深浅色
      home: const HomeScreen(),
    );
  }

  ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1), // indigo
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
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
    );
  }

  ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF818CF8),
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
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
    );
  }
}
