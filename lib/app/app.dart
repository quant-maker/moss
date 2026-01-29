import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routes.dart';
import '../core/theme/theme_provider.dart';

class MossApp extends ConsumerWidget {
  const MossApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeState = ref.watch(themeProvider);
    
    return MaterialApp.router(
      title: 'Moss - 智能管家',
      debugShowCheckedModeBanner: false,
      theme: getLightTheme(themeState.seedColor),
      darkTheme: getDarkTheme(themeState.seedColor),
      themeMode: themeState.themeMode,
      routerConfig: router,
    );
  }
}
