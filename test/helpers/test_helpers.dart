import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

/// 测试用临时目录
late Directory tempDir;

/// 初始化测试环境
Future<void> initializeTestEnvironment() async {
  // 创建临时目录用于 Hive
  tempDir = await Directory.systemTemp.createTemp('moss_test_');
  Hive.init(tempDir.path);
}

/// 清理测试环境
Future<void> cleanupTestEnvironment() async {
  await Hive.close();
  if (tempDir.existsSync()) {
    await tempDir.delete(recursive: true);
  }
}

/// 创建测试用 ProviderScope 包装的 Widget
Widget createTestWidget({
  required Widget child,
  List<Override>? overrides,
}) {
  return ProviderScope(
    overrides: overrides ?? [],
    child: MaterialApp(
      home: child,
    ),
  );
}

/// 创建 ProviderContainer 用于服务测试
ProviderContainer createTestContainer({List<Override>? overrides}) {
  return ProviderContainer(overrides: overrides ?? []);
}

/// 等待所有异步操作完成
Future<void> pumpAndSettle(WidgetTester tester, {Duration? duration}) async {
  if (duration != null) {
    await tester.pump(duration);
  }
  await tester.pumpAndSettle();
}

/// 模拟日期时间
DateTime createTestDateTime({
  int year = 2026,
  int month = 1,
  int day = 15,
  int hour = 10,
  int minute = 0,
}) {
  return DateTime(year, month, day, hour, minute);
}

/// 测试用扩展
extension WidgetTesterExtension on WidgetTester {
  /// 输入文本并提交
  Future<void> enterTextAndSubmit(Finder finder, String text) async {
    await enterText(finder, text);
    await testTextInput.receiveAction(TextInputAction.done);
    await pumpAndSettle();
  }
}
