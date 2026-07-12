import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/models/app_update_info.dart';
import 'package:echo_loop/widgets/app_update_dialog.dart';

void main() {
  // 弹窗用模块级标志防叠加；每个用例结束后复位，避免跨测试污染。
  tearDown(debugResetUpdateDialogVisible);

  const info = AppUpdateInfo(
    latestVersion: '2.0.0',
    minimumVersion: '1.5.0',
    releaseNotes: {'en': 'New features!', 'zh': '新功能！'},
    downloadUrl: {'fallback': 'https://example.com/download'},
  );

  Widget buildApp({required Widget child}) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: child,
    );
  }

  group('Soft update 对话框', () {
    testWidgets('显示版本号和更新说明', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppUpdateDialog(
                context: context,
                info: info,
                isForceUpdate: false,
                downloadUrl: 'https://example.com/download',
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2.0.0'), findsOneWidget);
      expect(find.text('New features!'), findsOneWidget);
      // 更新内容区有 "What's New" 标题
      expect(find.text("What's New"), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
    });

    testWidgets('点击稍后调用 onDismiss', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppUpdateDialog(
                context: context,
                info: info,
                isForceUpdate: false,
                downloadUrl: 'https://example.com',
                onDismiss: () => dismissed = true,
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('点击主按钮调用 onUpdate 并关闭对话框', (tester) async {
      var updateCalls = 0;

      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppUpdateDialog(
                context: context,
                info: info,
                isForceUpdate: false,
                downloadUrl: 'market://details?id=app.echoloop',
                onUpdate: () async => updateCalls++,
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Now'));
      await tester.pumpAndSettle();

      expect(updateCalls, 1);
      // soft update：点击后对话框关闭
      expect(find.text('Update Now'), findsNothing);
    });
  });

  group('防弹窗叠加', () {
    testWidgets('已有更新弹窗时重复调用被忽略，只出现一个', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                // 连续两次请求：第二次应被模块级守卫忽略
                showAppUpdateDialog(
                  context: context,
                  info: info,
                  isForceUpdate: false,
                  downloadUrl: 'https://example.com/download',
                );
                showAppUpdateDialog(
                  context: context,
                  info: info,
                  isForceUpdate: false,
                  downloadUrl: 'https://example.com/download',
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);

      // 关闭弹窗，复位模块级守卫，避免污染后续用例
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
    });
  });

  group('Force update 对话框', () {
    testWidgets('不显示稍后按钮，显示复制链接', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppUpdateDialog(
                context: context,
                info: info,
                isForceUpdate: true,
                downloadUrl: 'https://example.com/download',
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Update Required'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
      expect(find.text('Copy Download Link'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      // 强制更新也要展示更新内容（what's new）
      expect(find.text('New features!'), findsOneWidget);
    });

    testWidgets('不可通过返回键关闭', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppUpdateDialog(
                context: context,
                info: info,
                isForceUpdate: true,
                downloadUrl: 'https://example.com',
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // 尝试通过返回键关闭
      final dynamic widgetsBinding = tester.binding;
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      // 对话框仍然存在
      expect(find.text('Update Required'), findsOneWidget);
    });

    testWidgets('无可用下载链接时退化为可关闭', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppUpdateDialog(
                context: context,
                info: info,
                isForceUpdate: true,
                downloadUrl: null,
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // 强更但无下载链接：仍显示强更标题，但给出退出按钮
      expect(find.text('Update Required'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);

      // 可通过返回键关闭，避免用户被配置缺失卡死
      final dynamic widgetsBinding = tester.binding;
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Update Required'), findsNothing);
    });
  });
}
